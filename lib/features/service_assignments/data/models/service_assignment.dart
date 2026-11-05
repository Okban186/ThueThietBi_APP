class ServiceAssignment {
  const ServiceAssignment({
    required this.id,
    required this.type,
    required this.title,
    required this.createdBy,
    this.description,
    this.status,
    this.assignedAt,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
    this.startedAt,
    this.completedAt,
  });
  final String id, type, title, createdBy;
  final String? description, status;
  final DateTime? assignedAt, scheduledStartAt, startedAt, completedAt;
  final int? estimatedDurationMinutes;
  factory ServiceAssignment.fromJson(Map<String, dynamic> j) =>
      ServiceAssignment(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        createdBy: j['createdBy'] as String,
        description: j['description'] as String?,
        status: j['status'] as String?,
        assignedAt: _date(j['assignedAt']),
        scheduledStartAt: _date(j['scheduledStartAt']),
        estimatedDurationMinutes: (j['estimatedDurationMinutes'] as num?)
            ?.toInt(),
        startedAt: _date(j['startedAt']),
        completedAt: _date(j['completedAt']),
      );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
