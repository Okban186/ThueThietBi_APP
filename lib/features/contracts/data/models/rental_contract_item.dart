class RentalContractItem {
  const RentalContractItem({
    required this.id,
    required this.rentalContractId,
    required this.equipmentModelId,
    required this.quantity,
    required this.billingUnit,
    required this.agreedUnitPrice,
    this.note,
  });
  final String id, rentalContractId, equipmentModelId, billingUnit;
  final int quantity;
  final double agreedUnitPrice;
  final String? note;
  factory RentalContractItem.fromJson(Map<String, dynamic> j) =>
      RentalContractItem(
        id: j['id'] as String,
        rentalContractId: j['rentalContractId'] as String,
        equipmentModelId: j['equipmentModelId'] as String,
        quantity: (j['quantity'] as num).toInt(),
        billingUnit: j['billingUnit'] as String,
        agreedUnitPrice: (j['agreedUnitPrice'] as num).toDouble(),
        note: j['note'] as String?,
      );
}
