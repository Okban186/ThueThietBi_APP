class ContractStatusHistory {
  const ContractStatusHistory({
    required this.id,
    required this.rentalContractId,
    required this.status,
    required this.previousStatus,
    required this.changedBy,
    this.changedAt,
    this.note,
  });
  final String id, rentalContractId, status, previousStatus, changedBy;
  final DateTime? changedAt;
  final String? note;
  factory ContractStatusHistory.fromJson(Map<String, dynamic> j) =>
      ContractStatusHistory(
        id: j['id'] as String,
        rentalContractId: j['rentalContractId'] as String,
        status: j['status'] as String,
        previousStatus: j['previousStatus'] as String,
        changedBy: j['changedBy'] as String,
        changedAt: j['changedAt'] == null
            ? null
            : DateTime.parse(j['changedAt'] as String),
        note: j['note'] as String?,
      );
}
