class EquipmentReturnItem {
  const EquipmentReturnItem({
    required this.id,
    required this.equipmentReturnId,
    required this.equipmentId,
    this.status,
    this.note,
  });
  final String id, equipmentReturnId, equipmentId;
  final String? status, note;
  factory EquipmentReturnItem.fromJson(Map<String, dynamic> j) =>
      EquipmentReturnItem(
        id: j['id'] as String,
        equipmentReturnId: j['equipmentReturnId'] as String,
        equipmentId: j['equipmentId'] as String,
        status: j['status'] as String?,
        note: j['note'] as String?,
      );
}
