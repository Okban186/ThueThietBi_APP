import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/rental_contract.dart';

/// Nhãn trạng thái hợp đồng (dùng chung cho Sales, Manager, Khách hàng).
class ContractStatusBadge extends StatelessWidget {
  const ContractStatusBadge({super.key, required this.status});

  final RentalContractStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      RentalContractStatus.draft => (
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
      ),
      RentalContractStatus.pendingApproval ||
      RentalContractStatus.pendingSignature ||
      RentalContractStatus.cancellationRequested => (
        AppColors.warning,
        AppColors.warningLight,
      ),
      RentalContractStatus.rejected ||
      RentalContractStatus.cancelled ||
      RentalContractStatus.expired => (AppColors.error, AppColors.errorLight),
      RentalContractStatus.signed || RentalContractStatus.completed => (
        AppColors.success,
        AppColors.successLight,
      ),
      RentalContractStatus.preparing ||
      RentalContractStatus.partiallyDelivered ||
      RentalContractStatus.delivered => (AppColors.info, AppColors.infoLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
