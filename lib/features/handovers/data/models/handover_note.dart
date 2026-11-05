class HandoverNote {
  const HandoverNote({
    required this.id,
    required this.handoverCode,
    required this.rentalContractId,
    required this.handoverDate,
    required this.receivedByName,
    required this.createdBy,
    this.serviceAssignmentId,
    this.replacementRequestId,
    this.deliveryAttemptNumber = 1,
    this.failedReason,
    this.failedAt,
    this.receivedByPhone,
    this.note,
    this.status,
  });
  final String id, handoverCode, rentalContractId, receivedByName, createdBy;
  final String? serviceAssignmentId,
      replacementRequestId,
      failedReason,
      receivedByPhone,
      note,
      status;
  final DateTime handoverDate;
  final DateTime? failedAt;
  final int deliveryAttemptNumber;
  factory HandoverNote.fromJson(Map<String, dynamic> j) => HandoverNote(
    id: j['id'] as String,
    handoverCode: j['handoverCode'] as String,
    rentalContractId: j['rentalContractId'] as String,
    handoverDate: DateTime.parse(j['handoverDate'] as String),
    receivedByName: j['receivedByName'] as String,
    createdBy: j['createdBy'] as String,
    serviceAssignmentId: j['serviceAssignmentId'] as String?,
    replacementRequestId: j['replacementRequestId'] as String?,
    deliveryAttemptNumber: (j['deliveryAttemptNumber'] as num?)?.toInt() ?? 1,
    failedReason: j['failedReason'] as String?,
    failedAt: j['failedAt'] == null
        ? null
        : DateTime.parse(j['failedAt'] as String),
    receivedByPhone: j['receivedByPhone'] as String?,
    note: j['note'] as String?,
    status: j['status'] as String?,
  );
}
