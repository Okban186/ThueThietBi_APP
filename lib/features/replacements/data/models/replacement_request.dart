class ReplacementRequest {
  const ReplacementRequest({
    required this.id,
    required this.requestCode,
    required this.rentalContractId,
    required this.reason,
    required this.requestedBy,
    this.incidentId,
    this.handoverId,
    this.status,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });
  final String id, requestCode, rentalContractId, reason, requestedBy;
  final String? incidentId, handoverId, status, approvedBy;
  final DateTime? approvedAt, createdAt, updatedAt;
  factory ReplacementRequest.fromJson(Map<String, dynamic> j) =>
      ReplacementRequest(
        id: j['id'] as String,
        requestCode: j['requestCode'] as String,
        rentalContractId: j['rentalContractId'] as String,
        reason: j['reason'] as String,
        requestedBy: j['requestedBy'] as String,
        incidentId: j['incidentId'] as String?,
        handoverId: j['handoverId'] as String?,
        status: j['status'] as String?,
        approvedBy: j['approvedBy'] as String?,
        approvedAt: _date(j['approvedAt']),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
      );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
