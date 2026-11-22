import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/common/widgets/dashboard_header.dart';
import 'package:thuethietbi_app/features/users/data/models/user_account.dart';
import 'package:thuethietbi_app/features/users/presentation/admin/screens/user_detail_screen.dart';
import 'package:thuethietbi_app/features/users/presentation/admin/widgets/user_badges.dart';
import 'package:thuethietbi_app/features/users/presentation/providers/user_management_provider.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'admin_tab.dart';

/// Trang "Tổng quan" của quản trị viên.
/// Số liệu tính từ danh sách tài khoản trong [UserManagementProvider].
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onShowUsers,
  });

  final User user;
  final String roleLabel;
  final VoidCallback onOpenDrawer;
  final ValueChanged<AdminTab> onNavigate;

  /// Mở tab Tài khoản với bộ lọc trạng thái (null: tất cả).
  final ValueChanged<UserAccountStatus?> onShowUsers;

  static const double _overlap = 36;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserManagementProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: provider.load,
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
                onAvatarTap: () => onNavigate(AdminTab.profile),
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: _buildContent(context, provider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserManagementProvider provider) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (provider.errorMessage != null && !provider.hasLoaded) {
      return _Card(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.error,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(provider.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: provider.load,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _OverviewCard(provider: provider, onShowUsers: onShowUsers),
        const SizedBox(height: AppSpacing.lg),
        _RoleDistributionCard(provider: provider),
        const SizedBox(height: AppSpacing.lg),
        _RecentUsersCard(
          users: provider.recentlyCreated,
          onSeeAll: () => onShowUsers(null),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.provider, required this.onShowUsers});

  final UserManagementProvider provider;
  final ValueChanged<UserAccountStatus?> onShowUsers;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan tài khoản',
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
                icon: Icons.groups_outlined,
                color: AppColors.primary,
                value: provider.users.length,
                label: 'Tổng tài khoản',
                onTap: () => onShowUsers(null),
              ),
              _MetricCard(
                icon: Icons.verified_user_outlined,
                color: AppColors.success,
                value: provider.countByStatus(UserAccountStatus.active),
                label: 'Đang hoạt động',
                onTap: () => onShowUsers(UserAccountStatus.active),
              ),
              _MetricCard(
                icon: Icons.lock_outline_rounded,
                color: AppColors.error,
                value: provider.countByStatus(UserAccountStatus.locked),
                label: 'Đã khóa',
                onTap: () => onShowUsers(UserAccountStatus.locked),
              ),
              _MetricCard(
                icon: Icons.person_off_outlined,
                color: AppColors.textSecondary,
                value: provider.countByStatus(UserAccountStatus.inactive),
                label: 'Ngừng hoạt động',
                onTap: () => onShowUsers(UserAccountStatus.inactive),
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
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
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

class _RoleDistributionCard extends StatelessWidget {
  const _RoleDistributionCard({required this.provider});

  final UserManagementProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.users.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theo vai trò',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final role in provider.roles) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    role.name,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${provider.countByRole(role.code)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : provider.countByRole(role.code) / total,
                minHeight: 6,
                backgroundColor: AppColors.primaryLight,
                color: role.code == 'COMPANY'
                    ? AppColors.warning
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _RecentUsersCard extends StatelessWidget {
  const _RecentUsersCard({required this.users, required this.onSeeAll});

  final List<UserAccount> users;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tài khoản mới tạo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('Xem tất cả')),
            ],
          ),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Chưa có tài khoản nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final user in users)
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                onTap: () => UserDetailScreen.open(context, user.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      UserAvatar(user: user, radius: 19),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              user.role?.name ?? 'Chưa có vai trò',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormatter.relative(user.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

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
