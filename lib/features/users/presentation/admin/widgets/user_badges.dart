import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/role_option.dart';
import '../../../data/models/user_account.dart';

/// Nhãn trạng thái tài khoản.
class UserStatusBadge extends StatelessWidget {
  const UserStatusBadge({super.key, required this.status});

  final UserAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      UserAccountStatus.active => (AppColors.success, AppColors.successLight),
      UserAccountStatus.inactive => (
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
      ),
      UserAccountStatus.locked => (AppColors.error, AppColors.errorLight),
    };

    return _Badge(
      label: status.label,
      foreground: foreground,
      background: background,
    );
  }
}

/// Nhãn vai trò tài khoản.
class UserRoleBadge extends StatelessWidget {
  const UserRoleBadge({super.key, required this.role});

  final RoleOption? role;

  @override
  Widget build(BuildContext context) {
    final current = role;

    if (current == null) {
      return const _Badge(
        label: 'Chưa có vai trò',
        foreground: AppColors.textSecondary,
        background: AppColors.surfaceSecondary,
      );
    }

    final isCompany = current.code == 'COMPANY';

    return _Badge(
      label: current.name,
      foreground: isCompany ? AppColors.warning : AppColors.primary,
      background: isCompany ? AppColors.warningLight : AppColors.primaryLight,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Avatar tài khoản, hiển thị chữ cái đầu khi không có ảnh.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 22});

  final UserAccount user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl?.trim();
    final hasAvatar = url != null && url.isNotEmpty;
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim().split(' ').last.characters.first.toUpperCase();

    // Chữ cái đầu hiển thị khi không có ảnh, đang tải hoặc tải lỗi.
    final fallback = Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
