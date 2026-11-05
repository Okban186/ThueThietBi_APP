import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/user.dart';

class AuthApi {
  final ApiClient _apiClient;

  AuthApi(this._apiClient);

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'username': username, 'password': password},
      options: Options(extra: {'requiresAuth': false}),
    );
  }

  Future<void> logout() async {
    await _apiClient.post<void>('/api/auth/logout');
  }

  Future<User> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/auth/me');

    return User.fromJson(response.data!);
  }
}
