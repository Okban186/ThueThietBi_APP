class Category {
  const Category({
    required this.id,
    required this.code,
    required this.name,
    this.parentId,
    this.description,
    this.status,
  });
  final String id, code, name;
  final String? parentId, description, status;
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    description: json['description'] as String?,
    status: json['status'] as String?,
  );
}
