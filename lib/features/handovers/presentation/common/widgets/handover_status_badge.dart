import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/handover_preparation.dart';

/// Nhãn trạng thái phiếu bàn giao (dùng chung cho Thủ kho, Quản lý, Kỹ thuật viên).
class HandoverStatusBadge extends StatelessWidget {
  const HandoverStatusBadge({super.key, required this.status});

  final HandoverStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      HandoverStatus.draft ||
      HandoverStatus.preparing => (AppColors.info, AppColors.infoLight),
      HandoverStatus.pendingApproval ||
      HandoverStatus.shipping => (AppColors.warning, AppColors.warningLight),
      HandoverStatus.completed => (AppColors.success, AppColors.successLight),
      HandoverStatus.cancelled => (AppColors.error, AppColors.errorLight),
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
