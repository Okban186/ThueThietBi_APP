class RentalCharge {
  const RentalCharge({
    required this.id,
    required this.sourceType,
    required this.chargeType,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.paidAmount,
    required this.createdBy,
    this.rentalContractId,
    this.equipmentId,
    this.description,
    this.periodStart,
    this.periodEnd,
    this.dueDate,
    this.status,
    this.paidAt,
    this.note,
  });
  final String id, sourceType, chargeType, createdBy;
  final String? rentalContractId, equipmentId, description, status, note;
  final double quantity, unitPrice, amount, paidAmount;
  final DateTime? periodStart, periodEnd, dueDate, paidAt;
  factory RentalCharge.fromJson(Map<String, dynamic> j) => RentalCharge(
    id: j['id'] as String,
    sourceType: j['sourceType'] as String,
    chargeType: j['chargeType'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    amount: (j['amount'] as num).toDouble(),
    paidAmount: (j['paidAmount'] as num).toDouble(),
    createdBy: j['createdBy'] as String,
    rentalContractId: j['rentalContractId'] as String?,
    equipmentId: j['equipmentId'] as String?,
    description: j['description'] as String?,
    periodStart: _date(j['periodStart']),
    periodEnd: _date(j['periodEnd']),
    dueDate: _date(j['dueDate']),
    status: j['status'] as String?,
    paidAt: _date(j['paidAt']),
    note: j['note'] as String?,
  );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
