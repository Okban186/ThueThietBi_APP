class HandoverItem {
  const HandoverItem({
    required this.id,
    required this.handoverNoteId,
    required this.equipmentId,
    this.note,
  });
  final String id, handoverNoteId, equipmentId;
  final String? note;
  factory HandoverItem.fromJson(Map<String, dynamic> j) => HandoverItem(
    id: j['id'] as String,
    handoverNoteId: j['handoverNoteId'] as String,
    equipmentId: j['equipmentId'] as String,
    note: j['note'] as String?,
  );
}
