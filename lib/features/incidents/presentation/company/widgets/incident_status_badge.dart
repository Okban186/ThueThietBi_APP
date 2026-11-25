import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/customer_incident.dart';

/// Nhãn trạng thái sự cố.
class IncidentStatusBadge extends StatelessWidget {
  const IncidentStatusBadge({super.key, required this.status});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      IncidentStatus.open => (AppColors.warning, AppColors.warningLight),
      IncidentStatus.remoteSupport ||
      IncidentStatus.dispatching ||
      IncidentStatus.onSite ||
      IncidentStatus.returnRequired => (AppColors.info, AppColors.infoLight),
      IncidentStatus.resolved => (AppColors.success, AppColors.successLight),
      IncidentStatus.cancelled => (
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
