import 'contract_document.dart';
import 'contract_representative.dart';
import 'contract_status_history.dart';
import 'rental_contract_item.dart';
import 'rental_contract_service_model.dart';

/// Trạng thái hợp đồng thuê.
enum RentalContractStatus {
  draft('DRAFT', 'Bản nháp'),
  pendingApproval('PENDING_APPROVAL', 'Chờ duyệt'),
  rejected('REJECTED', 'Bị từ chối'),
  pendingSignature('PENDING_SIGNATURE', 'Chờ ký'),
  signed('SIGNED', 'Đã ký'),
  preparing('PREPARING', 'Đang chuẩn bị'),
  partiallyDelivered('PARTIALLY_DELIVERED', 'Giao một phần'),
  delivered('DELIVERED', 'Đã giao'),
  completed('COMPLETED', 'Hoàn tất'),
  expired('EXPIRED', 'Hết hạn'),
  cancellationRequested('CANCELLATION_REQUESTED', 'Chờ hủy'),
  cancelled('CANCELLED', 'Đã hủy');

  const RentalContractStatus(this.code, this.label);

  final String code;
  final String label;

  /// Trạng thái hiển thị trong bộ lọc danh sách (theo mockup).
  static const filterable = [
    draft,
    pendingApproval,
    rejected,
    pendingSignature,
    signed,
    cancelled,
  ];

  static RentalContractStatus fromCode(String code) => values.firstWhere(
    (s) => s.code == code.toUpperCase(),
    orElse: () => RentalContractStatus.draft,
  );
}

/// Loại thuê.
enum RentalType {
  shortTerm('SHORT_TERM', 'Ngắn hạn'),
  longTerm('LONG_TERM', 'Dài hạn');

  const RentalType(this.code, this.label);

  final String code;
  final String label;

  static RentalType fromCode(String code) =>
      code.toUpperCase() == 'LONG_TERM' ? longTerm : shortTerm;
}

/// Hợp đồng thuê (`/api/rental-contracts`).
class RentalContract {
  const RentalContract({
    required this.id,
    required this.contractCode,
    required this.companyId,
    required this.startDate,
    required this.endDate,
    required this.rentalType,
    required this.status,
    required this.createdBy,
    this.reservationId,
    this.reservationCode,
    this.companyCode,
    this.companyName,
    this.contractTotalAmount = 0,
    this.depositRequiredAmount = 0,
    this.itemCount = 0,
    this.totalQuantity = 0,
    this.createdByName,
    this.canEdit = false,
    this.rejectionReason,
    this.createdAt,
    this.detail,
  });

  final String id, contractCode, companyId, createdBy;
  final String? reservationId, reservationCode, companyCode, companyName;
  final DateTime startDate, endDate;
  final RentalType rentalType;
  final RentalContractStatus status;
  final double contractTotalAmount, depositRequiredAmount;
  final int itemCount, totalQuantity;
  final String? createdByName;

  /// Người đang đăng nhập là người tạo hợp đồng.
  final bool canEdit;

  /// Lý do Manager từ chối (khi Bị từ chối).
  final String? rejectionReason;
  final DateTime? createdAt;

  /// Chỉ có khi tải chi tiết.
  final RentalContractDetail? detail;

  int get rentalDays => endDate.difference(startDate).inDays + 1;

  bool get isEditable =>
      status == RentalContractStatus.draft ||
      status == RentalContractStatus.rejected;

  bool get isCancellable =>
      isEditable ||
      status == RentalContractStatus.pendingApproval ||
      status == RentalContractStatus.pendingSignature;

  factory RentalContract.fromJson(
    Map<String, dynamic> json, {
    RentalContractDetail? detail,
  }) => RentalContract(
    id: json['id'] as String,
    contractCode: json['contractCode'] as String,
    reservationId: json['reservationId'] as String?,
    reservationCode: json['reservationCode'] as String?,
    companyId: json['companyId'] as String,
    companyCode: json['companyCode'] as String?,
    companyName: json['companyName'] as String?,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    rentalType: RentalType.fromCode(json['rentalType'] as String),
    status: RentalContractStatus.fromCode(json['status'] as String),
    contractTotalAmount: _num(json['contractTotalAmount']),
    depositRequiredAmount: _num(json['depositRequiredAmount']),
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
    createdBy: json['createdById'] as String,
    createdByName: json['createdByName'] as String?,
    canEdit: json['canEdit'] as bool? ?? false,
    rejectionReason: json['rejectionReason'] as String?,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String).toLocal(),
    detail: detail,
  );

  /// Chi tiết: `{ "contract": {...}, "items": [...], ... }`.
  factory RentalContract.fromDetailJson(Map<String, dynamic> json) =>
      RentalContract.fromJson(
        json['contract'] as Map<String, dynamic>,
        detail: RentalContractDetail.fromJson(json),
      );

  static double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;
}

/// Phần chi tiết của hợp đồng.
class RentalContractDetail {
  const RentalContractDetail({
    required this.items,
    required this.services,
    required this.documents,
    required this.statusHistory,
    this.deliveryAddress,
    this.deliveryNote,
    this.note,
    this.representative,
    this.approvedByName,
    this.approvedAt,
    this.signedAt,
    this.signedContractUrl,
  });

  final String? deliveryAddress, deliveryNote, note;
  final List<RentalContractItem> items;
  final List<RentalContractServiceModel> services;
  final ContractRepresentative? representative;
  final List<ContractDocument> documents;
  final List<ContractStatusHistory> statusHistory;
  final String? approvedByName;
  final DateTime? approvedAt, signedAt;

  /// URL có thời hạn của bản hợp đồng đã ký.
  final String? signedContractUrl;

  ContractDocument? documentOf(ContractDocumentKind kind) {
    for (final document in documents) {
      if (document.kind == kind) return document;
    }
    return null;
  }

  factory RentalContractDetail.fromJson(
    Map<String, dynamic> json,
  ) => RentalContractDetail(
    deliveryAddress: json['deliveryAddress'] as String?,
    deliveryNote: json['deliveryNote'] as String?,
    note: json['note'] as String?,
    items: (json['items'] as List<dynamic>)
        .map((e) => RentalContractItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    services: (json['services'] as List<dynamic>)
        .map(
          (e) => RentalContractServiceModel.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    representative: json['representative'] == null
        ? null
        : ContractRepresentative.fromJson(
            json['representative'] as Map<String, dynamic>,
          ),
    documents: (json['documents'] as List<dynamic>)
        .map((e) => ContractDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    statusHistory: (json['statusHistory'] as List<dynamic>)
        .map((e) => ContractStatusHistory.fromJson(e as Map<String, dynamic>))
        .toList(),
    approvedByName: json['approvedByName'] as String?,
    approvedAt: _date(json['approvedAt']),
    signedAt: _date(json['signedAt']),
    signedContractUrl: json['signedContractUrl'] as String?,
  );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();
}
