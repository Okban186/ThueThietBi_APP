class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.equipmentModelId,
    required this.warehouseId,
    required this.serialNumber,
    this.status,
    this.condition,
    this.acquiredAt,
    this.acquisitionCost,
    this.note,
  });
  final String id, equipmentModelId, warehouseId, serialNumber;
  final String? status, condition, note;
  final DateTime? acquiredAt;
  final double? acquisitionCost;
  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
    id: json['id'] as String,
    equipmentModelId: json['equipmentModelId'] as String,
    warehouseId: json['warehouseId'] as String,
    serialNumber: json['serialNumber'] as String,
    status: json['status'] as String?,
    condition: json['condition'] as String?,
    acquiredAt: json['acquiredAt'] == null
        ? null
        : DateTime.parse(json['acquiredAt'] as String),
    acquisitionCost: (json['acquisitionCost'] as num?)?.toDouble(),
    note: json['note'] as String?,
  );
}
