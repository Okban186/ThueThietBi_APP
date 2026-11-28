import 'technician_models.dart';

class TechnicianIncidentSummary {
  const TechnicianIncidentSummary({
    required this.incidentId,
    required this.incidentCode,
    required this.assignmentMode,
    required this.isLeader,
    required this.companyId,
    required this.companyName,
    required this.description,
    required this.status,
    required this.reportedAt,
    required this.itemCount,
    required this.serialNumbers,
    this.serviceAddress,
    this.contactName,
    this.contactPhone,
    this.serviceAssignmentId,
    this.assignmentStatus,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
  });

  final String incidentId,
      incidentCode,
      assignmentMode,
      companyId,
      companyName,
      description,
      status;
  final bool isLeader;
  final String? serviceAddress,
      contactName,
      contactPhone,
      serviceAssignmentId,
      assignmentStatus;
  final DateTime reportedAt;
  final DateTime? scheduledStartAt;
  final int? estimatedDurationMinutes;
  final int itemCount;
  final List<String> serialNumbers;

  bool get isOnSiteMode => assignmentMode.toUpperCase() == 'ON_SITE';

  factory TechnicianIncidentSummary.fromJson(Map<String, dynamic> json) =>
      TechnicianIncidentSummary(
        incidentId: json['incidentId'] as String,
        incidentCode: json['incidentCode'] as String? ?? '',
        assignmentMode: json['assignmentMode'] as String? ?? 'REMOTE',
        isLeader: json['isLeader'] == true,
        companyId: json['companyId'] as String,
        companyName: json['companyName'] as String? ?? '',
        serviceAddress: json['serviceAddress'] as String?,
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        reportedAt: DateTime.parse(json['reportedAt'] as String).toLocal(),
        serviceAssignmentId: json['serviceAssignmentId'] as String?,
        assignmentStatus: json['assignmentStatus'] as String?,
        scheduledStartAt: json['scheduledStartAt'] != null
            ? DateTime.parse(json['scheduledStartAt'] as String).toLocal()
            : null,
        estimatedDurationMinutes:
            (json['estimatedDurationMinutes'] as num?)?.toInt(),
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        serialNumbers: (json['serialNumbers'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
}

class TechnicianIncidentItemDetail {
  const TechnicianIncidentItemDetail({
    required this.incidentItemId,
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.equipmentStatus,
    required this.equipmentCondition,
    this.customerDescription,
    this.assessment,
    this.note,
    this.rentalContractId,
    this.contractCode,
  });

  final String incidentItemId,
      equipmentId,
      serialNumber,
      equipmentModelId,
      modelCode,
      modelName,
      equipmentStatus,
      equipmentCondition;
  final String? customerDescription,
      assessment,
      note,
      rentalContractId,
      contractCode;

  factory TechnicianIncidentItemDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianIncidentItemDetail(
        incidentItemId: json['incidentItemId'] as String,
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String? ?? '',
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        equipmentStatus: json['equipmentStatus'] as String? ?? '',
        equipmentCondition: json['equipmentCondition'] as String? ?? '',
        customerDescription: json['customerDescription'] as String?,
        assessment: json['assessment'] as String?,
        note: json['note'] as String?,
        rentalContractId: json['rentalContractId'] as String?,
        contractCode: json['contractCode'] as String?,
      );
}

class TechnicianIncidentDetail {
  const TechnicianIncidentDetail({
    required this.incidentId,
    required this.incidentCode,
    required this.assignmentMode,
    required this.isLeader,
    required this.companyId,
    required this.companyName,
    required this.description,
    required this.status,
    required this.reportedAt,
    required this.members,
    required this.items,
    required this.attachmentUrls,
    this.serviceAddress,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
    this.resolution,
    this.resolvedAt,
    this.serviceAssignmentId,
    this.assignmentStatus,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
    this.startedAt,
    this.completedAt,
    this.depot,
  });

  final String incidentId,
      incidentCode,
      assignmentMode,
      companyId,
      companyName,
      description,
      status;
  final bool isLeader;
  final String? serviceAddress,
      contactName,
      contactPhone,
      resolution,
      serviceAssignmentId,
      assignmentStatus;
  final double? latitude, longitude;
  final DateTime reportedAt;
  final DateTime? resolvedAt, scheduledStartAt, startedAt, completedAt;
  final int? estimatedDurationMinutes;
  final TechnicianDepot? depot;
  final List<TechnicianMember> members;
  final List<TechnicianIncidentItemDetail> items;
  final List<String> attachmentUrls;

  bool get isOnSiteMode => assignmentMode.toUpperCase() == 'ON_SITE';
  bool get canArrive =>
      isOnSiteMode && isLeader && status.toUpperCase() == 'DISPATCHING';
  bool get canResolve =>
      isLeader &&
      const {
        'REMOTE_SUPPORT',
        'DISPATCHING',
        'ON_SITE',
      }.contains(status.toUpperCase());

  factory TechnicianIncidentDetail.fromJson(Map<String, dynamic> json) =>
      TechnicianIncidentDetail(
        incidentId: json['incidentId'] as String,
        incidentCode: json['incidentCode'] as String? ?? '',
        assignmentMode: json['assignmentMode'] as String? ?? 'REMOTE',
        isLeader: json['isLeader'] == true,
        companyId: json['companyId'] as String,
        companyName: json['companyName'] as String? ?? '',
        serviceAddress: json['serviceAddress'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        resolution: json['resolution'] as String?,
        reportedAt: DateTime.parse(json['reportedAt'] as String).toLocal(),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String).toLocal()
            : null,
        serviceAssignmentId: json['serviceAssignmentId'] as String?,
        assignmentStatus: json['assignmentStatus'] as String?,
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
        items: [
          for (final e in json['items'] as List<dynamic>? ?? const [])
            TechnicianIncidentItemDetail.fromJson(e as Map<String, dynamic>),
        ],
        attachmentUrls: (json['attachmentUrls'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
}

class TechnicianIncidentAssessmentInput {
  const TechnicianIncidentAssessmentInput({
    required this.equipmentId,
    this.assessment,
    this.note,
    this.needsReturn = true,
  });

  final String equipmentId;
  final String? assessment, note;
  final bool needsReturn;

  Map<String, dynamic> toJson() => {
    'equipmentId': equipmentId,
    if (assessment != null && assessment!.trim().isNotEmpty)
      'assessment': assessment!.trim(),
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    'needsReturn': needsReturn,
  };
}

class TechnicianResolveIncidentResult {
  const TechnicianResolveIncidentResult({
    required this.incidentId,
    required this.incidentCode,
    required this.status,
    required this.autoReturnCodes,
    required this.message,
  });

  final String incidentId, incidentCode, status, message;
  final List<String> autoReturnCodes;

  factory TechnicianResolveIncidentResult.fromJson(Map<String, dynamic> json) =>
      TechnicianResolveIncidentResult(
        incidentId: json['incidentId'] as String,
        incidentCode: json['incidentCode'] as String? ?? '',
        status: json['status'] as String? ?? '',
        autoReturnCodes: (json['autoReturnCodes'] as List<dynamic>? ?? const [])
            .cast<String>(),
        message: json['message'] as String? ?? 'Đã cập nhật sự cố.',
      );
}
