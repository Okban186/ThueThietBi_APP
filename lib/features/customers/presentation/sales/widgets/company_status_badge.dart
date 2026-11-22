import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/company.dart';

/// Nhãn trạng thái công ty khách hàng.
class CompanyStatusBadge extends StatelessWidget {
  const CompanyStatusBadge({super.key, required this.status});

  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == CompanyStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
