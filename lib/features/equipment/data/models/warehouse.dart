class Warehouse {
  const Warehouse({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.status,
  });
  final String id, code, name;
  final String? address, phone, status;
  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    status: json['status'] as String?,
  );
}
