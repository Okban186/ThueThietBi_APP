import 'reservation_item.dart';

/// Trạng thái phiếu giữ chỗ.
enum ReservationStatus {
  pending('PENDING', 'Chờ xử lý'),
  approved('APPROVED', 'Đã xác nhận'),
  converted('CONVERTED', 'Đã tạo hợp đồng'),
  cancelled('CANCELLED', 'Đã hủy'),
  expired('EXPIRED', 'Hết hạn'),
  // Có trong DB nhưng không dùng (Sales tự xác nhận phiếu).
  rejected('REJECTED', 'Bị từ chối');

  const ReservationStatus(this.code, this.label);

  final String code;
  final String label;

  /// Trạng thái hiển thị trong bộ lọc danh sách.
  static const filterable = [pending, approved, converted, cancelled, expired];

  static ReservationStatus fromCode(String code) => values.firstWhere(
    (s) => s.code == code.toUpperCase(),
    orElse: () => ReservationStatus.pending,
  );
}

/// Phiếu giữ chỗ (`/api/reservations`).
class Reservation {
  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.companyId,
    required this.requestedFrom,
    required this.requestedTo,
    required this.status,
    required this.createdBy,
    required this.contactName,
    required this.contactPhone,
    required this.expiresAt,
    this.companyCode,
    this.companyName,
    this.note,
    this.itemCount = 0,
    this.totalQuantity = 0,
    this.createdByName,
    this.canEdit = false,
    this.createdAt,
    this.items = const [],
  });

  final String id, reservationCode, companyId, createdBy;
  final String contactName, contactPhone;
  final String? companyCode, companyName, note, createdByName;
  final ReservationStatus status;
  final DateTime requestedFrom, requestedTo;

  /// Hạn giữ chỗ; quá hạn mà chưa tạo hợp đồng thì chuyển "Hết hạn".
  final DateTime expiresAt;

  final int itemCount, totalQuantity;

  /// Người đang đăng nhập là người lập phiếu.
  final bool canEdit;

  final DateTime? createdAt;

  /// Chỉ có khi tải chi tiết.
  final List<ReservationItem> items;

  bool get isPending => status == ReservationStatus.pending;
  bool get isApproved => status == ReservationStatus.approved;

  /// Còn hiệu lực giữ chỗ (chưa hủy/hết hạn/tạo hợp đồng).
  bool get isOpen => isPending || isApproved;

  factory Reservation.fromJson(
    Map<String, dynamic> json, {
    List<ReservationItem> items = const [],
  }) => Reservation(
    id: json['id'] as String,
    reservationCode: json['reservationCode'] as String,
    companyId: json['companyId'] as String,
    companyCode: json['companyCode'] as String?,
    companyName: json['companyName'] as String?,
    requestedFrom: DateTime.parse(json['requestedFrom'] as String),
    requestedTo: DateTime.parse(json['requestedTo'] as String),
    contactName: json['contactName'] as String? ?? '',
    contactPhone: json['contactPhone'] as String? ?? '',
    expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
    status: ReservationStatus.fromCode(json['status'] as String),
    note: json['note'] as String?,
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
    createdBy: json['createdById'] as String,
    createdByName: json['createdByName'] as String?,
    canEdit: json['canEdit'] as bool? ?? false,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String).toLocal(),
    items: items,
  );

  /// Chi tiết: `{ "reservation": {...}, "items": [...] }`.
  factory Reservation.fromDetailJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((e) => ReservationItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return Reservation.fromJson(
      json['reservation'] as Map<String, dynamic>,
      items: items,
    );
  }
}
