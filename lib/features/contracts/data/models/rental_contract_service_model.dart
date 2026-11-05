class RentalContractService {
  const RentalContractService({
    required this.id,
    required this.rentalContractId,
    required this.serviceType,
    required this.providedBy,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.note,
  });
  final String id, rentalContractId, serviceType, providedBy;
  final int quantity;
  final double unitPrice, amount;
  final String? note;
  factory RentalContractService.fromJson(Map<String, dynamic> j) =>
      RentalContractService(
        id: j['id'] as String,
        rentalContractId: j['rentalContractId'] as String,
        serviceType: j['serviceType'] as String,
        providedBy: j['providedBy'] as String,
        quantity: (j['quantity'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] as String?,
      );
}
