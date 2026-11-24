class EquipmentModel {
  const EquipmentModel({
    required this.id,
    required this.code,
    required this.name,
    this.manufacturer,
    this.modelNumber,
    this.description,
    this.estimatedInstallationMinutes = 0,
    this.specifications,
    this.unit = 'UNIT',
    this.rentalPriceDaily = 0,
    this.rentalPriceMonthly = 0,
    this.status,
    this.media = const [],
    this.operationalUnits,
    this.availableToday,
    this.totalUnits,
    this.categoryNames = const [],
  });
  final String id, code, name;
  final String? manufacturer, modelNumber, description, status, unit;
  final int estimatedInstallationMinutes;
  final Map<String, dynamic>? specifications;
  final double rentalPriceDaily, rentalPriceMonthly;
  final List<EquipmentModelMedia> media;

  /// Số máy hoạt động (AVAILABLE, RESERVED, RENTED) — từ `/api/equipment-models`.
  final int? operationalUnits;

  /// Số máy khả dụng trong ngày hôm nay — từ `/api/equipment-models`.
  final int? availableToday;

  /// Tổng số máy của model (mọi trạng thái).
  final int? totalUnits;

  /// Tên các danh mục của model.
  final List<String> categoryNames;

  /// Ảnh (bỏ video), ảnh đại diện đứng đầu.
  List<EquipmentModelMedia> get images =>
      media.where((m) => m.mediaType != 'VIDEO' && m.url != null).toList();

  EquipmentModelMedia? get primaryImage => images.isEmpty ? null : images.first;

  factory EquipmentModel.fromJson(Map<String, dynamic> json) => EquipmentModel(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    manufacturer: json['manufacturer'] as String?,
    modelNumber: json['modelNumber'] as String?,
    description: json['description'] as String?,
    estimatedInstallationMinutes:
        (json['estimatedInstallationMinutes'] as num?)?.toInt() ?? 0,
    specifications: json['specifications'] as Map<String, dynamic>?,
    unit: json['unit'] as String? ?? 'UNIT',
    rentalPriceDaily: (json['rentalPriceDaily'] as num?)?.toDouble() ?? 0,
    rentalPriceMonthly: (json['rentalPriceMonthly'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String?,
    operationalUnits: (json['operationalUnits'] as num?)?.toInt(),
    availableToday: (json['availableToday'] as num?)?.toInt(),
    totalUnits: (json['totalUnits'] as num?)?.toInt(),
    categoryNames: [
      for (final c in json['categories'] as List<dynamic>? ?? const [])
        (c as Map<String, dynamic>)['name'] as String,
    ],
    media: (json['media'] as List<dynamic>? ?? const [])
        .map((e) => EquipmentModelMedia.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class EquipmentModelMedia {
  const EquipmentModelMedia({
    required this.id,
    required this.storageFileId,
    this.url,
    this.mediaType,
    this.displayOrder,
    this.isPrimary,
  });
  final String id, storageFileId;
  final String? url, mediaType;
  final int? displayOrder;
  final bool? isPrimary;
  factory EquipmentModelMedia.fromJson(Map<String, dynamic> json) =>
      EquipmentModelMedia(
        id: json['id'] as String,
        storageFileId: json['storageFileId'] as String,
        url: json['url'] as String?,
        mediaType: json['mediaType'] as String?,
        displayOrder: (json['displayOrder'] as num?)?.toInt(),
        isPrimary: json['isPrimary'] as bool?,
      );
}
