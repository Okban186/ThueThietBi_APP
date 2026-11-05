class EquipmentIncidentItem {
  const EquipmentIncidentItem({
    required this.id,
    required this.incidentId,
    required this.equipmentId,
    this.description,
    this.assessment,
    this.note,
  });
  final String id, incidentId, equipmentId;
  final String? description, assessment, note;
  factory EquipmentIncidentItem.fromJson(Map<String, dynamic> j) =>
      EquipmentIncidentItem(
        id: j['id'] as String,
        incidentId: j['incidentId'] as String,
        equipmentId: j['equipmentId'] as String,
        description: j['description'] as String?,
        assessment: j['assessment'] as String?,
        note: j['note'] as String?,
      );
}
