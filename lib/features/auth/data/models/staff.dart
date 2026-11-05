class Staff {
  const Staff({
    required this.id,
    required this.userId,
    required this.employeeCode,
    this.position,
    this.hireDate,
    this.status,
  });
  final String id, userId, employeeCode;
  final String? position, status;
  final DateTime? hireDate;
  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
    id: j['id'] as String,
    userId: j['userId'] as String,
    employeeCode: j['employeeCode'] as String,
    position: j['position'] as String?,
    hireDate: j['hireDate'] == null
        ? null
        : DateTime.parse(j['hireDate'] as String),
    status: j['status'] as String?,
  );
}
