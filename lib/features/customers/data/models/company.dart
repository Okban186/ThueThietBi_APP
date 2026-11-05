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
  });
  final String id, companyCode, name, taxCode;
  final String? address, status;
  final DateTime? createdAt, updatedAt;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String,
    companyCode: json['companyCode'] as String,
    name: json['name'] as String,
    taxCode: json['taxCode'] as String,
    address: json['address'] as String?,
    status: json['status'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
