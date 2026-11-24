import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';

/// Hợp đồng còn máy ở chỗ khách (`GET /api/equipment-returns/contracts`).
class ReturnContract {
  const ReturnContract({
    required this.contractId,
    required this.contractCode,
    required this.companyCode,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.contractStatus,
    required this.deliveredQuantity,
    required this.outstandingQuantity,
    this.deliveryAddress,
  });

  final String contractId, contractCode, companyCode, companyName;
  final DateTime startDate, endDate;
  final RentalContractStatus contractStatus;
  final String? deliveryAddress;
  final int deliveredQuantity, outstandingQuantity;

  factory ReturnContract.fromJson(Map<String, dynamic> json) => ReturnContract(
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
    deliveredQuantity: (json['deliveredQuantity'] as num).toInt(),
    outstandingQuantity: (json['outstandingQuantity'] as num).toInt(),
  );
}

/// Máy đã giao, đang ở chỗ khách.
class OutstandingEquipment {
  const OutstandingEquipment({
    required this.equipmentId,
    required this.serialNumber,
    required this.equipmentModelId,
    required this.modelCode,
    required this.modelName,
    required this.condition,
    required this.handoverCode,
  });

  final String equipmentId, serialNumber, equipmentModelId;
  final String modelCode, modelName, condition, handoverCode;

  factory OutstandingEquipment.fromJson(Map<String, dynamic> json) =>
      OutstandingEquipment(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String,
        equipmentModelId: json['equipmentModelId'] as String,
        modelCode: json['modelCode'] as String,
        modelName: json['modelName'] as String,
        condition: json['condition'] as String,
        handoverCode: json['handoverCode'] as String,
      );
}

/// Phiếu nhận trả (danh sách).
class ReturnReceipt {
  const ReturnReceipt({
    required this.id,
    required this.returnCode,
    required this.rentalContractId,
    required this.contractCode,
    required this.companyName,
    required this.returnedAt,
    required this.status,
    required this.returnedCount,
    required this.missingCount,
    required this.damagedCount,
    this.receivedByName,
    this.note,
  });

  final String id, returnCode, rentalContractId, contractCode, companyName;
  final DateTime returnedAt;
  final String status;
  final String? receivedByName, note;
  final int returnedCount, missingCount, damagedCount;

  int get totalCount => returnedCount + missingCount;

  factory ReturnReceipt.fromJson(Map<String, dynamic> json) => ReturnReceipt(
    id: json['id'] as String,
    returnCode: json['returnCode'] as String,
    rentalContractId: json['rentalContractId'] as String,
    contractCode: json['contractCode'] as String,
    companyName: json['companyName'] as String,
    returnedAt: DateTime.parse(json['returnedAt'] as String).toLocal(),
    receivedByName: json['receivedByName'] as String?,
    status: json['status'] as String,
    note: json['note'] as String?,
    returnedCount: (json['returnedCount'] as num).toInt(),
    missingCount: (json['missingCount'] as num).toInt(),
    damagedCount: (json['damagedCount'] as num).toInt(),
  );
}

/// Chi tiết chuẩn bị nhận trả của một hợp đồng.
class ReturnContractDetail {
  const ReturnContractDetail({
    required this.contract,
    required this.outstanding,
    required this.returns,
  });

  final ReturnContract contract;
  final List<OutstandingEquipment> outstanding;
  final List<ReturnReceipt> returns;

  factory ReturnContractDetail.fromJson(Map<String, dynamic> json) =>
      ReturnContractDetail(
        contract: ReturnContract.fromJson(
          json['contract'] as Map<String, dynamic>,
        ),
        outstanding: [
          for (final e in json['outstanding'] as List<dynamic>)
            OutstandingEquipment.fromJson(e as Map<String, dynamic>),
        ],
        returns: [
          for (final e in json['returns'] as List<dynamic>)
            ReturnReceipt.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Một máy trong phiếu nhận trả.
class ReturnReceiptLine {
  const ReturnReceiptLine({
    required this.equipmentId,
    required this.serialNumber,
    required this.modelCode,
    required this.modelName,
    required this.status,
    required this.condition,
    required this.equipmentStatus,
    this.note,
  });

  final String equipmentId, serialNumber, modelCode, modelName;

  /// RETURNED, MISSING
  final String status;
  final String condition, equipmentStatus;
  final String? note;

  factory ReturnReceiptLine.fromJson(Map<String, dynamic> json) =>
      ReturnReceiptLine(
        equipmentId: json['equipmentId'] as String,
        serialNumber: json['serialNumber'] as String,
        modelCode: json['modelCode'] as String,
        modelName: json['modelName'] as String,
        status: json['status'] as String,
        condition: json['condition'] as String,
        equipmentStatus: json['equipmentStatus'] as String,
        note: json['note'] as String?,
      );
}

class ReturnReceiptDetail {
  const ReturnReceiptDetail({required this.receipt, required this.items});

  final ReturnReceipt receipt;
  final List<ReturnReceiptLine> items;

  factory ReturnReceiptDetail.fromJson(Map<String, dynamic> json) =>
      ReturnReceiptDetail(
        receipt: ReturnReceipt.fromJson(json['return'] as Map<String, dynamic>),
        items: [
          for (final e in json['items'] as List<dynamic>)
            ReturnReceiptLine.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Kết quả kiểm một máy khi nhận về.
enum ReturnCheck {
  good('Tốt', 'RETURNED', 'GOOD'),
  fair('Khá', 'RETURNED', 'FAIR'),
  damaged('Hỏng', 'RETURNED', 'DAMAGED'),
  missing('Thất lạc', 'MISSING', null);

  const ReturnCheck(this.label, this.status, this.condition);

  final String label;
  final String status;
  final String? condition;
}

/// Một dòng gửi lên khi lập phiếu nhận trả.
class ReturnCheckInput {
  const ReturnCheckInput({
    required this.equipmentId,
    required this.check,
    this.note,
  });

  final String equipmentId;
  final ReturnCheck check;
  final String? note;

  Map<String, dynamic> toJson() => {
    'equipmentId': equipmentId,
    'status': check.status,
    'condition': check.condition,
    'note': note,
  };
}
