class TechnicianMediaAttachment {
  const TechnicianMediaAttachment({
    required this.storageFileId,
    required this.url,
    required this.mediaType,
    this.fileName,
    this.sizeBytes,
  });

  final String storageFileId, url, mediaType;
  final String? fileName;
  final int? sizeBytes;

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO';

  factory TechnicianMediaAttachment.fromJson(Map<String, dynamic> json) =>
      TechnicianMediaAttachment(
        storageFileId: json['storageFileId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        mediaType: json['mediaType'] as String? ?? 'IMAGE',
        fileName: json['fileName'] as String?,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      );
}

class TechnicianDashboard {
  const TechnicianDashboard({
    required this.pendingTripsCount,
    required this.inProgressTripsCount,
    required this.completedTripsTodayCount,
    required this.pendingMaintenanceCount,
    required this.inProgressMaintenanceCount,
    required this.openIncidentsCount,
    this.activeTrips = const [],
  });

  final int pendingTripsCount;
  final int inProgressTripsCount;
  final int completedTripsTodayCount;
  final int pendingMaintenanceCount;
  final int inProgressMaintenanceCount;
  final int openIncidentsCount;
  final List<TechnicianAssignmentSummary> activeTrips;

  static const empty = TechnicianDashboard(
    pendingTripsCount: 0,
    inProgressTripsCount: 0,
    completedTripsTodayCount: 0,
    pendingMaintenanceCount: 0,
    inProgressMaintenanceCount: 0,
    openIncidentsCount: 0,
    activeTrips: [],
  );

  factory TechnicianDashboard.fromJson(Map<String, dynamic> json) =>
      TechnicianDashboard(
        pendingTripsCount: (json['pendingTripsCount'] as num?)?.toInt() ?? 0,
        inProgressTripsCount:
            (json['inProgressTripsCount'] as num?)?.toInt() ?? 0,
        completedTripsTodayCount:
            (json['completedTripsTodayCount'] as num?)?.toInt() ?? 0,
        pendingMaintenanceCount:
            (json['pendingMaintenanceCount'] as num?)?.toInt() ?? 0,
        inProgressMaintenanceCount:
            (json['inProgressMaintenanceCount'] as num?)?.toInt() ?? 0,
        openIncidentsCount: (json['openIncidentsCount'] as num?)?.toInt() ?? 0,
        activeTrips: [
          for (final e in json['activeTrips'] as List<dynamic>? ?? const [])
            TechnicianAssignmentSummary.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class TechnicianDepot {
  const TechnicianDepot({
    required this.warehouseName,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String warehouseName;
  final String? address;
  final double? latitude;
  final double? longitude;

  factory TechnicianDepot.fromJson(Map<String, dynamic> json) =>
      TechnicianDepot(
        warehouseName: json['warehouseName'] as String? ?? 'Kho chính',
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class TechnicianMember {
  const TechnicianMember({
    required this.staffId,
    required this.employeeCode,
    required this.fullName,
    required this.role,
    this.phone,
  });

  final String staffId, employeeCode, fullName, role;
  final String? phone;

  bool get isLeader => role.toUpperCase() == 'LEADER';

  factory TechnicianMember.fromJson(Map<String, dynamic> json) =>
      TechnicianMember(
        staffId: json['staffId'] as String,
        employeeCode: json['employeeCode'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'MEMBER',
      );
}

class TechnicianHandoverStopSummary {
  const TechnicianHandoverStopSummary({
    required this.handoverNoteId,
    required this.handoverCode,
    required this.handoverType,
    required this.rentalContractId,
    required this.contractCode,
    required this.companyName,
    required this.receivedByName,
    required this.stopOrder,
    required this.estimatedTravelMinutes,
    required this.estimatedInstallMinutes,
    required this.status,
    required this.itemCount,
    required this.deliveryAttemptNumber,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.receivedByPhone,
    this.failedReason,
    this.failedAt,
  });

  final String handoverNoteId,
      handoverCode,
      handoverType,
      rentalContractId,
      contractCode,
      companyName,
      receivedByName,
      status;
  final String? deliveryAddress, receivedByPhone, failedReason;
  final double? deliveryLatitude, deliveryLongitude;
  final int stopOrder,
      estimatedTravelMinutes,
      estimatedInstallMinutes,
      itemCount,
      deliveryAttemptNumber;
  final DateTime? failedAt;

  bool get isSupplementary => handoverType.toUpperCase() == 'SUPPLEMENTARY';
  bool get isIncidentReplacement => handoverType.toUpperCase() == 'INCIDENT_REPLACEMENT';

  factory TechnicianHandoverStopSummary.fromJson(Map<String, dynamic> json) =>
      TechnicianHandoverStopSummary(
        handoverNoteId: json['handoverNoteId'] as String,
        handoverCode: json['handoverCode'] as String? ?? '',
        handoverType: json['handoverType'] as String? ?? 'INITIAL',
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        deliveryAddress: json['deliveryAddress'] as String?,
        deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
        receivedByName: json['receivedByName'] as String? ?? '',
        receivedByPhone: json['receivedByPhone'] as String?,
        stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
        estimatedTravelMinutes:
            (json['estimatedTravelMinutes'] as num?)?.toInt() ?? 0,
        estimatedInstallMinutes:
            (json['estimatedInstallMinutes'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'PREPARING',
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        deliveryAttemptNumber:
            (json['deliveryAttemptNumber'] as num?)?.toInt() ?? 1,
        failedReason: json['failedReason'] as String?,
        failedAt: json['failedAt'] != null
            ? DateTime.parse(json['failedAt'] as String).toLocal()
            : null,
      );
}

class TechnicianAssignmentSummary {
  const TechnicianAssignmentSummary({
    required this.assignmentId,
    required this.type,
    required this.title,
    required this.status,
    required this.isLeader,
    required this.stopCount,
    required this.completedStopCount,
    required this.members,
    required this.stops,
    this.description,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
    this.startedAt,
    this.completedAt,
  });

  final String assignmentId, type, title, status;
  final String? description;
  final bool isLeader;
  final DateTime? scheduledStartAt, startedAt, completedAt;
  final int? estimatedDurationMinutes;
  final int stopCount, completedStopCount;
  final List<TechnicianMember> members;
  final List<TechnicianHandoverStopSummary> stops;

  bool get isRetrieval => type.toUpperCase() == 'RETRIEVAL';

  factory TechnicianAssignmentSummary.fromJson(Map<String, dynamic> json) =>
      TechnicianAssignmentSummary(
        assignmentId: json['assignmentId'] as String,
        type: json['type'] as String? ?? 'HANDOVER',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        isLeader: json['isLeader'] == true,
        scheduledStartAt: json['scheduledStartAt'] != null
            ? DateTime.parse(json['scheduledStartAt'] as String).toLocal()
            : null,
        estimatedDurationMinutes:
            (json['estimatedDurationMinutes'] as num?)?.toInt(),
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String).toLocal()
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String).toLocal()
            : null,
        stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
        completedStopCount: (json['completedStopCount'] as num?)?.toInt() ?? 0,
        members: [
          for (final e in json['members'] as List<dynamic>? ?? const [])
            TechnicianMember.fromJson(e as Map<String, dynamic>),
        ],
        stops: [
          for (final e in json['stops'] as List<dynamic>? ?? const [])
            TechnicianHandoverStopSummary.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class TechnicianEquipmentItem {
  const TechnicianEquipmentItem({
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.condition,
    required this.status,
    this.note,
  });

  final String equipmentId,
      serialNumber,
      equipmentModelId,
      modelCode,
      modelName,
      condition,
      status;
  final String? note;

  factory TechnicianEquipmentItem.fromJson(Map<String, dynamic> json) =>
      TechnicianEquipmentItem(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        condition: json['condition'] as String? ?? 'GOOD',
        status: json['status'] as String? ?? 'RESERVED',
        note: json['note'] as String?,
      );
}

class TechnicianEquipmentGroup {
  const TechnicianEquipmentGroup({
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.quantity,
    required this.items,
  });

  final String equipmentModelId, modelCode, modelName;
  final int quantity;
  final List<TechnicianEquipmentItem> items;

  factory TechnicianEquipmentGroup.fromJson(Map<String, dynamic> json) =>
      TechnicianEquipmentGroup(
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        items: [
          for (final e in json['items'] as List<dynamic>? ?? const [])
            TechnicianEquipmentItem.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class TechnicianFirstPaymentInfo {
  const TechnicianFirstPaymentInfo({
    required this.rentalContractId,
    required this.rentalType,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.hasPendingCash,
    required this.shippingFeeIncluded,
    this.firstInstallmentChargeId,
  });

  final String rentalContractId, rentalType, description, status;
  final String? firstInstallmentChargeId;
  final double amount, paidAmount, remainingAmount, shippingFeeIncluded;
  final bool hasPendingCash;

  bool get isPaid => status.toUpperCase() == 'PAID' || remainingAmount <= 0;
  bool get isLongTerm => rentalType.toUpperCase() == 'LONG_TERM';

  factory TechnicianFirstPaymentInfo.fromJson(Map<String, dynamic> json) =>
      TechnicianFirstPaymentInfo(
        rentalContractId: json['rentalContractId'] as String,
        rentalType: json['rentalType'] as String? ?? 'SHORT_TERM',
        firstInstallmentChargeId: json['firstInstallmentChargeId'] as String?,
        description: json['description'] as String? ?? 'Tiền thuê đợt 1',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'UNPAID',
        hasPendingCash: json['hasPendingCash'] == true,
        shippingFeeIncluded:
            (json['shippingFeeIncluded'] as num?)?.toDouble() ?? 0,
      );
}

class TechnicianHandoverLookupSerial {
  const TechnicianHandoverLookupSerial({
    required this.belongsToHandover,
    required this.serialNumber,
    this.equipmentId,
    this.equipmentModelId,
    this.modelCode,
    this.modelName,
    this.condition,
    this.message,
  });

  final bool belongsToHandover;
  final String serialNumber;
  final String? equipmentId,
      equipmentModelId,
      modelCode,
      modelName,
      condition,
      message;

  factory TechnicianHandoverLookupSerial.fromJson(Map<String, dynamic> json) =>
      TechnicianHandoverLookupSerial(
        belongsToHandover: json['belongsToHandover'] == true,
        equipmentId: json['equipmentId'] as String?,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String?,
        modelCode: json['modelCode'] as String?,
        modelName: json['modelName'] as String?,
        condition: json['condition'] as String?,
        message: json['message'] as String?,
      );
}

class TechnicianDefectiveIssueItemDetail {
  const TechnicianDefectiveIssueItemDetail({
    required this.issueItemId,
    required this.equipmentId,
    required this.serialNumber,
    required this.modelCode,
    required this.modelName,
    required this.issueType,
    required this.status,
    required this.itemPhotos,
    this.description,
  });

  final String issueItemId,
      equipmentId,
      serialNumber,
      modelCode,
      modelName,
      issueType,
      status;
  final String? description;
  final List<TechnicianMediaAttachment> itemPhotos;

  String get issueTypeLabel => switch (issueType.toUpperCase()) {
    'DAMAGED' => 'Hư hỏng vật lý / móp vỡ',
    'MALFUNCTION' => 'Lỗi kỹ thuật / không hoạt động',
    _ => 'Lỗi khác',
  };

  factory TechnicianDefectiveIssueItemDetail.fromJson(
    Map<String, dynamic> json,
  ) => TechnicianDefectiveIssueItemDetail(
    issueItemId: json['issueItemId'] as String,
    equipmentId: json['equipmentId'] as String,
    serialNumber: json['serialNumber'] as String? ?? '',
    modelCode: json['modelCode'] as String? ?? '',
    modelName: json['modelName'] as String? ?? '',
    issueType: json['issueType'] as String? ?? 'DAMAGED',
    description: json['description'] as String?,
    status: json['status'] as String? ?? 'OPEN',
    itemPhotos: [
      for (final e in json['itemPhotos'] as List<dynamic>? ?? const [])
        TechnicianMediaAttachment.fromJson(e as Map<String, dynamic>),
    ],
  );
}

class TechnicianHandoverResultDetail {
  const TechnicianHandoverResultDetail({
    required this.deliveredGoodCount,
    required this.defectiveCount,
    required this.sceneMedia,
    required this.sharedIssueMedia,
    required this.deliveredGoodItems,
    required this.defectiveItems,
    this.issueDescription,
    this.autoReturnId,
    this.autoReturnCode,
    this.autoReturnStatus,
  });

  final int deliveredGoodCount, defectiveCount;
  final String? issueDescription,
      autoReturnId,
      autoReturnCode,
      autoReturnStatus;
  final List<TechnicianMediaAttachment> sceneMedia;
  final List<TechnicianMediaAttachment> sharedIssueMedia;
  final List<TechnicianEquipmentItem> deliveredGoodItems;
  final List<TechnicianDefectiveIssueItemDetail> defectiveItems;

  factory TechnicianHandoverResultDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianHandoverResultDetail(
        deliveredGoodCount: (json['deliveredGoodCount'] as num?)?.toInt() ?? 0,
        defectiveCount: (json['defectiveCount'] as num?)?.toInt() ?? 0,
        issueDescription: json['issueDescription'] as String?,
        autoReturnId: json['autoReturnId'] as String?,
        autoReturnCode: json['autoReturnCode'] as String?,
        autoReturnStatus: json['autoReturnStatus'] as String?,
        sceneMedia: [
          for (final e in json['sceneMedia'] as List<dynamic>? ?? const [])
            TechnicianMediaAttachment.fromJson(e as Map<String, dynamic>),
        ],
        sharedIssueMedia: [
          for (final e
              in json['sharedIssueMedia'] as List<dynamic>? ?? const [])
            TechnicianMediaAttachment.fromJson(e as Map<String, dynamic>),
        ],
        deliveredGoodItems: [
          for (final e
              in json['deliveredGoodItems'] as List<dynamic>? ?? const [])
            TechnicianEquipmentItem.fromJson(e as Map<String, dynamic>),
        ],
        defectiveItems: [
          for (final e in json['defectiveItems'] as List<dynamic>? ?? const [])
            TechnicianDefectiveIssueItemDetail.fromJson(
              e as Map<String, dynamic>,
            ),
        ],
      );
}

class TechnicianHandoverStopDetail {
  const TechnicianHandoverStopDetail({
    required this.handoverNoteId,
    required this.handoverCode,
    required this.handoverType,
    required this.rentalContractId,
    required this.contractCode,
    required this.contractStatus,
    required this.companyName,
    required this.receivedByName,
    required this.stopOrder,
    required this.estimatedTravelMinutes,
    required this.estimatedInstallMinutes,
    required this.status,
    required this.deliveryAttemptNumber,
    required this.equipmentGroups,
    required this.evidenceUrls,
    this.evidenceMedia = const [],
    this.deliveryResult,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryNote,
    this.receivedByPhone,
    this.failedReason,
    this.failedAt,
    this.note,
    this.firstPayment,
  });

  final String handoverNoteId,
      handoverCode,
      handoverType,
      rentalContractId,
      contractCode,
      contractStatus,
      companyName,
      receivedByName,
      status;
  final String? deliveryAddress,
      deliveryNote,
      receivedByPhone,
      failedReason,
      note;
  final double? deliveryLatitude, deliveryLongitude;
  final int stopOrder,
      estimatedTravelMinutes,
      estimatedInstallMinutes,
      deliveryAttemptNumber;
  final DateTime? failedAt;
  final List<TechnicianEquipmentGroup> equipmentGroups;
  final List<String> evidenceUrls;
  final List<TechnicianMediaAttachment> evidenceMedia;
  final TechnicianHandoverResultDetail? deliveryResult;
  final TechnicianFirstPaymentInfo? firstPayment;

  bool get isSupplementary => handoverType.toUpperCase() == 'SUPPLEMENTARY';
  bool get isIncidentReplacement => handoverType.toUpperCase() == 'INCIDENT_REPLACEMENT';
  bool get isShipping => status.toUpperCase() == 'SHIPPING';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  int get totalEquipmentCount =>
      equipmentGroups.fold(0, (sum, g) => sum + g.quantity);

  factory TechnicianHandoverStopDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianHandoverStopDetail(
        handoverNoteId: json['handoverNoteId'] as String,
        handoverCode: json['handoverCode'] as String? ?? '',
        handoverType: json['handoverType'] as String? ?? 'INITIAL',
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        contractStatus: json['contractStatus'] as String? ?? 'PREPARING',
        companyName: json['companyName'] as String? ?? '',
        deliveryAddress: json['deliveryAddress'] as String?,
        deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble(),
        deliveryNote: json['deliveryNote'] as String?,
        receivedByName: json['receivedByName'] as String? ?? '',
        receivedByPhone: json['receivedByPhone'] as String?,
        stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
        estimatedTravelMinutes:
            (json['estimatedTravelMinutes'] as num?)?.toInt() ?? 0,
        estimatedInstallMinutes:
            (json['estimatedInstallMinutes'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'PREPARING',
        deliveryAttemptNumber:
            (json['deliveryAttemptNumber'] as num?)?.toInt() ?? 1,
        failedReason: json['failedReason'] as String?,
        failedAt: json['failedAt'] != null
            ? DateTime.parse(json['failedAt'] as String).toLocal()
            : null,
        note: json['note'] as String?,
        equipmentGroups: [
          for (final e in json['equipmentGroups'] as List<dynamic>? ?? const [])
            TechnicianEquipmentGroup.fromJson(e as Map<String, dynamic>),
        ],
        evidenceUrls: (json['evidenceUrls'] as List<dynamic>? ?? const [])
            .cast<String>(),
        evidenceMedia: [
          for (final e in json['evidenceMedia'] as List<dynamic>? ?? const [])
            TechnicianMediaAttachment.fromJson(e as Map<String, dynamic>),
        ],
        deliveryResult: json['deliveryResult'] != null
            ? TechnicianHandoverResultDetail.fromJson(
                json['deliveryResult'] as Map<String, dynamic>,
              )
            : null,
        firstPayment: json['firstPayment'] != null
            ? TechnicianFirstPaymentInfo.fromJson(
                json['firstPayment'] as Map<String, dynamic>,
              )
            : null,
      );
}

class TechnicianRetrievalItem {
  const TechnicianRetrievalItem({
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.condition,
    required this.itemStatus,
    this.note,
  });

  final String equipmentId,
      serialNumber,
      equipmentModelId,
      modelCode,
      modelName,
      condition,
      itemStatus;
  final String? note;

  factory TechnicianRetrievalItem.fromJson(Map<String, dynamic> json) =>
      TechnicianRetrievalItem(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        condition: json['condition'] as String? ?? 'GOOD',
        itemStatus: json['itemStatus'] as String? ?? 'RETURNED',
        note: json['note'] as String?,
      );
}

class TechnicianRetrievalStopDetail {
  const TechnicianRetrievalStopDetail({
    required this.returnId,
    required this.returnCode,
    required this.rentalContractId,
    required this.contractCode,
    required this.contractStatus,
    required this.companyName,
    required this.contractEndDate,
    required this.stopOrder,
    required this.estimatedTravelMinutes,
    required this.estimatedUninstallMinutes,
    required this.status,
    required this.items,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.contactName,
    this.contactPhone,
    this.note,
  });

  final String returnId,
      returnCode,
      rentalContractId,
      contractCode,
      contractStatus,
      companyName,
      status;
  final String? pickupAddress, contactName, contactPhone, note;
  final double? pickupLatitude, pickupLongitude;
  final DateTime contractEndDate;
  final int stopOrder, estimatedTravelMinutes, estimatedUninstallMinutes;
  final List<TechnicianRetrievalItem> items;

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isProcessing => status.toUpperCase() == 'PROCESSING';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  factory TechnicianRetrievalStopDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianRetrievalStopDetail(
        returnId: json['returnId'] as String,
        returnCode: json['returnCode'] as String? ?? '',
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        contractStatus: json['contractStatus'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        pickupAddress: json['pickupAddress'] as String?,
        pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
        pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        contractEndDate: DateTime.parse(json['contractEndDate'] as String),
        stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
        estimatedTravelMinutes:
            (json['estimatedTravelMinutes'] as num?)?.toInt() ?? 0,
        estimatedUninstallMinutes:
            (json['estimatedUninstallMinutes'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'DRAFT',
        note: json['note'] as String?,
        items: [
          for (final e in json['items'] as List<dynamic>? ?? const [])
            TechnicianRetrievalItem.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class TechnicianCompleteRetrievalItemInput {
  const TechnicianCompleteRetrievalItemInput({
    required this.equipmentId,
    required this.status,
    this.condition,
    this.note,
  });

  final String equipmentId, status;
  final String? condition, note;

  Map<String, dynamic> toJson() => {
    'equipmentId': equipmentId,
    'status': status,
    if (condition != null && condition!.isNotEmpty) 'condition': condition,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

class TechnicianCompleteRetrievalResult {
  const TechnicianCompleteRetrievalResult({
    required this.returnId,
    required this.returnCode,
    required this.returnedCount,
    required this.missingCount,
    required this.message,
  });

  final String returnId, returnCode, message;
  final int returnedCount, missingCount;

  factory TechnicianCompleteRetrievalResult.fromJson(
    Map<String, dynamic> json,
  ) => TechnicianCompleteRetrievalResult(
    returnId: json['returnId'] as String,
    returnCode: json['returnCode'] as String? ?? '',
    returnedCount: (json['returnedCount'] as num?)?.toInt() ?? 0,
    missingCount: (json['missingCount'] as num?)?.toInt() ?? 0,
    message: json['message'] as String? ?? 'Đã xác nhận thu hồi tại hiện trường.',
  );
}

class TechnicianAssignmentDetail {
  const TechnicianAssignmentDetail({
    required this.assignmentId,
    required this.type,
    required this.title,
    required this.status,
    required this.isLeader,
    required this.members,
    required this.stops,
    required this.assignmentAttachmentUrls,
    this.retrievalStops = const [],
    this.assignmentMedia = const [],
    this.description,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
    this.startedAt,
    this.completedAt,
    this.depot,
  });

  final String assignmentId, type, title, status;
  final String? description;
  final bool isLeader;
  final DateTime? scheduledStartAt, startedAt, completedAt;
  final int? estimatedDurationMinutes;
  final TechnicianDepot? depot;
  final List<TechnicianMember> members;
  final List<TechnicianHandoverStopDetail> stops;
  final List<TechnicianRetrievalStopDetail> retrievalStops;
  final List<String> assignmentAttachmentUrls;
  final List<TechnicianMediaAttachment> assignmentMedia;

  bool get isRetrieval => type.toUpperCase() == 'RETRIEVAL';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  factory TechnicianAssignmentDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianAssignmentDetail(
        assignmentId: json['assignmentId'] as String,
        type: json['type'] as String? ?? 'HANDOVER',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        isLeader: json['isLeader'] == true,
        scheduledStartAt: json['scheduledStartAt'] != null
            ? DateTime.parse(json['scheduledStartAt'] as String).toLocal()
            : null,
        estimatedDurationMinutes:
            (json['estimatedDurationMinutes'] as num?)?.toInt(),
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String).toLocal()
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String).toLocal()
            : null,
        depot: json['depot'] != null
            ? TechnicianDepot.fromJson(json['depot'] as Map<String, dynamic>)
            : null,
        members: [
          for (final e in json['members'] as List<dynamic>? ?? const [])
            TechnicianMember.fromJson(e as Map<String, dynamic>),
        ],
        stops: [
          for (final e in json['stops'] as List<dynamic>? ?? const [])
            TechnicianHandoverStopDetail.fromJson(e as Map<String, dynamic>),
        ],
        retrievalStops: [
          for (final e in json['retrievalStops'] as List<dynamic>? ?? const [])
            TechnicianRetrievalStopDetail.fromJson(e as Map<String, dynamic>),
        ],
        assignmentAttachmentUrls:
            (json['assignmentAttachmentUrls'] as List<dynamic>? ?? const [])
                .cast<String>(),
        assignmentMedia: [
          for (final e in json['assignmentMedia'] as List<dynamic>? ?? const [])
            TechnicianMediaAttachment.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class TechnicianDefectiveItemInput {
  const TechnicianDefectiveItemInput({
    required this.equipmentId,
    this.issueType = 'DAMAGED',
    this.description,
    this.attachmentFileIds = const [],
  });

  final String equipmentId;
  final String issueType;
  final String? description;
  final List<String> attachmentFileIds;

  Map<String, dynamic> toJson() => {
    'equipmentId': equipmentId,
    'issueType': issueType,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    'attachmentFileIds': attachmentFileIds,
  };
}

class TechnicianCompleteHandoverResult {
  const TechnicianCompleteHandoverResult({
    required this.handoverNoteId,
    required this.handoverCode,
    required this.contractStatus,
    required this.deliveredGoodCount,
    required this.defectiveCount,
    required this.message,
    this.autoReturnId,
    this.autoReturnCode,
  });

  final String handoverNoteId, handoverCode, contractStatus, message;
  final int deliveredGoodCount, defectiveCount;
  final String? autoReturnId, autoReturnCode;

  factory TechnicianCompleteHandoverResult.fromJson(
    Map<String, dynamic> json,
  ) => TechnicianCompleteHandoverResult(
    handoverNoteId: json['handoverNoteId'] as String,
    handoverCode: json['handoverCode'] as String? ?? '',
    contractStatus: json['contractStatus'] as String? ?? '',
    deliveredGoodCount: (json['deliveredGoodCount'] as num?)?.toInt() ?? 0,
    defectiveCount: (json['defectiveCount'] as num?)?.toInt() ?? 0,
    autoReturnId: json['autoReturnId'] as String?,
    autoReturnCode: json['autoReturnCode'] as String?,
    message: json['message'] as String? ?? 'Đã hoàn tất bàn giao.',
  );
}

class TechnicianFailHandoverResult {
  const TechnicianFailHandoverResult({
    required this.handoverNoteId,
    required this.handoverCode,
    required this.deliveryAttemptNumber,
    required this.penaltyApplied,
    required this.penaltyAmount,
    required this.message,
  });

  final String handoverNoteId, handoverCode, message;
  final int deliveryAttemptNumber;
  final bool penaltyApplied;
  final double penaltyAmount;

  factory TechnicianFailHandoverResult.fromJson(Map<String, dynamic> json) =>
      TechnicianFailHandoverResult(
        handoverNoteId: json['handoverNoteId'] as String,
        handoverCode: json['handoverCode'] as String? ?? '',
        deliveryAttemptNumber:
            (json['deliveryAttemptNumber'] as num?)?.toInt() ?? 0,
        penaltyApplied: json['penaltyApplied'] == true,
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        message: json['message'] as String? ?? 'Đã ghi nhận giao thất bại.',
      );
}
