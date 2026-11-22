/// Đơn vị tính tiền thuê.
enum BillingUnit {
  daily('DAILY', 'Theo ngày', 'ngày'),
  monthly('MONTHLY', 'Theo tháng', 'tháng');

  const BillingUnit(this.code, this.label, this.unitLabel);

  final String code;
  final String label;

  /// Đơn vị hiển thị sau đơn giá, ví dụ "200.000 đ/ngày".
  final String unitLabel;

  static BillingUnit fromCode(String code) =>
      code.toUpperCase() == 'MONTHLY' ? monthly : daily;

  /// Số đơn vị tính tiền: ngày, hoặc tháng = làm tròn lên (30 ngày/tháng).
  /// Khớp công thức của Backend (ContractService.BillableUnits).
  int billableUnits(int rentalDays) =>
      this == monthly ? (rentalDays / 30).ceil() : rentalDays;
}

/// Một dòng thiết bị trong hợp đồng.
class RentalContractItem {
  const RentalContractItem({
    required this.equipmentModelId,
    required this.quantity,
    required this.billingUnit,
    required this.agreedUnitPrice,
    this.id,
    this.equipmentModelCode,
    this.equipmentModelName,
    this.unit,
    this.billableUnits = 0,
    this.amount = 0,
    this.note,
  });

  final String? id;
  final String equipmentModelId;
  final String? equipmentModelCode, equipmentModelName, unit, note;
  final int quantity;
  final BillingUnit billingUnit;
  final double agreedUnitPrice;
  final int billableUnits;
  final double amount;

  factory RentalContractItem.fromJson(Map<String, dynamic> json) =>
      RentalContractItem(
        id: json['id'] as String?,
        equipmentModelId: json['equipmentModelId'] as String,
        equipmentModelCode: json['equipmentModelCode'] as String?,
        equipmentModelName: json['equipmentModelName'] as String?,
        unit: json['unit'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        billingUnit: BillingUnit.fromCode(json['billingUnit'] as String),
        agreedUnitPrice: (json['agreedUnitPrice'] as num).toDouble(),
        billableUnits: (json['billableUnits'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
      );
}
