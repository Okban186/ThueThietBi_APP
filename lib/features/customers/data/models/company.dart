enum CompanyStatus {
  active('ACTIVE', 'Đang hoạt động'),
  inactive('INACTIVE', 'Ngừng hoạt động');

  const CompanyStatus(this.code, this.label);

  final String code;
  final String label;

  static CompanyStatus fromCode(String? code) =>
      code?.toUpperCase() == 'INACTIVE' ? inactive : active;
}

/// Công ty khách hàng (`/api/companies`).
class Company {
  const Company({
    required this.id,
    required this.companyCode,
    required this.name,
    required this.taxCode,
    this.address,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.createdById,
    this.createdByName,
    this.canEdit = false,
    this.accountCount = 0,
  });

  final String id, companyCode, name, taxCode;
  final String? address, status;
  final DateTime? createdAt, updatedAt;

  /// Nhân viên kinh doanh tạo công ty (null với dữ liệu cũ).
  final String? createdById;
  final String? createdByName;

  /// Người đang đăng nhập được sửa công ty (người tạo, hoặc công ty chưa có người tạo).
  final bool canEdit;

  /// Số tài khoản đăng nhập (role COMPANY) của công ty.
  final int accountCount;

  CompanyStatus get companyStatus => CompanyStatus.fromCode(status);
  bool get isActive => companyStatus == CompanyStatus.active;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String,
    companyCode: json['companyCode'] as String,
    name: json['name'] as String,
    taxCode: json['taxCode'] as String,
    address: json['address'] as String?,
    status: json['status'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    createdById: json['createdById'] as String?,
    createdByName: json['createdByName'] as String?,
    canEdit: json['canEdit'] as bool? ?? false,
    accountCount: json['accountCount'] as int? ?? 0,
  );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();
}
