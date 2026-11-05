import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../user/user_profile_card.dart';

class DefaultAccountPage extends StatelessWidget {
  const DefaultAccountPage({
    super.key,
    required this.name,
    required this.role,
    required this.email,
    this.avatarUrl,
    this.onProfileTap,
    this.onSettingsTap,
  });

  final String name;
  final String role;
  final String email;
  final String? avatarUrl;

  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          children: [
            // Thông tin tài khoản
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: UserProfileCard(
                  name: name,
                  role: role,
                  email: email,
                  avatarUrl: avatarUrl,
                  compact: true,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Danh sách chức năng tài khoản
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildAccountItem(
                    icon: Icons.person_outline,
                    title: 'Thông tin cá nhân',
                    onTap: onProfileTap,
                  ),

                  _buildAccountItem(
                    icon: Icons.settings_outlined,
                    title: 'Cài đặt ứng dụng',
                    onTap: onSettingsTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    int notificationCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (notificationCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  notificationCount > 99 ? '99+' : '$notificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
