class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.equipmentId,
    required this.type,
    required this.description,
    this.serviceAssignmentId,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.status,
    this.result,
  });
  final String id, equipmentId, type, description;
  final String? serviceAssignmentId, status, result;
  final DateTime? scheduledAt, startedAt, completedAt;
  factory MaintenanceTask.fromJson(Map<String, dynamic> j) => MaintenanceTask(
    id: j['id'] as String,
    equipmentId: j['equipmentId'] as String,
    type: j['type'] as String,
    description: j['description'] as String,
    serviceAssignmentId: j['serviceAssignmentId'] as String?,
    scheduledAt: _date(j['scheduledAt']),
    startedAt: _date(j['startedAt']),
    completedAt: _date(j['completedAt']),
    status: j['status'] as String?,
    result: j['result'] as String?,
  );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
