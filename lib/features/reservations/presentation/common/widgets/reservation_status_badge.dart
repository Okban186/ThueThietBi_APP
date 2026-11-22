import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/reservation.dart';

/// Nhãn trạng thái phiếu giữ chỗ (dùng chung cho Sales và Manager).
class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({super.key, required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      ReservationStatus.pending => (AppColors.warning, AppColors.warningLight),
      ReservationStatus.approved => (AppColors.success, AppColors.successLight),
      ReservationStatus.converted => (AppColors.info, AppColors.infoLight),
      ReservationStatus.cancelled ||
      ReservationStatus.rejected => (AppColors.error, AppColors.errorLight),
      ReservationStatus.expired => (
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
      ),
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
