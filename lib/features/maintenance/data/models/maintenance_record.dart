class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.maintenanceTaskId,
    required this.performedBy,
    required this.description,
    this.laborCost = 0,
    this.completedAt,
    this.note,
  });
  final String id, maintenanceTaskId, performedBy, description;
  final double laborCost;
  final DateTime? completedAt;
  final String? note;
  factory MaintenanceRecord.fromJson(Map<String, dynamic> j) =>
      MaintenanceRecord(
        id: j['id'] as String,
        maintenanceTaskId: j['maintenanceTaskId'] as String,
        performedBy: j['performedBy'] as String,
        description: j['description'] as String,
        laborCost: (j['laborCost'] as num?)?.toDouble() ?? 0,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
        note: j['note'] as String?,
      );
}
