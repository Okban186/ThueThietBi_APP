import 'package:dio/dio.dart';

/// Lấy thông báo lỗi hiển thị cho người dùng từ lỗi gọi API.
///
/// Hỗ trợ 2 định dạng Backend trả về:
/// - AppException: `{ "success": false, "code": "...", "message": "...", "errors": {...} }`
/// - Validation mặc định của ASP.NET: `{ "title": "...", "errors": { "Field": ["..."] } }`
String apiErrorMessage(
  Object error, {
  String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.',
}) {
  if (error is! DioException) {
    return fallback;
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
    default:
      break;
  }

  final statusCode = error.response?.statusCode;
  final data = error.response?.data;

  if (data is Map) {
    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    // Lỗi validation: lấy thông báo đầu tiên.
    final errors = data['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
      }
    }
  }

  return switch (statusCode) {
    401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu.',
    _ => fallback,
  };
}
