import 'company.dart';

/// Tài khoản đăng nhập (role COMPANY) của người thuộc công ty khách hàng.
class CompanyAccount {
  const CompanyAccount({
    required this.id,
    required this.username,
    required this.fullName,
    required this.status,
    required this.createdAt,
    this.email,
    this.phone,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;

  /// ACTIVE, INACTIVE, LOCKED
  final String status;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get statusLabel => switch (status.toUpperCase()) {
    'ACTIVE' => 'Hoạt động',
    'LOCKED' => 'Đã khóa',
    _ => 'Ngừng hoạt động',
  };

  factory CompanyAccount.fromJson(Map<String, dynamic> json) => CompanyAccount(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    status: json['status'] as String,
    lastLoginAt: json['lastLoginAt'] == null
        ? null
        : DateTime.parse(json['lastLoginAt'] as String).toLocal(),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

/// Chi tiết công ty kèm tài khoản đăng nhập (`GET /api/companies/{id}`).
class CompanyDetail {
  const CompanyDetail({required this.company, required this.accounts});

  final Company company;
  final List<CompanyAccount> accounts;

  factory CompanyDetail.fromJson(Map<String, dynamic> json) => CompanyDetail(
    company: Company.fromJson(json['company'] as Map<String, dynamic>),
    accounts: (json['accounts'] as List<dynamic>)
        .map((e) => CompanyAccount.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
