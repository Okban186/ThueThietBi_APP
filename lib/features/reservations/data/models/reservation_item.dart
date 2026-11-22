/// Một dòng thiết bị (model + số lượng) trong phiếu giữ chỗ.
class ReservationItem {
  const ReservationItem({
    required this.id,
    required this.equipmentModelId,
    required this.quantity,
    this.equipmentModelCode,
    this.equipmentModelName,
    this.unit,
    this.rentalPriceDaily = 0,
    this.rentalPriceMonthly = 0,
    this.note,
    this.availableQuantity,
  });

  final String id, equipmentModelId;
  final int quantity;
  final String? equipmentModelCode, equipmentModelName, unit, note;
  final double rentalPriceDaily, rentalPriceMonthly;

  /// Số lượng tối đa phiếu này giữ được cho model trong khoảng ngày của phiếu
  /// (đã loại trừ chính phiếu này).
  final int? availableQuantity;

  ReservationItem copyWith({int? quantity, int? availableQuantity}) =>
      ReservationItem(
        id: id,
        equipmentModelId: equipmentModelId,
        quantity: quantity ?? this.quantity,
        equipmentModelCode: equipmentModelCode,
        equipmentModelName: equipmentModelName,
        unit: unit,
        rentalPriceDaily: rentalPriceDaily,
        rentalPriceMonthly: rentalPriceMonthly,
        note: note,
        availableQuantity: availableQuantity ?? this.availableQuantity,
      );

  factory ReservationItem.fromJson(Map<String, dynamic> json) =>
      ReservationItem(
        id: json['id'] as String,
        equipmentModelId: json['equipmentModelId'] as String,
        equipmentModelCode: json['equipmentModelCode'] as String?,
        equipmentModelName: json['equipmentModelName'] as String?,
        unit: json['unit'] as String?,
        rentalPriceDaily: (json['rentalPriceDaily'] as num?)?.toDouble() ?? 0,
        rentalPriceMonthly:
            (json['rentalPriceMonthly'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num).toInt(),
        note: json['note'] as String?,
        availableQuantity: (json['availableQuantity'] as num?)?.toInt(),
      );
}
