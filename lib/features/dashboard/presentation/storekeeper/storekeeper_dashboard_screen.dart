import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/storekeeper_dashboard_summary.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'storekeeper_tab.dart';

class StorekeeperDashboardScreen extends StatelessWidget {
  const StorekeeperDashboardScreen({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.isLeadStorekeeper,
    required this.summary,
    required this.onRefresh,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onOpenWarehouses,
  });

  final User user;
  final String roleLabel;
  final bool isLeadStorekeeper;
  final StorekeeperDashboardSummary summary;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDrawer;
  final ValueChanged<StorekeeperTab> onNavigate;
  final VoidCallback onOpenWarehouses;

  static const double _overlap = 36;

  @override
  Widget build(BuildContext context) {
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
                roleLabel: roleLabel,
                bottomPadding: _overlap + AppSpacing.lg,
                onOpenDrawer: onOpenDrawer,
                onAvatarTap: () => onNavigate(StorekeeperTab.account),
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      _OperationsWorkflowCard(
                        summary: summary,
                        onNavigate: onNavigate,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InventoryOverviewCard(
                        summary: summary,
                        onNavigate: onNavigate,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InventoryHealthBar(summary: summary),
                      const SizedBox(height: AppSpacing.lg),
                      _AlertsCard(
                        summary: summary,
                        isLeadStorekeeper: isLeadStorekeeper,
                        onNavigate: onNavigate,
                        onOpenWarehouses: onOpenWarehouses,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RecentEquipmentsCard(
                        summary: summary,
                        onNavigate: onNavigate,
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

class _InventoryOverviewCard extends StatelessWidget {
  const _InventoryOverviewCard({
    required this.summary,
    required this.onNavigate,
  });
  final StorekeeperDashboardSummary summary;
  final ValueChanged<StorekeeperTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng quan kho thiết bị',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Theo dõi model & tồn kho thực tế',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _StatTile(
                icon: Icons.category_rounded,
                color: AppColors.primary,
                value: '${summary.totalModels}',
                label: 'Model thiết bị',
                onTap: () => onNavigate(StorekeeperTab.models),
              ),
              _StatTile(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                value: '${summary.availableEquipments}',
                label: 'Sẵn sàng cho thuê',
                onTap: () => onNavigate(StorekeeperTab.equipments),
              ),
              _StatTile(
                icon: Icons.handshake_rounded,
                color: AppColors.info,
                value: '${summary.rentedEquipments}',
                label: 'Đang cho thuê',
                onTap: () => onNavigate(StorekeeperTab.equipments),
              ),
              _StatTile(
                icon: Icons.build_circle_rounded,
                color: AppColors.warning,
                value: '${summary.maintenanceEquipments}',
                label: 'Đang bảo trì',
                onTap: () => onNavigate(StorekeeperTab.equipments),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String value, label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryHealthBar extends StatelessWidget {
  const _InventoryHealthBar({required this.summary});
  final StorekeeperDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalEquipments == 0 ? 1 : summary.totalEquipments;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Phân bổ trạng thái thiết bị',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${summary.totalEquipments} máy',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (summary.availableEquipments > 0)
                    Expanded(
                      flex: summary.availableEquipments,
                      child: Container(color: AppColors.success),
                    ),
                  if (summary.rentedEquipments + summary.reservedEquipments > 0)
                    Expanded(
                      flex:
                          summary.rentedEquipments + summary.reservedEquipments,
                      child: Container(color: AppColors.info),
                    ),
                  if (summary.maintenanceEquipments > 0)
                    Expanded(
                      flex: summary.maintenanceEquipments,
                      child: Container(color: AppColors.warning),
                    ),
                  if (summary.damagedOrLostEquipments > 0)
                    Expanded(
                      flex: summary.damagedOrLostEquipments,
                      child: Container(color: AppColors.error),
                    ),
                  if (summary.totalEquipments == 0)
                    Expanded(child: Container(color: AppColors.border)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(
                color: AppColors.success,
                text:
                    'Khả dụng (${(summary.availableEquipments * 100 / total).round()}%)',
              ),
              _LegendDot(
                color: AppColors.info,
                text:
                    'Thuê/Giữ (${((summary.rentedEquipments + summary.reservedEquipments) * 100 / total).round()}%)',
              ),
              _LegendDot(
                color: AppColors.warning,
                text: 'Bảo trì (${summary.maintenanceEquipments})',
              ),
              _LegendDot(
                color: AppColors.error,
                text: 'Hỏng/Mất (${summary.damagedOrLostEquipments})',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.summary,
    required this.isLeadStorekeeper,
    required this.onNavigate,
    required this.onOpenWarehouses,
  });

  final StorekeeperDashboardSummary summary;
  final bool isLeadStorekeeper;
  final ValueChanged<StorekeeperTab> onNavigate;
  final VoidCallback onOpenWarehouses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Cần chú ý',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AlertRow(
            label: 'Model hết thiết bị khả dụng',
            count: summary.outOfStockModelsCount,
            color: AppColors.error,
            onTap: () => onNavigate(StorekeeperTab.models),
          ),
          const SizedBox(height: 8),
          _AlertRow(
            label: 'Thiết bị hỏng / thất lạc',
            count: summary.damagedOrLostEquipments,
            color: AppColors.warning,
            onTap: () => onNavigate(StorekeeperTab.equipments),
          ),
          if (isLeadStorekeeper) ...[
            const SizedBox(height: 8),
            _AlertRow(
              label: 'Kho bãi đang vận hành',
              count: summary.activeWarehousesCount,
              color: AppColors.primary,
              onTap: onOpenWarehouses,
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
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

class _RecentEquipmentsCard extends StatelessWidget {
  const _RecentEquipmentsCard({
    required this.summary,
    required this.onNavigate,
  });
  final StorekeeperDashboardSummary summary;
  final ValueChanged<StorekeeperTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thiết bị nhập gần đây',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(StorekeeperTab.equipments),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          if (summary.recentEquipments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có thiết bị nào được nhập kho.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final item in summary.recentEquipments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(
                    Icons.qr_code_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  item.serialNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${item.equipmentModelName} • ${item.warehouseName}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: Text(
                  DateFormatter.date(item.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}


class _OperationsWorkflowCard extends StatelessWidget {
  const _OperationsWorkflowCard({
    required this.summary,
    required this.onNavigate,
  });

  final StorekeeperDashboardSummary summary;
  final ValueChanged<StorekeeperTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
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
              const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Công việc Giao nhận & Thu hồi của tôi',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(StorekeeperTab.handovers),
                child: const Text('Mở giao nhận >'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 1. Phiếu bàn giao
          _WorkflowGroup(
            icon: Icons.outbox_rounded,
            title: 'Phiếu bàn giao',
            pills: [
              _StatusPillData(
                'Chưa ai nhận',
                summary.unclaimedHandoversCount,
                AppColors.warning,
                AppColors.warningLight,
              ),
              _StatusPillData(
                'Của tôi đang soạn',
                summary.myPreparingHandoversCount,
                AppColors.primary,
                AppColors.primaryLight,
              ),
              _StatusPillData(
                'Chờ Manager duyệt',
                summary.myPendingApprovalHandoversCount,
                AppColors.info,
                AppColors.infoLight,
              ),
            ],
            onTap: () => onNavigate(StorekeeperTab.handovers),
          ),
          const SizedBox(height: 8),
          // 2. Phiếu thu hồi
          _WorkflowGroup(
            icon: Icons.assignment_return_outlined,
            title: 'Phiếu thu hồi về kho',
            pills: [
              _StatusPillData(
                'Chưa ai nhận',
                summary.unclaimedReturnsCount,
                AppColors.error,
                AppColors.errorLight,
              ),
              _StatusPillData(
                'Tôi đang kiểm nhận',
                summary.myProcessingReturnsCount,
                AppColors.warning,
                AppColors.warningLight,
              ),
            ],
            onTap: () => onNavigate(StorekeeperTab.handovers),
          ),
          const SizedBox(height: 8),
          // 3. Giao bù máy lỗi
          _WorkflowGroup(
            icon: Icons.replay_circle_filled_outlined,
            title: 'Hợp đồng giao bù máy lỗi',
            pills: [
              _StatusPillData(
                'Chờ thu hồi xong',
                summary.waitingDefectiveReturnContractsCount,
                AppColors.error,
                AppColors.errorLight,
              ),
              _StatusPillData(
                'Sẵn sàng soạn bù',
                summary.readySupplementaryContractsCount,
                AppColors.success,
                AppColors.successLight,
              ),
            ],
            onTap: () => onNavigate(StorekeeperTab.handovers),
          ),
          const SizedBox(height: 8),
          // 4. Đề xuất đổi Model
          _WorkflowGroup(
            icon: Icons.swap_horiz_rounded,
            title: 'Đề xuất đổi Model',
            pills: [
              _StatusPillData(
                'Chờ duyệt',
                summary.pendingReplacementsCount,
                AppColors.warning,
                AppColors.warningLight,
              ),
              _StatusPillData(
                'Đã duyệt',
                summary.approvedReplacementsCount,
                AppColors.success,
                AppColors.successLight,
              ),
              _StatusPillData(
                'Từ chối',
                summary.rejectedReplacementsCount,
                AppColors.error,
                AppColors.errorLight,
              ),
            ],
            onTap: () => onNavigate(StorekeeperTab.handovers),
          ),
        ],
      ),
    );
  }
}

class _StatusPillData {
  const _StatusPillData(this.label, this.count, this.fg, this.bg);
  final String label;
  final int count;
  final Color fg, bg;
}

class _WorkflowGroup extends StatelessWidget {
  const _WorkflowGroup({
    required this.icon,
    required this.title,
    required this.pills,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<_StatusPillData> pills;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in pills)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.count > 0 ? p.bg : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: p.count > 0
                              ? p.fg.withValues(alpha: 0.35)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${p.label}: ${p.count}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: p.count > 0 ? p.fg : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
