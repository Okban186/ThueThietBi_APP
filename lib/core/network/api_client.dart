import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_token_storage.dart';

class ApiClient {
  final String baseUrl;
  final AuthTokenStorage tokenStorage;

  /// Được gọi khi phiên đăng nhập không còn hợp lệ.
  final Future<void> Function()? onSessionExpired;

  Future<void>? _sessionExpiredFuture;

  late final Dio dio;
  late final Dio _refreshDio;

  /// Future của lần refresh hiện tại.
  ///
  /// null: không có refresh nào đang chạy.
  /// khác null: có request đang refresh, request khác sẽ chờ.
  Future<String?>? _refreshFuture;

  ApiClient({
    required this.baseUrl,
    required this.tokenStorage,
    this.onSessionExpired,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Dio riêng cho refresh.
    // Không gắn interceptor xử lý 401 vào instance này.
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (options.extra['requiresAuth'] == false) {
        handler.next(options);
        return;
      }

      final accessToken = await tokenStorage.getAccessToken();
      final refreshToken = await tokenStorage.getRefreshToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      } else {
        options.headers.remove('Authorization');
      }

      if (refreshToken != null && refreshToken.isNotEmpty) {
        options.headers['X-Refresh-Token'] = refreshToken;
      } else {
        options.headers.remove('X-Refresh-Token');
      }

      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      await _saveTokensFromHeaders(response.headers);
      handler.next(response);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> _saveTokensFromHeaders(Headers headers) async {
    final newAccessToken = headers.value('X-New-Access-Token');

    final newRefreshToken = headers.value('X-Refresh-Token');

    if (newAccessToken == null ||
        newAccessToken.isEmpty ||
        newRefreshToken == null ||
        newRefreshToken.isEmpty) {
      return;
    }

    await tokenStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;

    // Chỉ xử lý lỗi 401.
    // Không refresh với 403, 404, 500...
    if (error.response?.statusCode != 401) {
      handler.next(error);
      return;
    }

    // Không refresh request công khai.
    if (options.extra['requiresAuth'] == false) {
      handler.next(error);
      return;
    }

    // Request đã retry một lần thì không retry tiếp.
    if (options.extra['retried'] == true) {
      handler.next(error);
      return;
    }

    // Request refresh không được đi vào luồng refresh.
    if (options.extra['isRefreshRequest'] == true) {
      handler.next(error);
      return;
    }

    String? newAccessToken;

    try {
      final failedToken = _extractBearerToken(options.headers['Authorization']);

      final currentToken = await tokenStorage.getAccessToken();

      // Một request khác đã refresh thành công.
      // Token hiện tại khác token request này từng sử dụng.
      if (currentToken != null &&
          currentToken.isNotEmpty &&
          currentToken != failedToken) {
        newAccessToken = currentToken;
      } else {
        // Chưa có token mới:
        // thực hiện refresh hoặc chờ request khác refresh.
        newAccessToken = await _refreshAccessToken();
      }
    } catch (e) {
      // Refresh thất bại, phiên đăng nhập không còn hợp lệ.
      await _handleSessionExpired();

      handler.next(error);
      return;
    }

    if (newAccessToken == null || newAccessToken.isEmpty) {
      await _handleSessionExpired();

      handler.next(error);
      return;
    }

    try {
      // Gửi lại request ban đầu bằng token mới.
      final response = await _retryRequest(options, newAccessToken);

      handler.resolve(response);
    } on DioException catch (retryError) {
      // Request gửi lại thất bại.
      // Không xóa token chỉ vì request này gặp lỗi.
      handler.next(retryError);
    } catch (e) {
      handler.next(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<String?> _refreshAccessToken() {
    // Đang có request refresh khác:
    // không gọi API refresh thêm lần nữa.
    final ongoingRefresh = _refreshFuture;

    if (ongoingRefresh != null) {
      return ongoingRefresh;
    }

    // Chưa có refresh nào chạy:
    // request đầu tiên thực hiện refresh.
    final refreshFuture = _performRefresh();

    _refreshFuture = refreshFuture;

    return refreshFuture.whenComplete(() {
      // Chỉ xóa Future nếu vẫn đúng là lần refresh này.
      if (identical(_refreshFuture, refreshFuture)) {
        _refreshFuture = null;
      }
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Refresh Token không tồn tại.');
    }

    final response = await _refreshDio.post(
      '/auth/refresh', // Thay bằng endpoint thực tế.
      data: {'refreshToken': refreshToken},
    );

    final data = response.data as Map<String, dynamic>;

    // Đổi tên field theo JSON Backend thực tế.
    final newAccessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String?;

    if (newAccessToken == null ||
        newAccessToken.isEmpty ||
        newRefreshToken == null ||
        newRefreshToken.isEmpty) {
      throw Exception('Backend trả về token không hợp lệ.');
    }

    // Lưu đồng thời cặp token mới.
    await tokenStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );

    return newAccessToken;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions options,
    String accessToken,
  ) {
    // Đánh dấu request đã retry.
    options.extra['retried'] = true;

    // Gắn token mới.
    options.headers['Authorization'] = 'Bearer $accessToken';

    // Gửi lại request với cấu hình ban đầu.
    // Interceptor onRequest sẽ chạy lại, nhưng không refresh ở đây.
    return dio.fetch<dynamic>(options);
  }

  Future<void> _handleSessionExpired() {
    if (_sessionExpiredFuture != null) {
      return _sessionExpiredFuture!;
    }

    final future = _clearSession();

    _sessionExpiredFuture = future;

    return future;
  }

  Future<void> _clearSession() async {
    try {
      await tokenStorage.clearTokens();

      if (onSessionExpired != null) {
        await onSessionExpired!();
      }
    } finally {
      // Giữ trạng thái đã xử lý để tránh callback lặp lại.
      // Reset khi người dùng đăng nhập thành công.
    }
  }

  String? _extractBearerToken(dynamic authorization) {
    if (authorization is! String) {
      return null;
    }

    const prefix = 'Bearer ';

    if (!authorization.startsWith(prefix)) {
      return null;
    }

    return authorization.substring(prefix.length);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
