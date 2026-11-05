class Role {
  const Role({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });
  final String id, code, name;
  final String? description;
  factory Role.fromJson(Map<String, dynamic> j) => Role(
    id: j['id'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
  );
}
