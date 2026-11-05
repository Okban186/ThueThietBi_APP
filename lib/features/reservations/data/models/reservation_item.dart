class ReservationItem {
  const ReservationItem({
    required this.id,
    required this.reservationId,
    required this.equipmentModelId,
    required this.quantity,
    this.note,
    this.equipmentModelName,
  });
  final String id, reservationId, equipmentModelId;
  final int quantity;
  final String? note, equipmentModelName;

  factory ReservationItem.fromJson(Map<String, dynamic> json) =>
      ReservationItem(
        id: json['id'] as String,
        reservationId: json['reservationId'] as String,
        equipmentModelId: json['equipmentModelId'] as String,
        quantity: (json['quantity'] as num).toInt(),
        note: json['note'] as String?,
        equipmentModelName: json['equipmentModelName'] as String?,
      );
}
