import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/sales_dashboard_summary.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'sales_tab.dart';

/// Trang "Tổng quan" của nhân viên kinh doanh.
class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.summary,
    required this.onOpenDrawer,
    required this.onNavigate,
  });

  final User user;
  final String roleLabel;
  final SalesDashboardSummary summary;
  final VoidCallback onOpenDrawer;
  final ValueChanged<SalesTab> onNavigate;

  // Phần thẻ tổng quan đè lên header xanh.
  static const double _overlap = 36;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            DashboardHeader(
              user: user,
              roleLabel: roleLabel,
              bottomPadding: _overlap + AppSpacing.lg,
              onOpenDrawer: onOpenDrawer,
              onAvatarTap: () => onNavigate(SalesTab.account),
            ),
            Transform.translate(
              offset: const Offset(0, -_overlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    _OverviewCard(summary: summary, onNavigate: onNavigate),
                    const SizedBox(height: AppSpacing.lg),
                    _PendingTasksCard(summary: summary, onNavigate: onNavigate),
                    const SizedBox(height: AppSpacing.lg),
                    _RecentActivitiesCard(activities: summary.recentActivities),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary, required this.onNavigate});

  final SalesDashboardSummary summary;
  final ValueChanged<SalesTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan kinh doanh',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.weekdayDate(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.45,
            children: [
              _MetricCard(
                icon: Icons.receipt_long_outlined,
                value: summary.totalReservations,
                label: 'Tổng đơn thuê',
                onTap: () => onNavigate(SalesTab.reservations),
              ),
              _MetricCard(
                icon: Icons.schedule_rounded,
                value: summary.processingReservations,
                label: 'Đặt thuê đang xử lý',
                onTap: () => onNavigate(SalesTab.reservations),
              ),
              _MetricCard(
                icon: Icons.handshake_outlined,
                value: summary.activeContracts,
                label: 'Hợp đồng hiệu lực',
                onTap: () => onNavigate(SalesTab.contracts),
              ),
              _MetricCard(
                icon: Icons.business_outlined,
                value: summary.companies,
                label: 'Công ty',
                onTap: () => onNavigate(SalesTab.customers),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingTasksCard extends StatelessWidget {
  const _PendingTasksCard({required this.summary, required this.onNavigate});

  final SalesDashboardSummary summary;
  final ValueChanged<SalesTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (summary.pendingTaskCount == 0) {
      return _SectionCard(
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Không có việc cần xử lý.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Cần xử lý',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (summary.rejectedContracts > 0)
            _TaskRow(
              label: 'Hợp đồng bị từ chối',
              count: summary.rejectedContracts,
              badgeColor: AppColors.error,
              onTap: () => onNavigate(SalesTab.contracts),
            ),
          if (summary.reservationsToComplete > 0)
            _TaskRow(
              label: 'Đặt thuê cần hoàn thiện',
              count: summary.reservationsToComplete,
              badgeColor: AppColors.info,
              onTap: () => onNavigate(SalesTab.reservations),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.label,
    required this.count,
    required this.badgeColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitiesCard extends StatelessWidget {
  const _RecentActivitiesCard({required this.activities});

  final List<SalesRecentActivity> activities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoạt động gần đây',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Chưa có hoạt động nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final activity in activities) _ActivityRow(activity: activity),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final SalesRecentActivity activity;

  IconData get _icon => switch (activity.type) {
    SalesActivityType.reservation => Icons.event_note_outlined,
    SalesActivityType.contract => Icons.description_outlined,
    SalesActivityType.company => Icons.business_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            DateFormatter.relative(activity.occurredAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
