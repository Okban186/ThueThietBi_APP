class EquipmentReturn {
  const EquipmentReturn({
    required this.id,
    required this.returnCode,
    required this.rentalContractId,
    required this.returnedAt,
    required this.receivedBy,
    this.status,
    this.note,
  });
  final String id, returnCode, rentalContractId, receivedBy;
  final DateTime returnedAt;
  final String? status, note;
  factory EquipmentReturn.fromJson(Map<String, dynamic> j) => EquipmentReturn(
    id: j['id'] as String,
    returnCode: j['returnCode'] as String,
    rentalContractId: j['rentalContractId'] as String,
    returnedAt: DateTime.parse(j['returnedAt'] as String),
    receivedBy: j['receivedBy'] as String,
    status: j['status'] as String?,
    note: j['note'] as String?,
  );
}
