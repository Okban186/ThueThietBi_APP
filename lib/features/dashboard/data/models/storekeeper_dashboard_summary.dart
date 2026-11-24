class StorekeeperDashboardSummary {
  const StorekeeperDashboardSummary({
    required this.totalModels,
    required this.activeModels,
    required this.totalEquipments,
    required this.availableEquipments,
    required this.rentedEquipments,
    required this.reservedEquipments,
    required this.maintenanceEquipments,
    required this.damagedOrLostEquipments,
    required this.outOfStockModelsCount,
    required this.activeWarehousesCount,
    required this.activeCategoriesCount,
    required this.recentEquipments,
  });

  const StorekeeperDashboardSummary.empty()
    : totalModels = 0,
      activeModels = 0,
      totalEquipments = 0,
      availableEquipments = 0,
      rentedEquipments = 0,
      reservedEquipments = 0,
      maintenanceEquipments = 0,
      damagedOrLostEquipments = 0,
      outOfStockModelsCount = 0,
      activeWarehousesCount = 0,
      activeCategoriesCount = 0,
      recentEquipments = const [];

  final int totalModels, activeModels, totalEquipments;
  final int availableEquipments, rentedEquipments, reservedEquipments;
  final int maintenanceEquipments, damagedOrLostEquipments;
  final int outOfStockModelsCount, activeWarehousesCount, activeCategoriesCount;
  final List<RecentEquipmentActivity> recentEquipments;

  factory StorekeeperDashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => StorekeeperDashboardSummary(
    totalModels: (json['totalModels'] as num?)?.toInt() ?? 0,
    activeModels: (json['activeModels'] as num?)?.toInt() ?? 0,
    totalEquipments: (json['totalEquipments'] as num?)?.toInt() ?? 0,
    availableEquipments: (json['availableEquipments'] as num?)?.toInt() ?? 0,
    rentedEquipments: (json['rentedEquipments'] as num?)?.toInt() ?? 0,
    reservedEquipments: (json['reservedEquipments'] as num?)?.toInt() ?? 0,
    maintenanceEquipments:
        (json['maintenanceEquipments'] as num?)?.toInt() ?? 0,
    damagedOrLostEquipments:
        (json['damagedOrLostEquipments'] as num?)?.toInt() ?? 0,
    outOfStockModelsCount:
        (json['outOfStockModelsCount'] as num?)?.toInt() ?? 0,
    activeWarehousesCount:
        (json['activeWarehousesCount'] as num?)?.toInt() ?? 0,
    activeCategoriesCount:
        (json['activeCategoriesCount'] as num?)?.toInt() ?? 0,
    recentEquipments: (json['recentEquipments'] as List<dynamic>? ?? const [])
        .map((e) => RecentEquipmentActivity.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class RecentEquipmentActivity {
  const RecentEquipmentActivity({
    required this.id,
    required this.serialNumber,
    required this.equipmentModelName,
    required this.warehouseName,
    required this.status,
    required this.createdAt,
  });
  final String id, serialNumber, equipmentModelName, warehouseName, status;
  final DateTime createdAt;

  factory RecentEquipmentActivity.fromJson(Map<String, dynamic> json) =>
      RecentEquipmentActivity(
        id: json['id'] as String,
        serialNumber: json['serialNumber'] as String,
        equipmentModelName: json['equipmentModelName'] as String,
        warehouseName: json['warehouseName'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
