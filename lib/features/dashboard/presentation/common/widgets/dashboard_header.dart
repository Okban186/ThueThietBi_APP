import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

/// Header xanh của trang Tổng quan (dùng chung cho các actor):
/// menu, logo, chuông thông báo, avatar và lời chào.
///
/// Đặt trong `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light)`
/// để biểu tượng thanh trạng thái hiển thị màu trắng.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.user,
    required this.roleLabel,
    required this.onOpenDrawer,
    required this.onAvatarTap,
    this.bottomPadding = AppSpacing.lg,
  });

  final User user;
  final String roleLabel;
  final VoidCallback onOpenDrawer;
  final VoidCallback onAvatarTap;

  /// Khoảng trống phía dưới, dùng khi có thẻ nội dung đè lên header.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.lg,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: onOpenDrawer,
                    icon: const Icon(Icons.menu_rounded),
                    color: AppColors.onPrimary,
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset('assets/images/equiprent_logo.png'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'EquipRent',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const IconTheme(
                    data: IconThemeData(color: AppColors.onPrimary),
                    child: NotificationButton(),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _Avatar(avatarUrl: user.avatarUrl, onTap: onAvatarTap),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào, ${user.fullName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: AppColors.onPrimarySecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.onTap});

  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasAvatar = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: AppColors.onPrimary,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: hasAvatar ? CachedNetworkImageProvider(url) : null,
          child: hasAvatar
              ? null
              : const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
        ),
      ),
    );
  }
}
