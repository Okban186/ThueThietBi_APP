class EquipmentMaintenancePartHistory {
  const EquipmentMaintenancePartHistory({
    required this.partId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.note,
  });

  final String partId, name;
  final double quantity, unitCost, totalCost;
  final String? note;

  factory EquipmentMaintenancePartHistory.fromJson(Map<String, dynamic> json) =>
      EquipmentMaintenancePartHistory(
        partId: json['partId'] as String,
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
      );
}

class EquipmentMaintenanceRecordHistory {
  const EquipmentMaintenanceRecordHistory({
    required this.recordId,
    required this.performedByName,
    required this.description,
    required this.laborCost,
    required this.partsTotalCost,
    required this.parts,
    this.completedAt,
    this.note,
  });

  final String recordId, performedByName, description;
  final double laborCost, partsTotalCost;
  final DateTime? completedAt;
  final String? note;
  final List<EquipmentMaintenancePartHistory> parts;

  double get totalCost => laborCost + partsTotalCost;

  factory EquipmentMaintenanceRecordHistory.fromJson(
    Map<String, dynamic> json,
  ) => EquipmentMaintenanceRecordHistory(
    recordId: json['recordId'] as String,
    performedByName: json['performedByName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    laborCost: (json['laborCost'] as num?)?.toDouble() ?? 0,
    partsTotalCost: (json['partsTotalCost'] as num?)?.toDouble() ?? 0,
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String).toLocal()
        : null,
    note: json['note'] as String?,
    parts: [
      for (final e in json['parts'] as List<dynamic>? ?? const [])
        EquipmentMaintenancePartHistory.fromJson(e as Map<String, dynamic>),
    ],
  );
}

class EquipmentMaintenanceHistory {
  const EquipmentMaintenanceHistory({
    required this.taskId,
    required this.type,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.totalLaborCost,
    required this.totalPartsCost,
    required this.attachmentUrls,
    required this.records,
    this.result,
    this.assignedTechnicianName,
    this.startedAt,
    this.completedAt,
  });

  final String taskId, type, status, description;
  final String? result, assignedTechnicianName;
  final DateTime? startedAt, completedAt;
  final DateTime createdAt;
  final double totalLaborCost, totalPartsCost;
  final List<String> attachmentUrls;
  final List<EquipmentMaintenanceRecordHistory> records;

  double get totalCost => totalLaborCost + totalPartsCost;

  String get typeLabel => switch (type.toUpperCase()) {
    'PREVENTIVE' => 'Bảo dưỡng định kỳ',
    'CORRECTIVE' => 'Sửa chữa hư hỏng',
    _ => 'Kiểm tra thiết bị',
  };

  factory EquipmentMaintenanceHistory.fromJson(Map<String, dynamic> json) =>
      EquipmentMaintenanceHistory(
        taskId: json['taskId'] as String,
        type: json['type'] as String? ?? 'INSPECTION',
        status: json['status'] as String? ?? 'PENDING',
        description: json['description'] as String? ?? '',
        result: json['result'] as String?,
        assignedTechnicianName: json['assignedTechnicianName'] as String?,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String).toLocal()
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        totalLaborCost: (json['totalLaborCost'] as num?)?.toDouble() ?? 0,
        totalPartsCost: (json['totalPartsCost'] as num?)?.toDouble() ?? 0,
        attachmentUrls: (json['attachmentUrls'] as List<dynamic>? ?? const [])
            .cast<String>(),
        records: [
          for (final e in json['records'] as List<dynamic>? ?? const [])
            EquipmentMaintenanceRecordHistory.fromJson(
              e as Map<String, dynamic>,
            ),
        ],
      );
}

class EquipmentIncidentHistory {
  const EquipmentIncidentHistory({
    required this.incidentId,
    required this.incidentCode,
    required this.companyName,
    required this.status,
    required this.reportedAt,
    required this.description,
    this.resolvedAt,
    this.faultType,
    this.assessment,
    this.resolution,
    this.chargeAmount,
    this.chargeStatus,
  });

  final String incidentId, incidentCode, companyName, status, description;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? faultType, assessment, resolution, chargeStatus;
  final double? chargeAmount;

  String? get faultLabel => switch (faultType?.toUpperCase()) {
    'TECHNICAL_FAULT' => 'Lỗi kỹ thuật / hao mòn',
    'CUSTOMER_FAULT' => 'Lỗi do khách hàng',
    _ => null,
  };

  factory EquipmentIncidentHistory.fromJson(Map<String, dynamic> json) =>
      EquipmentIncidentHistory(
        incidentId: json['incidentId'] as String,
        incidentCode: json['incidentCode'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        reportedAt: DateTime.parse(json['reportedAt'] as String).toLocal(),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String).toLocal()
            : null,
        description: json['description'] as String? ?? '',
        faultType: json['faultType'] as String?,
        assessment: json['assessment'] as String?,
        resolution: json['resolution'] as String?,
        chargeAmount: (json['chargeAmount'] as num?)?.toDouble(),
        chargeStatus: json['chargeStatus'] as String?,
      );
}

class EquipmentRentalHistory {
  const EquipmentRentalHistory({
    required this.rentalContractId,
    required this.contractCode,
    required this.companyName,
    required this.contractStatus,
    required this.startDate,
    required this.endDate,
    required this.handoverCode,
    required this.handoverType,
    required this.handoverDate,
    required this.handoverStatus,
  });

  final String rentalContractId,
      contractCode,
      companyName,
      contractStatus,
      handoverCode,
      handoverType,
      handoverStatus;
  final DateTime startDate, endDate, handoverDate;

  String get handoverTypeLabel => switch (handoverType.toUpperCase()) {
    'SUPPLEMENTARY' => 'Giao bù máy lỗi',
    'INCIDENT_REPLACEMENT' => 'Đổi sự cố',
    _ => 'Bàn giao gốc',
  };

  factory EquipmentRentalHistory.fromJson(Map<String, dynamic> json) =>
      EquipmentRentalHistory(
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        contractStatus: json['contractStatus'] as String? ?? '',
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        handoverCode: json['handoverCode'] as String? ?? '',
        handoverType: json['handoverType'] as String? ?? 'INITIAL',
        handoverDate: DateTime.parse(json['handoverDate'] as String),
        handoverStatus: json['handoverStatus'] as String? ?? '',
      );
}

class EquipmentLifecycleHistory {
  const EquipmentLifecycleHistory({
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.condition,
    required this.totalRentalsCount,
    required this.totalMaintenanceCount,
    required this.totalIncidentsCount,
    required this.totalLaborCost,
    required this.totalPartsCost,
    required this.totalMaintenanceCost,
    required this.maintenanceHistory,
    required this.incidentHistory,
    required this.rentalHistory,
    this.acquiredAt,
    this.acquisitionCost,
    this.note,
    this.repairToAcquisitionPercent,
  });

  final String equipmentId,
      serialNumber,
      equipmentModelId,
      modelCode,
      modelName,
      warehouseId,
      warehouseName,
      status,
      condition;
  final DateTime? acquiredAt;
  final double? acquisitionCost, repairToAcquisitionPercent;
  final String? note;
  final int totalRentalsCount, totalMaintenanceCount, totalIncidentsCount;
  final double totalLaborCost, totalPartsCost, totalMaintenanceCost;
  final List<EquipmentMaintenanceHistory> maintenanceHistory;
  final List<EquipmentIncidentHistory> incidentHistory;
  final List<EquipmentRentalHistory> rentalHistory;

  factory EquipmentLifecycleHistory.fromJson(Map<String, dynamic> json) =>
      EquipmentLifecycleHistory(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        warehouseId: json['warehouseId'] as String,
        warehouseName: json['warehouseName'] as String? ?? '',
        status: json['status'] as String? ?? '',
        condition: json['condition'] as String? ?? 'GOOD',
        acquiredAt: json['acquiredAt'] != null
            ? DateTime.parse(json['acquiredAt'] as String)
            : null,
        acquisitionCost: (json['acquisitionCost'] as num?)?.toDouble(),
        note: json['note'] as String?,
        totalRentalsCount: (json['totalRentalsCount'] as num?)?.toInt() ?? 0,
        totalMaintenanceCount:
            (json['totalMaintenanceCount'] as num?)?.toInt() ?? 0,
        totalIncidentsCount:
            (json['totalIncidentsCount'] as num?)?.toInt() ?? 0,
        totalLaborCost: (json['totalLaborCost'] as num?)?.toDouble() ?? 0,
        totalPartsCost: (json['totalPartsCost'] as num?)?.toDouble() ?? 0,
        totalMaintenanceCost:
            (json['totalMaintenanceCost'] as num?)?.toDouble() ?? 0,
        repairToAcquisitionPercent:
            (json['repairToAcquisitionPercent'] as num?)?.toDouble(),
        maintenanceHistory: [
          for (final e
              in json['maintenanceHistory'] as List<dynamic>? ?? const [])
            EquipmentMaintenanceHistory.fromJson(e as Map<String, dynamic>),
        ],
        incidentHistory: [
          for (final e in json['incidentHistory'] as List<dynamic>? ?? const [])
            EquipmentIncidentHistory.fromJson(e as Map<String, dynamic>),
        ],
        rentalHistory: [
          for (final e in json['rentalHistory'] as List<dynamic>? ?? const [])
            EquipmentRentalHistory.fromJson(e as Map<String, dynamic>),
        ],
      );
}
