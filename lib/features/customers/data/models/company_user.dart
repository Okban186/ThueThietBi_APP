class CompanyUser {
  const CompanyUser({
    required this.userId,
    required this.companyId,
    this.createdAt,
  });
  final String userId, companyId;
  final DateTime? createdAt;
  factory CompanyUser.fromJson(Map<String, dynamic> json) => CompanyUser(
    userId: json['userId'] as String,
    companyId: json['companyId'] as String,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String),
  );
}
