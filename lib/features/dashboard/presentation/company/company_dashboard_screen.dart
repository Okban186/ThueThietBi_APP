import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/customer_dashboard_summary.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'company_tab.dart';

/// Trang "Tổng quan" của khách hàng doanh nghiệp.
class CompanyDashboardScreen extends StatelessWidget {
  const CompanyDashboardScreen({
    super.key,
    required this.user,
    required this.summary,
    required this.onRefresh,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onOpenContract,
  });

  final User user;

  /// `null` khi chưa tải xong.
  final CustomerDashboardSummary? summary;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDrawer;
  final ValueChanged<CompanyTab> onNavigate;
  final ValueChanged<String> onOpenContract;

  // Phần thẻ tổng quan đè lên header xanh.
  static const double _overlap = 36;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            children: [
              DashboardHeader(
                user: user,
                roleLabel: summary?.company.name ?? 'Khách hàng doanh nghiệp',
                bottomPadding: _overlap + AppSpacing.lg,
                onOpenDrawer: onOpenDrawer,
                onAvatarTap: () => onNavigate(CompanyTab.account),
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: summary == null
                      ? const _SectionCard(
                          child: SizedBox(
                            height: 160,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      : Column(
                          children: [
                            _OverviewCard(
                              summary: summary,
                              onNavigate: onNavigate,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _UpcomingCard(
                              contracts: summary.upcomingContracts,
                              onOpenContract: onOpenContract,
                              onSeeAll: () => onNavigate(CompanyTab.contracts),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _ContactCard(company: summary.company),
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary, required this.onNavigate});

  final CustomerDashboardSummary summary;
  final ValueChanged<CompanyTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    void openContracts() => onNavigate(CompanyTab.contracts);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tình hình thuê thiết bị',
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
                icon: Icons.handshake_outlined,
                value: '${summary.activeContracts}',
                label: 'Hợp đồng đang thuê',
                onTap: openContracts,
              ),
              _MetricCard(
                icon: Icons.inventory_2_outlined,
                value: '${summary.rentedUnits}',
                label: 'Máy đang thuê',
                onTap: openContracts,
              ),
              _MetricCard(
                icon: Icons.draw_outlined,
                value: '${summary.pendingSignatureContracts}',
                label: 'Chờ ký',
                highlight: summary.pendingSignatureContracts > 0,
                onTap: openContracts,
              ),
              _MetricCard(
                icon: Icons.event_busy_outlined,
                value: '${summary.endingSoonContracts}',
                label: 'Kết thúc trong 7 ngày',
                highlight: summary.endingSoonContracts > 0,
                onTap: openContracts,
              ),
            ],
          ),
          const Divider(height: AppSpacing.xxl),
          _MoneyRow(
            label: 'Giá trị hợp đồng đang thuê',
            value: summary.activeContractsValue,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MoneyRow(
            label: 'Còn phải thanh toán',
            value: summary.outstandingAmount,
            color: summary.outstandingAmount > 0
                ? AppColors.error
                : AppColors.success,
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
    this.highlight = false,
  });

  final IconData icon;
  final String value, label;
  final VoidCallback onTap;

  /// Tô màu cảnh báo khi có việc cần chú ý.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.warning : AppColors.primary;

    return Material(
      color: highlight ? AppColors.warningLight : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight ? AppColors.warning : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(
          CurrencyFormatter.vnd(value),
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.contracts,
    required this.onOpenContract,
    required this.onSeeAll,
  });

  final List<CustomerContractBrief> contracts;
  final ValueChanged<String> onOpenContract;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hợp đồng đang theo dõi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('Xem tất cả')),
            ],
          ),
          if (contracts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Chưa có hợp đồng đang thuê hoặc chờ ký.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final c in contracts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onOpenContract(c.id),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  c.contractCode,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${DateFormatter.dateRange(c.startDate, c.endDate)}\n${_daysLeftText(c.daysLeft)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.daysLeft <= 7
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
                isThreeLine: true,
                trailing: ContractStatusBadge(status: c.status),
              ),
        ],
      ),
    );
  }

  static String _daysLeftText(int daysLeft) {
    if (daysLeft < 0) return 'Đã quá hạn ${-daysLeft} ngày';
    if (daysLeft == 0) return 'Kết thúc hôm nay';
    return 'Còn $daysLeft ngày';
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.company});

  final CustomerCompany company;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin công ty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContactRow(
            icon: Icons.business_outlined,
            text: '${company.name} (${company.companyCode})',
          ),
          _ContactRow(
            icon: Icons.badge_outlined,
            text: 'MST ${company.taxCode}',
          ),
          if (company.address != null)
            _ContactRow(
              icon: Icons.location_on_outlined,
              text: company.address!,
            ),
          if (company.salesName != null) ...[
            const Divider(height: AppSpacing.xl),
            const Text(
              'Nhân viên kinh doanh phụ trách',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            _ContactRow(
              icon: Icons.support_agent_outlined,
              text: company.salesName!,
            ),
            if (company.salesPhone != null)
              _ContactRow(
                icon: Icons.phone_outlined,
                text: company.salesPhone!,
              ),
            if (company.salesEmail != null)
              _ContactRow(icon: Icons.mail_outline, text: company.salesEmail!),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
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
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
