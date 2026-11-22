/// Role trả về từ `GET /api/roles`.
class RoleOption {
  const RoleOption({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.assignableByAdmin = false,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  /// Admin được gán role này cho tài khoản nhân viên (mọi role trừ COMPANY).
  final bool assignableByAdmin;

  factory RoleOption.fromJson(Map<String, dynamic> json) => RoleOption(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    assignableByAdmin: json['assignableByAdmin'] as bool? ?? false,
  );
}
