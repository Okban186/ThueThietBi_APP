class ServiceAssignmentMember {
  const ServiceAssignmentMember({
    required this.id,
    required this.serviceAssignmentId,
    required this.staffId,
    required this.role,
  });
  final String id, serviceAssignmentId, staffId, role;
  factory ServiceAssignmentMember.fromJson(Map<String, dynamic> j) =>
      ServiceAssignmentMember(
        id: j['id'] as String,
        serviceAssignmentId: j['serviceAssignmentId'] as String,
        staffId: j['staffId'] as String,
        role: j['role'] as String,
      );
}
