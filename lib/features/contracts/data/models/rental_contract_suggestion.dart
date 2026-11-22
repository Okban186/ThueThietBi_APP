import 'rental_contract.dart';
import 'rental_contract_item.dart';

/// Giá trị đề xuất khi tạo hợp đồng từ phiếu đã xác nhận
/// (`GET /api/rental-contracts/suggestion?reservationId=`).
class RentalContractSuggestion {
  const RentalContractSuggestion({
    required this.reservationId,
    required this.reservationCode,
    required this.companyId,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.rentalDays,
    required this.rentalType,
    required this.depositRate,
    required this.items,
    required this.contractTotalAmount,
    required this.depositRequiredAmount,
  });

  final String reservationId, reservationCode, companyId, companyName;
  final DateTime startDate, endDate;
  final int rentalDays;
  final RentalType rentalType;
  final double depositRate;
  final List<RentalContractItem> items;
  final double contractTotalAmount, depositRequiredAmount;

  factory RentalContractSuggestion.fromJson(Map<String, dynamic> json) =>
      RentalContractSuggestion(
        reservationId: json['reservationId'] as String,
        reservationCode: json['reservationCode'] as String,
        companyId: json['companyId'] as String,
        companyName: json['companyName'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        rentalDays: (json['rentalDays'] as num).toInt(),
        rentalType: RentalType.fromCode(json['rentalType'] as String),
        depositRate: (json['depositRate'] as num).toDouble(),
        items: (json['items'] as List<dynamic>)
            .map((e) => RentalContractItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        contractTotalAmount: (json['contractTotalAmount'] as num).toDouble(),
        depositRequiredAmount: (json['depositRequiredAmount'] as num)
            .toDouble(),
      );
}
