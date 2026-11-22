import 'rental_contract.dart';

/// Một lần đổi trạng thái hợp đồng.
class ContractStatusHistory {
  const ContractStatusHistory({
    required this.status,
    required this.previousStatus,
    required this.changedAt,
    this.changedByName,
    this.note,
  });

  final RentalContractStatus status, previousStatus;
  final DateTime changedAt;
  final String? changedByName, note;

  factory ContractStatusHistory.fromJson(Map<String, dynamic> json) =>
      ContractStatusHistory(
        status: RentalContractStatus.fromCode(json['status'] as String),
        previousStatus: RentalContractStatus.fromCode(
          json['previousStatus'] as String,
        ),
        changedByName: json['changedByName'] as String?,
        changedAt: DateTime.parse(json['changedAt'] as String).toLocal(),
        note: json['note'] as String?,
      );
}
