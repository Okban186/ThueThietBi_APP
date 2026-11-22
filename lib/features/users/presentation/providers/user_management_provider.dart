import 'package:flutter/foundation.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';

import '../../data/datasources/user_api.dart';
import '../../data/models/role_option.dart';
import '../../data/models/user_account.dart';

/// Trạng thái màn hình quản lý tài khoản của Admin.
///
/// Danh sách tài khoản nhỏ nên tải một lần rồi lọc tại client;
/// mỗi thao tác thành công sẽ cập nhật lại phần tử trong danh sách.
class UserManagementProvider extends ChangeNotifier {
  UserManagementProvider(this._api);

  final UserApi _api;

  List<UserAccount> _users = [];
  List<RoleOption> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _keyword = '';
  String? _roleFilter;
  UserAccountStatus? _statusFilter;

  List<UserAccount> get users => List.unmodifiable(_users);
  List<RoleOption> get roles => List.unmodifiable(_roles);
  List<RoleOption> get assignableRoles =>
      _roles.where((role) => role.assignableByAdmin).toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _users.isNotEmpty || _roles.isNotEmpty;

  String get keyword => _keyword;
  String? get roleFilter => _roleFilter;
  UserAccountStatus? get statusFilter => _statusFilter;

  List<UserAccount> get filteredUsers {
    final keyword = _keyword.trim().toLowerCase();

    return _users.where((user) {
      if (_statusFilter != null && user.status != _statusFilter) return false;
      if (_roleFilter != null && user.role?.code != _roleFilter) return false;
      if (keyword.isEmpty) return true;

      return [
        user.username,
        user.fullName,
        user.email,
        user.phone,
        user.employeeCode,
      ].any((value) => value != null && value.toLowerCase().contains(keyword));
    }).toList();
  }

  int countByStatus(UserAccountStatus status) =>
      _users.where((user) => user.status == status).length;

  int countByRole(String roleCode) =>
      _users.where((user) => user.role?.code == roleCode).length;

  List<UserAccount> get recentlyCreated {
    final sorted = [..._users]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted.take(5).toList();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([_api.getRoles(), _api.getUsers()]);

      _roles = results[0] as List<RoleOption>;
      _users = results[1] as List<UserAccount>;
    } catch (error) {
      _errorMessage = apiErrorMessage(
        error,
        fallback: 'Không tải được danh sách tài khoản.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setKeyword(String value) {
    _keyword = value;
    notifyListeners();
  }

  void setRoleFilter(String? roleCode) {
    _roleFilter = roleCode;
    notifyListeners();
  }

  void setStatusFilter(UserAccountStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _keyword = '';
    _roleFilter = null;
    _statusFilter = null;
    notifyListeners();
  }

  UserAccount? findById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }

    return null;
  }

  // Các thao tác ném lỗi gốc để màn hình hiển thị bằng apiErrorMessage().

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
    final user = await _api.createUser(
      username: username,
      password: password,
      fullName: fullName,
      roleCode: roleCode,
      email: email,
      phone: phone,
      position: position,
      hireDate: hireDate,
    );

    _users = [user, ..._users];
    notifyListeners();

    return user;
  }

  Future<UserAccount> updateUser({
    required String id,
    required String fullName,
    String? email,
    String? phone,
    String? position,
    DateTime? hireDate,
  }) async {
    return _replace(
      await _api.updateUser(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        position: position,
        hireDate: hireDate,
      ),
    );
  }

  Future<UserAccount> updateRole(String id, String roleCode) async {
    return _replace(await _api.updateRole(id: id, roleCode: roleCode));
  }

  Future<UserAccount> updateStatus(String id, UserAccountStatus status) async {
    return _replace(await _api.updateStatus(id: id, status: status));
  }

  Future<void> resetPassword(String id, String newPassword) {
    return _api.resetPassword(id: id, newPassword: newPassword);
  }

  UserAccount _replace(UserAccount updated) {
    _users = [
      for (final user in _users) user.id == updated.id ? updated : user,
    ];
    notifyListeners();

    return updated;
  }
}
