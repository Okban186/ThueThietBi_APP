class MaintenanceTaskSummary {
  const MaintenanceTaskSummary({
    required this.id,
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.warehouseName,
    required this.equipmentStatus,
    required this.equipmentCondition,
    required this.type,
    required this.description,
    required this.status,
    required this.attachmentCount,
    required this.recordCount,
    required this.createdAt,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.result,
    this.assignedTechnicianStaffId,
    this.assignedTechnicianName,
    this.isAssignedToMe = false,
  });

  final String id,
      equipmentId,
      serialNumber,
      equipmentModelId,
      modelCode,
      modelName,
      warehouseName,
      equipmentStatus,
      equipmentCondition,
      type,
      description,
      status;
  final String? result, assignedTechnicianStaffId, assignedTechnicianName;
  final bool isAssignedToMe;
  final int attachmentCount, recordCount;
  final DateTime createdAt;
  final DateTime? scheduledAt, startedAt, completedAt;

  bool get isClaimed =>
      assignedTechnicianStaffId != null &&
      assignedTechnicianStaffId!.isNotEmpty;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get canComplete => isPending || isInProgress;

  String get typeLabel => switch (type.toUpperCase()) {
    'CORRECTIVE' => 'Sửa chữa',
    'PREVENTIVE' => 'Bảo trì định kỳ',
    _ => 'Kiểm tra kỹ thuật',
  };

  factory MaintenanceTaskSummary.fromJson(Map<String, dynamic> json) =>
      MaintenanceTaskSummary(
        id: json['id'] as String,
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        warehouseName: json['warehouseName'] as String? ?? '',
        equipmentStatus: json['equipmentStatus'] as String? ?? 'MAINTENANCE',
        equipmentCondition: json['equipmentCondition'] as String? ?? 'GOOD',
        type: json['type'] as String? ?? 'INSPECTION',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        scheduledAt: json['scheduledAt'] != null
            ? DateTime.parse(json['scheduledAt'] as String).toLocal()
            : null,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String).toLocal()
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String).toLocal()
            : null,
        result: json['result'] as String?,
        attachmentCount: (json['attachmentCount'] as num?)?.toInt() ?? 0,
        recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        assignedTechnicianStaffId: json['assignedTechnicianStaffId'] as String?,
        assignedTechnicianName: json['assignedTechnicianName'] as String?,
        isAssignedToMe: json['isAssignedToMe'] == true,
      );
}

class MaintenancePartItem {
  const MaintenancePartItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.note,
  });

  final String id, name;
  final double quantity, unitCost, totalCost;
  final String? note;

  factory MaintenancePartItem.fromJson(Map<String, dynamic> json) =>
      MaintenancePartItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
      );
}

class MaintenanceRecordItem {
  const MaintenanceRecordItem({
    required this.id,
    required this.performedByStaffId,
    required this.performedByName,
    required this.description,
    required this.laborCost,
    required this.partsTotalCost,
    required this.parts,
    this.completedAt,
    this.note,
  });

  final String id, performedByStaffId, performedByName, description;
  final double laborCost, partsTotalCost;
  final DateTime? completedAt;
  final String? note;
  final List<MaintenancePartItem> parts;

  double get totalCost => laborCost + partsTotalCost;

  factory MaintenanceRecordItem.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecordItem(
        id: json['id'] as String,
        performedByStaffId: json['performedByStaffId'] as String,
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
            MaintenancePartItem.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class MaintenanceIncidentContext {
  const MaintenanceIncidentContext({
    required this.incidentId,
    required this.incidentCode,
    required this.incidentItemId,
    required this.companyName,
    required this.incidentDescription,
    this.rentalContractId,
    this.contractCode,
    this.existingFaultType,
    this.existingChargeStatus,
    this.existingChargeAmount,
  });

  final String incidentId,
      incidentCode,
      incidentItemId,
      companyName,
      incidentDescription;
  final String? rentalContractId,
      contractCode,
      existingFaultType,
      existingChargeStatus;
  final double? existingChargeAmount;

  factory MaintenanceIncidentContext.fromJson(Map<String, dynamic> json) =>
      MaintenanceIncidentContext(
        incidentId: json['incidentId'] as String,
        incidentCode: json['incidentCode'] as String? ?? '',
        incidentItemId: json['incidentItemId'] as String,
        rentalContractId: json['rentalContractId'] as String?,
        contractCode: json['contractCode'] as String?,
        companyName: json['companyName'] as String? ?? '',
        incidentDescription: json['incidentDescription'] as String? ?? '',
        existingFaultType: json['existingFaultType'] as String?,
        existingChargeStatus: json['existingChargeStatus'] as String?,
        existingChargeAmount: (json['existingChargeAmount'] as num?)?.toDouble(),
      );
}

class MaintenanceTaskDetail {
  const MaintenanceTaskDetail({
    required this.task,
    required this.attachmentUrls,
    required this.records,
    this.incidentContext,
  });

  final MaintenanceTaskSummary task;
  final List<String> attachmentUrls;
  final List<MaintenanceRecordItem> records;
  final MaintenanceIncidentContext? incidentContext;

  factory MaintenanceTaskDetail.fromJson(Map<String, dynamic> json) =>
      MaintenanceTaskDetail(
        task: MaintenanceTaskSummary.fromJson(
          json['task'] as Map<String, dynamic>,
        ),
        attachmentUrls: (json['attachmentUrls'] as List<dynamic>? ?? const [])
            .cast<String>(),
        records: [
          for (final e in json['records'] as List<dynamic>? ?? const [])
            MaintenanceRecordItem.fromJson(e as Map<String, dynamic>),
        ],
        incidentContext: json['incidentContext'] != null
            ? MaintenanceIncidentContext.fromJson(
                json['incidentContext'] as Map<String, dynamic>,
              )
            : null,
      );
}

class MaintenancePartInput {
  const MaintenancePartInput({
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.note,
  });

  final String name;
  final double quantity, unitCost;
  final String? note;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'quantity': quantity,
    'unitCost': unitCost,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

class CompleteMaintenanceResult {
  const CompleteMaintenanceResult({
    required this.taskId,
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentStatus,
    required this.equipmentCondition,
    required this.totalCost,
    required this.message,
    this.followUpTaskId,
  });

  final String taskId,
      equipmentId,
      serialNumber,
      equipmentStatus,
      equipmentCondition,
      message;
  final double totalCost;
  final String? followUpTaskId;

  factory CompleteMaintenanceResult.fromJson(Map<String, dynamic> json) =>
      CompleteMaintenanceResult(
        taskId: json['taskId'] as String,
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentStatus: json['equipmentStatus'] as String? ?? '',
        equipmentCondition: json['equipmentCondition'] as String? ?? '',
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        followUpTaskId: json['followUpTaskId'] as String?,
        message: json['message'] as String? ?? 'Đã hoàn tất bảo trì.',
      );
}
