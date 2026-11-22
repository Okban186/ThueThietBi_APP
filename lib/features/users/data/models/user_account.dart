import 'role_option.dart';

enum UserAccountStatus {
  active('ACTIVE', 'Hoạt động'),
  inactive('INACTIVE', 'Ngừng hoạt động'),
  locked('LOCKED', 'Đã khóa');

  const UserAccountStatus(this.code, this.label);

  final String code;
  final String label;

  static UserAccountStatus fromCode(String code) {
    return values.firstWhere(
      (status) => status.code == code.toUpperCase(),
      orElse: () => UserAccountStatus.inactive,
    );
  }
}

/// Tài khoản trả về từ `/api/users` (màn hình quản trị).
class UserAccount {
  const UserAccount({
    required this.id,
    required this.username,
    required this.fullName,
    required this.status,
    required this.createdAt,
    this.email,
    this.phone,
    this.role,
    this.isCompanyAccount = false,
    this.companyName,
    this.employeeCode,
    this.position,
    this.hireDate,
    this.avatarUrl,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final UserAccountStatus status;
  final RoleOption? role;

  /// Tài khoản doanh nghiệp thuê (role COMPANY), do Sales quản lý.
  final bool isCompanyAccount;
  final String? companyName;

  final String? employeeCode;
  final String? position;
  final DateTime? hireDate;
  final String? avatarUrl;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    status: UserAccountStatus.fromCode(json['status'] as String),
    role: json['role'] == null
        ? null
        : RoleOption.fromJson(json['role'] as Map<String, dynamic>),
    isCompanyAccount: json['isCompanyAccount'] as bool? ?? false,
    companyName: json['companyName'] as String?,
    employeeCode: json['employeeCode'] as String?,
    position: json['position'] as String?,
    hireDate: _date(json['hireDate']),
    avatarUrl: json['avatarUrl'] as String?,
    lastLoginAt: _date(json['lastLoginAt']),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();
}
