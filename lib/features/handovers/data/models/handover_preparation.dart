import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';

/// Trạng thái phiếu bàn giao.
enum HandoverStatus {
  draft('DRAFT', 'Nháp'),
  preparing('PREPARING', 'Đang soạn'),
  pendingApproval('PENDING_APPROVAL', 'Chờ duyệt xuất kho'),
  shipping('SHIPPING', 'Đang giao'),
  completed('COMPLETED', 'Đã giao'),
  cancelled('CANCELLED', 'Đã hủy');

  const HandoverStatus(this.code, this.label);

  final String code;
  final String label;

  static HandoverStatus fromCode(String code) => values.firstWhere(
    (s) => s.code == code.toUpperCase(),
    orElse: () => draft,
  );
}

/// Hợp đồng cần kho soạn bàn giao (`GET /api/handovers/contracts`).
class PreparationContract {
  const PreparationContract({
    required this.contractId,
    required this.contractCode,
    required this.companyCode,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.contractStatus,
    required this.totalQuantity,
    required this.allocatedQuantity,
    required this.activeNoteCount,
    this.deliveryAddress,
  });

  final String contractId, contractCode, companyCode, companyName;
  final DateTime startDate, endDate;
  final RentalContractStatus contractStatus;
  final String? deliveryAddress;
  final int totalQuantity, allocatedQuantity, activeNoteCount;

  int get remainingQuantity => totalQuantity - allocatedQuantity;

  factory PreparationContract.fromJson(Map<String, dynamic> json) =>
      PreparationContract(
        contractId: json['contractId'] as String,
        contractCode: json['contractCode'] as String,
        companyCode: json['companyCode'] as String,
        companyName: json['companyName'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        contractStatus: RentalContractStatus.fromCode(
          json['contractStatus'] as String,
        ),
        deliveryAddress: json['deliveryAddress'] as String?,
        totalQuantity: (json['totalQuantity'] as num).toInt(),
        allocatedQuantity: (json['allocatedQuantity'] as num).toInt(),
        activeNoteCount: (json['activeNoteCount'] as num).toInt(),
      );
}

/// Một model trong hợp đồng: cần bao nhiêu, đã xếp bao nhiêu, kho còn bao nhiêu.
class PreparationItem {
  const PreparationItem({
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.unit,
    required this.quantity,
    required this.allocatedQuantity,
    required this.availableInStock,
  });

  final String equipmentModelId, modelCode, modelName, unit;
  final int quantity, allocatedQuantity, availableInStock;

  int get remainingQuantity => quantity - allocatedQuantity;

  factory PreparationItem.fromJson(Map<String, dynamic> json) =>
      PreparationItem(
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String,
        modelName: json['modelName'] as String,
        unit: json['unit'] as String,
        quantity: (json['quantity'] as num).toInt(),
        allocatedQuantity: (json['allocatedQuantity'] as num).toInt(),
        availableInStock: (json['availableInStock'] as num).toInt(),
      );
}

/// Chi tiết chuẩn bị của một hợp đồng (`GET /api/handovers/contracts/{id}`).
class PreparationContractDetail {
  const PreparationContractDetail({
    required this.contract,
    required this.items,
    required this.notes,
    this.deliveryNote,
    this.representativeName,
    this.representativePhone,
  });

  final PreparationContract contract;
  final String? deliveryNote, representativeName, representativePhone;
  final List<PreparationItem> items;
  final List<HandoverSummary> notes;

  factory PreparationContractDetail.fromJson(Map<String, dynamic> json) =>
      PreparationContractDetail(
        contract: PreparationContract.fromJson(
          json['contract'] as Map<String, dynamic>,
        ),
        deliveryNote: json['deliveryNote'] as String?,
        representativeName: json['representativeName'] as String?,
        representativePhone: json['representativePhone'] as String?,
        items: [
          for (final e in json['items'] as List<dynamic>)
            PreparationItem.fromJson(e as Map<String, dynamic>),
        ],
        notes: [
          for (final e in json['notes'] as List<dynamic>)
            HandoverSummary.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Máy sẵn sàng trong kho để chọn vào phiếu.
class StockEquipment {
  const StockEquipment({
    required this.id,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.warehouseName,
    required this.condition,
  });

  final String id, serialNumber, equipmentModelId, warehouseName, condition;

  factory StockEquipment.fromJson(Map<String, dynamic> json) => StockEquipment(
    id: json['id'] as String,
    serialNumber: json['serialNumber'] as String,
    equipmentModelId: json['equipmentModelId'] as String,
    warehouseName: json['warehouseName'] as String,
    condition: json['condition'] as String,
  );
}

/// Phiếu bàn giao (danh sách).
class HandoverSummary {
  const HandoverSummary({
    required this.id,
    required this.handoverCode,
    required this.rentalContractId,
    required this.contractCode,
    required this.companyName,
    required this.handoverDate,
    required this.receivedByName,
    required this.status,
    required this.itemCount,
    this.receivedByPhone,
    this.note,
    this.createdByName,
  });

  final String id, handoverCode, rentalContractId, contractCode, companyName;
  final DateTime handoverDate;
  final String receivedByName;
  final String? receivedByPhone, note, createdByName;
  final HandoverStatus status;
  final int itemCount;

  bool get isEditable => status == HandoverStatus.preparing;

  bool get isCancellable =>
      status == HandoverStatus.preparing ||
      status == HandoverStatus.pendingApproval;

  factory HandoverSummary.fromJson(Map<String, dynamic> json) =>
      HandoverSummary(
        id: json['id'] as String,
        handoverCode: json['handoverCode'] as String,
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String,
        companyName: json['companyName'] as String,
        handoverDate: DateTime.parse(json['handoverDate'] as String),
        receivedByName: json['receivedByName'] as String,
        receivedByPhone: json['receivedByPhone'] as String?,
        note: json['note'] as String?,
        status: HandoverStatus.fromCode(json['status'] as String),
        itemCount: (json['itemCount'] as num).toInt(),
        createdByName: json['createdByName'] as String?,
      );
}

/// Một máy trong phiếu bàn giao.
class HandoverLine {
  const HandoverLine({
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.warehouseName,
    required this.condition,
    required this.equipmentStatus,
    this.note,
  });

  final String equipmentId, serialNumber, equipmentModelId;
  final String modelCode, modelName, warehouseName, condition, equipmentStatus;
  final String? note;

  factory HandoverLine.fromJson(Map<String, dynamic> json) => HandoverLine(
    equipmentId: json['equipmentId'] as String,
    serialNumber: json['serialNumber'] as String,
    equipmentModelId: json['equipmentModelId'] as String,
    modelCode: json['modelCode'] as String,
    modelName: json['modelName'] as String,
    warehouseName: json['warehouseName'] as String,
    condition: json['condition'] as String,
    equipmentStatus: json['equipmentStatus'] as String,
    note: json['note'] as String?,
  );
}

/// Chi tiết phiếu bàn giao (`GET /api/handovers/{id}`).
class HandoverDetail {
  const HandoverDetail({
    required this.handover,
    required this.items,
    this.deliveryAddress,
    this.deliveryNote,
  });

  final HandoverSummary handover;
  final String? deliveryAddress, deliveryNote;
  final List<HandoverLine> items;

  factory HandoverDetail.fromJson(Map<String, dynamic> json) => HandoverDetail(
    handover: HandoverSummary.fromJson(
      json['handover'] as Map<String, dynamic>,
    ),
    deliveryAddress: json['deliveryAddress'] as String?,
    deliveryNote: json['deliveryNote'] as String?,
    items: [
      for (final e in json['items'] as List<dynamic>)
        HandoverLine.fromJson(e as Map<String, dynamic>),
    ],
  );
}

/// Nội dung tạo/sửa phiếu bàn giao.
class HandoverInput {
  const HandoverInput({
    required this.handoverDate,
    required this.receivedByName,
    required this.equipmentIds,
    this.receivedByPhone,
    this.note,
  });

  final DateTime handoverDate;
  final String receivedByName;
  final String? receivedByPhone, note;
  final List<String> equipmentIds;

  Map<String, dynamic> toJson() => {
    'handoverDate':
        '${handoverDate.year.toString().padLeft(4, '0')}-${handoverDate.month.toString().padLeft(2, '0')}-${handoverDate.day.toString().padLeft(2, '0')}',
    'receivedByName': receivedByName,
    'receivedByPhone': receivedByPhone,
    'note': note,
    'items': [
      for (final id in equipmentIds) {'equipmentId': id},
    ],
  };
}
