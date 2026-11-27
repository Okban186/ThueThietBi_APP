import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'manager_tab.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({
    super.key,
    required this.user,
    required this.summary,
    required this.onRefresh,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onOpenApprovals,
    required this.onOpenCreateTrip,
    required this.onOpenSupplementary,
    this.onOpenCreateRetrieval,
  });

  final User user;
  final Map<String, dynamic> summary;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDrawer;
  final ValueChanged<ManagerTab> onNavigate;
  final VoidCallback onOpenApprovals;
  final VoidCallback onOpenCreateTrip;
  final VoidCallback onOpenSupplementary;
  final VoidCallback? onOpenCreateRetrieval;

  static const double _overlap = 36;

  int _val(String key) => (summary[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final pendingApproval = _val('pendingApprovalContracts');
    final pendingSigned = _val('pendingSignedContracts');
    final pendingDeposit = _val('pendingDepositContracts');
    final readyToSchedule = _val('readyToScheduleContracts');
    final pendingCancel = _val('pendingCancelContracts');
    final openIncidents = _val('openIncidentsCount');
    final pendingReplacements = _val('pendingReplacementsCount');
    final pendingHandovers = _val('pendingHandoversCount');
    final pendingDisposals = _val('pendingDisposalsCount');
    final todaySchedules = _val('todaySchedulesCount');
    final pendingSupp = _val('pendingSupplementaryCount');
    final waitingDefReturn = _val('waitingDefectiveReturnCount');
    final failedDeliveries = _val('failedDeliveriesCount');
    final processingReturns = _val('processingReturnsCount');
    final pendingCashPayments = _val('pendingCashPaymentsCount');
    final pendingIncidentCharges = _val('pendingIncidentChargesCount');
    final pendingRetrievalContracts = _val('pendingRetrievalContractsCount');

    final totalStaffApprovals =
        pendingCashPayments +
        pendingIncidentCharges +
        pendingReplacements +
        pendingHandovers +
        pendingDisposals +
        pendingCancel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            children: [
              DashboardHeader(
                user: user,
                roleLabel: user.staff?.position ?? 'Quản lý vận hành',
                bottomPadding: _overlap + AppSpacing.lg,
                onOpenDrawer: onOpenDrawer,
                onAvatarTap: () => onNavigate(ManagerTab.account),
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tổng quan điều phối',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormatter.weekdayDate(
                                          DateTime.now(),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: onOpenCreateTrip,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.route_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Lập tuyến',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                  icon: Icons.pending_actions_rounded,
                                  value: pendingApproval + pendingSigned,
                                  label: 'HĐ cần duyệt / ký',
                                  onTap: () => onNavigate(ManagerTab.contracts),
                                ),
                                _MetricCard(
                                  icon: Icons.local_shipping_outlined,
                                  value: readyToSchedule + failedDeliveries,
                                  label: 'Chờ xếp lịch giao',
                                  onTap: onOpenCreateTrip,
                                ),
                                _MetricCard(
                                  icon: Icons.replay_circle_filled_outlined,
                                  value: pendingSupp + waitingDefReturn,
                                  label: 'Giao bù / Chờ thu hồi',
                                  accentColor: (pendingSupp + waitingDefReturn) > 0
                                      ? AppColors.warning
                                      : null,
                                  onTap: onOpenSupplementary,
                                ),
                                _MetricCard(
                                  icon: Icons.receipt_long_rounded,
                                  value: pendingCashPayments,
                                  label: 'Hóa đơn cọc / tiền mặt',
                                  accentColor: pendingCashPayments > 0
                                      ? AppColors.error
                                      : null,
                                  onTap: onOpenApprovals,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionCard(
                        borderColor: AppColors.primary.withValues(alpha: 0.35),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Giao bù & Xếp lịch lại',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: onOpenSupplementary,
                                  icon: const Icon(
                                    Icons.add_road_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Tạo lịch giao bù'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _ActionRow(
                              label: 'Đã thu hồi xong — Sẵn sàng tạo lịch giao bù',
                              count: pendingSupp,
                              badgeColor: AppColors.success,
                              onTap: onOpenSupplementary,
                            ),
                            _ActionRow(
                              label: 'Đang chờ Kho thu hồi máy lỗi trước khi giao bù',
                              count: waitingDefReturn,
                              badgeColor: AppColors.warning,
                              onTap: onOpenSupplementary,
                            ),
                            _ActionRow(
                              label: 'Đơn giao không thành công — Cần xếp lịch mới',
                              count: failedDeliveries,
                              badgeColor: AppColors.error,
                              onTap: onOpenCreateTrip,
                            ),
                            _ActionRow(
                              label: 'Hợp đồng sắp/đã hết hạn cần tạo chuyến thu hồi',
                              count: pendingRetrievalContracts,
                              badgeColor: AppColors.error,
                              onTap: onOpenCreateRetrieval ?? () => onNavigate(ManagerTab.contracts),
                            ),
                            _ActionRow(
                              label: 'Phiếu thu hồi đang chờ Kho kiểm nhận',
                              count: processingReturns,
                              badgeColor: AppColors.info,
                              onTap: onOpenSupplementary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionCard(
                        borderColor: AppColors.warning.withValues(alpha: 0.35),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Duyệt yêu cầu & Vận hành',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: onOpenApprovals,
                                  child: Text('Duyệt ($totalStaffApprovals) >'),
                                ),
                              ],
                            ),
                            _ActionRow(
                              label: 'Hóa đơn thu cọc / tiền mặt chờ duyệt',
                              count: pendingCashPayments,
                              badgeColor: AppColors.error,
                              onTap: onOpenApprovals,
                            ),
                            _ActionRow(
                              label: 'Đề xuất phạt / bồi thường sự cố chờ duyệt',
                              count: pendingIncidentCharges,
                              badgeColor: AppColors.error,
                              onTap: onOpenApprovals,
                            ),
                            _ActionRow(
                              label: 'Bản PDF đã ký chờ duyệt (mở đặt cọc)',
                              count: pendingSigned,
                              badgeColor: AppColors.primary,
                              onTap: () => onNavigate(ManagerTab.contracts),
                            ),
                            _ActionRow(
                              label: 'Hợp đồng đang chờ khách đặt cọc',
                              count: pendingDeposit,
                              badgeColor: AppColors.warning,
                              onTap: () => onNavigate(ManagerTab.contracts),
                            ),
                            _ActionRow(
                              label: 'Hợp đồng mới chờ duyệt',
                              count: pendingApproval,
                              badgeColor: AppColors.warning,
                              onTap: () => onNavigate(ManagerTab.contracts),
                            ),
                            _ActionRow(
                              label: 'Phiếu bàn giao chờ duyệt xuất kho',
                              count: pendingHandovers,
                              badgeColor: AppColors.primary,
                              onTap: onOpenApprovals,
                            ),
                            _ActionRow(
                              label: 'Đề xuất đổi model chờ duyệt',
                              count: pendingReplacements,
                              badgeColor: AppColors.warning,
                              onTap: onOpenApprovals,
                            ),
                            _ActionRow(
                              label: 'Yêu cầu hủy HĐ / Thanh lý',
                              count: pendingCancel + pendingDisposals,
                              badgeColor: AppColors.error,
                              onTap: onOpenApprovals,
                            ),
                            _ActionRow(
                              label: 'Sự cố khách hàng đang mở',
                              count: openIncidents,
                              badgeColor: AppColors.error,
                              onTap: () => onNavigate(ManagerTab.incidents),
                            ),
                            _ActionRow(
                              label: 'Lịch trình chuyến đi hôm nay',
                              count: todaySchedules,
                              badgeColor: AppColors.primary,
                              onTap: () => onNavigate(ManagerTab.schedule),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final c = accentColor ?? AppColors.primary;
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor != null
                  ? accentColor!.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0
                    ? badgeColor.withValues(alpha: 0.14)
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: count > 0 ? badgeColor : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
