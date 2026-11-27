import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/features/technician/data/models/technician_models.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'technician_tab.dart';

class TechnicianDashboardScreen extends StatelessWidget {
  const TechnicianDashboardScreen({
    super.key,
    required this.user,
    required this.summary,
    required this.onRefresh,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onOpenTrip,
    this.errorMessage,
  });

  final User user;
  final TechnicianDashboard summary;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDrawer;
  final ValueChanged<TechnicianTab> onNavigate;
  final ValueChanged<String> onOpenTrip;
  final String? errorMessage;

  static const double _overlap = 34;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              DashboardHeader(
                user: user,
                roleLabel: user.staff?.position ?? 'Kỹ thuật viên',
                bottomPadding: _overlap + AppSpacing.lg,
                onOpenDrawer: onOpenDrawer,
                onAvatarTap: () => onNavigate(TechnicianTab.account),
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: onRefresh,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _sectionCard(
                        title: 'Tổng quan công việc hôm nay',
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.55,
                          children: [
                            _metricTile(
                              label: 'Đang đi giao',
                              count: summary.inProgressTripsCount,
                              icon: Icons.directions_car_filled_outlined,
                              color: AppColors.info,
                              bg: AppColors.infoLight,
                              onTap: () => onNavigate(TechnicianTab.trips),
                            ),
                            _metricTile(
                              label: 'Chuyến chờ xuất phát',
                              count: summary.pendingTripsCount,
                              icon: Icons.schedule_rounded,
                              color: AppColors.warning,
                              bg: AppColors.warningLight,
                              onTap: () => onNavigate(TechnicianTab.trips),
                            ),
                            _metricTile(
                              label: 'Phiếu bảo trì mở',
                              count:
                                  summary.pendingMaintenanceCount +
                                  summary.inProgressMaintenanceCount,
                              icon: Icons.build_circle_outlined,
                              color: AppColors.primary,
                              bg: AppColors.primaryLight,
                              onTap: () =>
                                  onNavigate(TechnicianTab.maintenance),
                            ),
                            _metricTile(
                              label: 'Sự cố đang xử lý',
                              count: summary.openIncidentsCount,
                              icon: Icons.support_agent_rounded,
                              color: AppColors.error,
                              bg: AppColors.errorLight,
                              onTap: () => onNavigate(TechnicianTab.incidents),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title:
                            'Chuyến đang đi & Chờ xuất phát (${summary.activeTrips.length})',
                        trailing: TextButton(
                          onPressed: () => onNavigate(TechnicianTab.trips),
                          child: const Text('Xem tất cả'),
                        ),
                        child: summary.activeTrips.isEmpty
                            ? const Text(
                                'Hiện chưa có chuyến giao nào đang đi hoặc chờ xuất phát.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : Column(
                                children: [
                                  for (final trip in summary.activeTrips)
                                    _activeTripCard(trip),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Truy cập nhanh',
                        child: Column(
                          children: [
                            _quickRow(
                              icon: Icons.local_shipping_outlined,
                              title: 'Lịch trình chuyến giao',
                              subtitle:
                                  'Hoàn tất hôm nay: ${summary.completedTripsTodayCount} chuyến • Chỉ đường từng chặng',
                              onTap: () => onNavigate(TechnicianTab.trips),
                            ),
                            const Divider(height: 18),
                            _quickRow(
                              icon: Icons.build_outlined,
                              title: 'Kiểm tra & bảo trì thiết bị tại kho',
                              subtitle:
                                  '${summary.pendingMaintenanceCount} chờ xử lý • ${summary.inProgressMaintenanceCount} đang sửa chữa',
                              onTap: () =>
                                  onNavigate(TechnicianTab.maintenance),
                            ),
                            const Divider(height: 18),
                            _quickRow(
                              icon: Icons.support_agent_outlined,
                              title: 'Xử lý sự cố khách hàng',
                              subtitle:
                                  '${summary.openIncidentsCount} sự cố Online / hiện trường được phân công',
                              onTap: () => onNavigate(TechnicianTab.incidents),
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

  Widget _activeTripCard(TechnicianAssignmentSummary trip) {
    final isInProgress = trip.status.toUpperCase() == 'IN_PROGRESS';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isInProgress
              ? AppColors.info.withValues(alpha: 0.45)
              : AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpenTrip(trip.assignmentId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? AppColors.infoLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isInProgress
                          ? (trip.isRetrieval ? 'Đang đi thu hồi' : 'Đang đi giao')
                          : 'Chờ xuất phát',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isInProgress
                            ? AppColors.info
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  trip.isRetrieval ? 'Thu hồi' : 'Giao lắp',
                  trip.isLeader ? '⭐ KTV trưởng' : 'Thành viên',
                  '${trip.completedStopCount}/${trip.stopCount} điểm xong',
                  if (trip.scheduledStartAt != null)
                    DateFormatter.dateTime(trip.scheduledStartAt!),
                ].join(' • '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _metricTile({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) => Material(
    color: bg,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _quickRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}
