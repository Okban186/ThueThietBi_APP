class IncidentCharge {
  const IncidentCharge({
    required this.id,
    required this.incidentItemId,
    required this.chargeType,
    required this.amount,
    this.description,
    this.status,
    this.rentalChargeId,
  });
  final String id, incidentItemId, chargeType;
  final double amount;
  final String? description, status, rentalChargeId;
  factory IncidentCharge.fromJson(Map<String, dynamic> j) => IncidentCharge(
    id: j['id'] as String,
    incidentItemId: j['incidentItemId'] as String,
    chargeType: j['chargeType'] as String,
    amount: (j['amount'] as num).toDouble(),
    description: j['description'] as String?,
    status: j['status'] as String?,
    rentalChargeId: j['rentalChargeId'] as String?,
  );
}
