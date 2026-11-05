class RentalContract {
  const RentalContract({
    required this.id,
    required this.contractCode,
    required this.companyId,
    required this.startDate,
    required this.endDate,
    required this.rentalType,
    required this.status,
    required this.createdBy,
    this.reservationId,
    this.deliveryAddress,
    this.deliveryNote,
    this.contractTotalAmount = 0,
    this.depositRequiredAmount = 0,
    this.depositPaidAmount = 0,
    this.depositAppliedAmount = 0,
    this.depositRefundedAmount = 0,
    this.contractFileId,
    this.signedAt,
    this.effectiveFrom,
    this.effectiveTo,
    this.note,
  });
  final String id, contractCode, companyId, rentalType, status, createdBy;
  final String? reservationId,
      deliveryAddress,
      deliveryNote,
      contractFileId,
      note;
  final DateTime startDate, endDate;
  final DateTime? signedAt, effectiveFrom, effectiveTo;
  final double contractTotalAmount,
      depositRequiredAmount,
      depositPaidAmount,
      depositAppliedAmount,
      depositRefundedAmount;

  factory RentalContract.fromJson(Map<String, dynamic> j) => RentalContract(
    id: j['id'] as String,
    contractCode: j['contractCode'] as String,
    companyId: j['companyId'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: DateTime.parse(j['endDate'] as String),
    rentalType: j['rentalType'] as String,
    status: j['status'] as String,
    createdBy: j['createdBy'] as String,
    reservationId: j['reservationId'] as String?,
    deliveryAddress: j['deliveryAddress'] as String?,
    deliveryNote: j['deliveryNote'] as String?,
    contractTotalAmount: _num(j['contractTotalAmount']),
    depositRequiredAmount: _num(j['depositRequiredAmount']),
    depositPaidAmount: _num(j['depositPaidAmount']),
    depositAppliedAmount: _num(j['depositAppliedAmount']),
    depositRefundedAmount: _num(j['depositRefundedAmount']),
    contractFileId: j['contractFileId'] as String?,
    signedAt: _date(j['signedAt']),
    effectiveFrom: _date(j['effectiveFrom']),
    effectiveTo: _date(j['effectiveTo']),
    note: j['note'] as String?,
  );
  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
