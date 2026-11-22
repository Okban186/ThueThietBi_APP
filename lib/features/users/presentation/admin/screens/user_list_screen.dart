import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';

import '../../../data/models/user_account.dart';
import '../../providers/user_management_provider.dart';
import '../widgets/user_badges.dart';
import 'user_detail_screen.dart';

/// Danh sách tài khoản (tab "Tài khoản" của Admin).
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<UserManagementProvider>().keyword,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserManagementProvider>();
    final users = provider.filteredUsers;

    return Column(
      children: [
        _SearchAndFilters(controller: _searchController, provider: provider),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.load,
            child: _buildBody(provider, users),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(UserManagementProvider provider, List<UserAccount> users) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && !provider.hasLoaded) {
      return _ScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: provider.errorMessage,
          action: FilledButton(
            onPressed: provider.load,
            child: const Text('Thử lại'),
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return const _ScrollableCenter(
        child: AppEmptyView(
          icon: Icons.person_search_rounded,
          title: 'Không có tài khoản phù hợp',
          message: 'Thử đổi từ khóa hoặc bộ lọc.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        96,
      ),
      itemCount: users.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${users.length} tài khoản',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final user = users[index - 1];

        return _UserCard(
          user: user,
          onTap: () => UserDetailScreen.open(context, user.id),
        );
      },
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({required this.controller, required this.provider});

  final TextEditingController controller;
  final UserManagementProvider provider;

  @override
  Widget build(BuildContext context) {
    final roleName = provider.roles
        .where((role) => role.code == provider.roleFilter)
        .map((role) => role.name)
        .firstOrNull;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: provider.setKeyword,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, tên đăng nhập, mã NV...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        provider.setKeyword('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: provider.statusFilter == null,
                  onTap: () => provider.setStatusFilter(null),
                ),
                for (final status in UserAccountStatus.values)
                  _FilterChip(
                    label: status.label,
                    selected: provider.statusFilter == status,
                    onTap: () => provider.setStatusFilter(status),
                  ),
                _FilterChip(
                  label: roleName ?? 'Vai trò',
                  selected: roleName != null,
                  icon: Icons.filter_list_rounded,
                  onTap: () => _pickRole(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRole(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Lọc theo vai trò',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Tất cả vai trò'),
                selected: provider.roleFilter == null,
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
              for (final role in provider.roles)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(role.name),
                  subtitle: Text(role.code),
                  selected: provider.roleFilter == role.code,
                  onTap: () => Navigator.pop(sheetContext, role.code),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      provider.setRoleFilter(selected.isEmpty ? null : selected);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.onPrimary : AppColors.textPrimary,
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final UserAccount user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      user.username,
      if (user.employeeCode != null) user.employeeCode!,
      if (user.companyName != null) user.companyName!,
    ].join(' · ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              UserAvatar(user: user),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        UserRoleBadge(role: user.role),
                        UserStatusBadge(status: user.status),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cho phép kéo để tải lại cả khi nội dung là trạng thái trống.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
