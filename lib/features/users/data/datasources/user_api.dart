import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/role_option.dart';
import '../models/user_account.dart';

/// Gọi API quản lý tài khoản (chỉ Admin).
class UserApi {
  UserApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RoleOption>> getRoles() async {
    final response = await _apiClient.get<List<dynamic>>('/api/roles');

    return response.data!
        .map((json) => RoleOption.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserAccount>> getUsers() async {
    final response = await _apiClient.get<List<dynamic>>('/api/users');

    return response.data!
        .map((json) => UserAccount.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<UserAccount> createUser({
    required String username,
    required String password,
    required String fullName,
    required String roleCode,
    String? email,
    String? phone,
    String? position,
    DateTime? hireDate,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/users',
      data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'roleCode': roleCode,
        'email': email,
        'phone': phone,
        'position': position,
        'hireDate': _dateOnly(hireDate),
      },
    );

    return UserAccount.fromJson(response.data!);
  }

  Future<UserAccount> updateUser({
    required String id,
    required String fullName,
    String? email,
    String? phone,
    String? position,
    DateTime? hireDate,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/users/$id',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'position': position,
        'hireDate': _dateOnly(hireDate),
      },
    );

    return UserAccount.fromJson(response.data!);
  }

  Future<UserAccount> updateRole({
    required String id,
    required String roleCode,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/users/$id/role',
      data: {'roleCode': roleCode},
    );

    return UserAccount.fromJson(response.data!);
  }

  Future<UserAccount> updateStatus({
    required String id,
    required UserAccountStatus status,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/users/$id/status',
      data: {'status': status.code},
    );

    return UserAccount.fromJson(response.data!);
  }

  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async {
    await _apiClient.post<void>(
      '/api/users/$id/reset-password',
      data: {'newPassword': newPassword},
    );
  }

  /// DateOnly của Backend: yyyy-MM-dd.
  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}
