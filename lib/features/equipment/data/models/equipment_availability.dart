/// Số lượng khả dụng của một model trong khoảng ngày
/// (`/api/equipment-models/{id}/availability`, `POST /api/equipment-models/availability`).
class EquipmentAvailability {
  const EquipmentAvailability({
    required this.equipmentModelId,
    required this.operationalUnits,
    required this.peakHeldQuantity,
    required this.availableQuantity,
  });

  final String equipmentModelId;

  /// Số máy hoạt động (AVAILABLE, RESERVED, RENTED).
  final int operationalUnits;

  /// Mức chiếm dụng cao nhất trong một ngày của khoảng hỏi.
  final int peakHeldQuantity;

  /// Số lượng còn giữ chỗ/cho thuê được trong suốt khoảng hỏi.
  final int availableQuantity;

  factory EquipmentAvailability.fromJson(Map<String, dynamic> json) =>
      EquipmentAvailability(
        equipmentModelId: json['equipmentModelId'] as String,
        operationalUnits: (json['operationalUnits'] as num).toInt(),
        peakHeldQuantity: (json['peakHeldQuantity'] as num).toInt(),
        availableQuantity: (json['availableQuantity'] as num).toInt(),
      );
}
