class EquipmentIncident {
  const EquipmentIncident({
    required this.id,
    required this.incidentCode,
    required this.companyId,
    required this.description,
    required this.reportedAt,
    this.resolvedAt,
    this.status,
    this.resolution,
  });
  final String id, incidentCode, companyId, description;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? status, resolution;
  factory EquipmentIncident.fromJson(Map<String, dynamic> j) =>
      EquipmentIncident(
        id: j['id'] as String,
        incidentCode: j['incidentCode'] as String,
        companyId: j['companyId'] as String,
        description: j['description'] as String,
        reportedAt: DateTime.parse(j['reportedAt'] as String),
        resolvedAt: j['resolvedAt'] == null
            ? null
            : DateTime.parse(j['resolvedAt'] as String),
        status: j['status'] as String?,
        resolution: j['resolution'] as String?,
      );
}
