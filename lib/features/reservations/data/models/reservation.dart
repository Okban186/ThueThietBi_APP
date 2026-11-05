import 'package:thuethietbi_app/features/reservations/data/models/reservation_item.dart';

class Reservation {
  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.companyId,
    required this.requestedFrom,
    required this.requestedTo,
    required this.status,
    required this.createdBy,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.companyName,
    this.items = const [],
  });
  final String id, reservationCode, companyId, status, createdBy;
  final DateTime requestedFrom, requestedTo;
  final String? note, companyName;
  final DateTime? createdAt, updatedAt;
  final List<ReservationItem> items;

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: json['id'] as String,
    reservationCode: json['reservationCode'] as String,
    companyId: json['companyId'] as String,
    requestedFrom: DateTime.parse(json['requestedFrom'] as String),
    requestedTo: DateTime.parse(json['requestedTo'] as String),
    status: json['status'] as String,
    createdBy: json['createdBy'] as String,
    note: json['note'] as String?,
    companyName: json['companyName'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => ReservationItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
