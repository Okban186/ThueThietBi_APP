class MaintenancePart {
  const MaintenancePart({
    required this.id,
    required this.maintenanceRecordId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.note,
  });
  final String id, maintenanceRecordId, name;
  final double quantity, unitCost, totalCost;
  final String? note;
  factory MaintenancePart.fromJson(Map<String, dynamic> j) => MaintenancePart(
    id: j['id'] as String,
    maintenanceRecordId: j['maintenanceRecordId'] as String,
    name: j['name'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    unitCost: (j['unitCost'] as num).toDouble(),
    totalCost: (j['totalCost'] as num).toDouble(),
    note: j['note'] as String?,
  );
}
