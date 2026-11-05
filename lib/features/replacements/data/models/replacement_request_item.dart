class ReplacementRequestItem {
  const ReplacementRequestItem({
    required this.id,
    required this.replacementRequestId,
    required this.oldEquipmentId,
    this.note,
    this.createdAt,
  });
  final String id, replacementRequestId, oldEquipmentId;
  final String? note;
  final DateTime? createdAt;
  factory ReplacementRequestItem.fromJson(Map<String, dynamic> j) =>
      ReplacementRequestItem(
        id: j['id'] as String,
        replacementRequestId: j['replacementRequestId'] as String,
        oldEquipmentId: j['oldEquipmentId'] as String,
        note: j['note'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'] as String),
      );
}
