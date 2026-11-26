import 'rental_contract_service_model.dart';

/// Báo giá phí vận chuyển tự động trả về từ `POST /api/rental-contracts/shipping-quote`.
class ShippingQuote {
  const ShippingQuote({
    required this.providedBy,
    required this.originAddress,
    this.destinationAddress,
    this.distanceKm,
    this.isEstimated = false,
    required this.freeRadiusKm,
    required this.chargeableKm,
    required this.pricePerKmOneWay,
    required this.trips,
    required this.rawFee,
    required this.discountPercent,
    required this.discountAmount,
    required this.finalFee,
    this.promotionDescription,
    required this.summaryNote,
  });

  final ServiceProvider providedBy;
  final String originAddress;
  final String? destinationAddress;
  final double? distanceKm;
  final bool isEstimated;
  final double freeRadiusKm;
  final double chargeableKm;
  final double pricePerKmOneWay;
  final int trips;
  final double rawFee;
  final double discountPercent;
  final double discountAmount;
  final double finalFee;
  final String? promotionDescription;
  final String summaryNote;

  factory ShippingQuote.fromJson(Map<String, dynamic> json) => ShippingQuote(
    providedBy: ServiceProvider.fromCode(json['providedBy'] as String),
    originAddress: json['originAddress'] as String? ?? '',
    destinationAddress: json['destinationAddress'] as String?,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    isEstimated: json['isEstimated'] as bool? ?? false,
    freeRadiusKm: (json['freeRadiusKm'] as num?)?.toDouble() ?? 0,
    chargeableKm: (json['chargeableKm'] as num?)?.toDouble() ?? 0,
    pricePerKmOneWay: (json['pricePerKmOneWay'] as num?)?.toDouble() ?? 0,
    trips: (json['trips'] as num?)?.toInt() ?? 0,
    rawFee: (json['rawFee'] as num?)?.toDouble() ?? 0,
    discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
    discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    finalFee: (json['finalFee'] as num?)?.toDouble() ?? 0,
    promotionDescription: json['promotionDescription'] as String?,
    summaryNote: json['summaryNote'] as String? ?? '',
  );
}
