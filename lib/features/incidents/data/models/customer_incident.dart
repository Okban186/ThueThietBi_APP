/// Trạng thái sự cố (khách xem).
enum IncidentStatus {
  open('OPEN', 'Chờ tiếp nhận'),
  remoteSupport('REMOTE_SUPPORT', 'Đang hỗ trợ từ xa'),
  dispatching('DISPATCHING', 'Đang điều phối'),
  onSite('ON_SITE', 'Kỹ thuật viên đang xử lý'),
  returnRequired('RETURN_REQUIRED', 'Cần thu hồi máy'),
  resolved('RESOLVED', 'Đã xử lý'),
  cancelled('CANCELLED', 'Đã hủy');

  const IncidentStatus(this.code, this.label);

  final String code;
  final String label;

  static IncidentStatus fromCode(String code) => values.firstWhere(
    (s) => s.code == code.toUpperCase(),
    orElse: () => open,
  );
}

/// Máy công ty đang thuê (`GET /api/customer/equipments`).
class RentedEquipment {
  const RentedEquipment({
    required this.equipmentId,
    required this.serialNumber,
    required this.modelCode,
    required this.modelName,
    required this.contractId,
    required this.contractCode,
  });

  final String equipmentId, serialNumber, modelCode, modelName;
  final String contractId, contractCode;

  factory RentedEquipment.fromJson(Map<String, dynamic> json) =>
      RentedEquipment(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String,
        modelCode: json['modelCode'] as String,
        modelName: json['modelName'] as String,
        contractId: json['contractId'] as String,
        contractCode: json['contractCode'] as String,
      );
}

/// Sự cố (danh sách).
class CustomerIncident {
  const CustomerIncident({
    required this.id,
    required this.incidentCode,
    required this.description,
    required this.status,
    required this.reportedAt,
    required this.itemCount,
    this.resolvedAt,
    this.resolution,
    this.contactName,
    this.contactPhone,
    this.reportedByName,
  });

  final String id, incidentCode, description;
  final IncidentStatus status;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? resolution, contactName, contactPhone, reportedByName;
  final int itemCount;

  factory CustomerIncident.fromJson(Map<String, dynamic> json) =>
      CustomerIncident(
        id: json['id'] as String,
        incidentCode: json['incidentCode'] as String,
        description: json['description'] as String,
        status: IncidentStatus.fromCode(json['status'] as String),
        reportedAt: DateTime.parse(json['reportedAt'] as String).toLocal(),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String).toLocal(),
        resolution: json['resolution'] as String?,
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        reportedByName: json['reportedByName'] as String?,
        itemCount: (json['itemCount'] as num).toInt(),
      );
}

class CustomerIncidentItem {
  const CustomerIncidentItem({
    required this.equipmentId,
    required this.serialNumber,
    required this.modelName,
    this.description,
    this.assessment,
  });

  final String equipmentId, serialNumber, modelName;
  final String? description, assessment;

  factory CustomerIncidentItem.fromJson(Map<String, dynamic> json) =>
      CustomerIncidentItem(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String,
        modelName: json['modelName'] as String,
        description: json['description'] as String?,
        assessment: json['assessment'] as String?,
      );
}

class CustomerIncidentDetail {
  const CustomerIncidentDetail({
    required this.incident,
    required this.items,
    required this.attachments,
  });

  final CustomerIncident incident;
  final List<CustomerIncidentItem> items;

  /// Ảnh đính kèm: storageFileId → URL có chữ ký.
  final List<({String storageFileId, String url})> attachments;

  factory CustomerIncidentDetail.fromJson(Map<String, dynamic> json) =>
      CustomerIncidentDetail(
        incident: CustomerIncident.fromJson(
          json['incident'] as Map<String, dynamic>,
        ),
        items: [
          for (final e in json['items'] as List<dynamic>)
            CustomerIncidentItem.fromJson(e as Map<String, dynamic>),
        ],
        attachments: [
          for (final e in json['attachments'] as List<dynamic>)
            (
              storageFileId:
                  (e as Map<String, dynamic>)['storageFileId'] as String,
              url: e['url'] as String,
            ),
        ],
      );
}

/// Nội dung báo sự cố.
class IncidentInput {
  const IncidentInput({
    required this.description,
    required this.contactName,
    required this.contactPhone,
    required this.equipmentIds,
    this.attachmentFileIds = const [],
  });

  final String description, contactName, contactPhone;
  final List<String> equipmentIds;
  final List<String> attachmentFileIds;

  Map<String, dynamic> toJson() => {
    'description': description,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'items': [
      for (final id in equipmentIds) {'equipmentId': id},
    ],
    'attachmentFileIds': attachmentFileIds,
  };
}
