class HandoverIssue {
  const HandoverIssue({
    required this.id,
    required this.handoverNoteId,
    required this.description,
    required this.createdBy,
    this.status,
    this.createdAt,
    this.resolvedAt,
  });
  final String id, handoverNoteId, description, createdBy;
  final String? status;
  final DateTime? createdAt, resolvedAt;
  factory HandoverIssue.fromJson(Map<String, dynamic> j) => HandoverIssue(
    id: j['id'] as String,
    handoverNoteId: j['handoverNoteId'] as String,
    description: j['description'] as String,
    createdBy: j['createdBy'] as String,
    status: j['status'] as String?,
    createdAt: _date(j['createdAt']),
    resolvedAt: _date(j['resolvedAt']),
  );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
