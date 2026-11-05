import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/notifications/presentation/common/screens/notification_screen.dart';
import 'package:thuethietbi_app/shared/widgets/user/user_profile_card.dart';

import '../../../core/auth/auth_session.dart';
import '../../../features/auth/data/datasources/auth_api.dart';
import '../../../features/notifications/data/providers/notification_provider.dart';
import 'drawer_item.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.items,
    required this.onProfileTap,
    this.onSettingsTap,
    this.onNotificationsTap,
    this.onHelpTap,
    this.onLogoutTap,
  });

  final List<DrawerItem> items;

  final VoidCallback onProfileTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onLogoutTap;
  @override
  State<StatefulWidget> createState() {
    return _AppDrawer();
  }
}

class _AppDrawer extends State<AppDrawer> {
  static const Color _textColor = Color(0xFF172B55);
  static const Color _secondaryColor = Color(0xFF64748B);
  static const Color _selectedColor = Color(0xFFE4ECFF);
  bool _isNotificationSelected = false;
  late final AuthSession _authSession;
  @override
  void initState() {
    super.initState();

    _authSession = context.read<AuthSession>();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 304,
      elevation: 12,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            _buildUserProfile(context),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ...widget.items.map(
                      (item) => _buildNavigationItem(context, item),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE8EDF5),
                      ),
                    ),

                    _buildFixedItem(
                      icon: Icons.settings_outlined,
                      title: 'Cài đặt',
                      onTap: widget.onSettingsTap ?? () {},
                      context: context,
                    ),

                    Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, child) {
                        final count = notificationProvider.unreadCount;

                        return _buildFixedItem(
                          icon: Icons.notifications_none_rounded,
                          title: 'Thông báo',
                          selected: _isNotificationSelected,
                          onTap: () {
                            setState(() {
                              _isNotificationSelected = true;
                            });

                            Navigator.of(context).pop();

                            if (widget.onNotificationsTap != null) {
                              widget.onNotificationsTap!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );
                            }
                          },
                          trailing: count > 0
                              ? _buildNotificationBadge(count)
                              : null,
                          context: context,
                        );
                      },
                    ),

                    // _buildFixedItem(
                    //   icon: Icons.help_outline_rounded,
                    //   title: 'Trợ giúp',
                    //   onTap: onHelpTap,
                    // ),
                    _buildFixedItem(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      onTap: widget.onLogoutTap ?? _showLogoutDialog,
                      context: context,
                      closeDrawer: false,
                    ),
                  ],
                ),
              ),
            ),

            Image.asset('assets/images/login_city_bottom.png'),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    final authApi = context.read<AuthApi>();
    final authSession = context.read<AuthSession>();

    try {
      await authApi.logout();
    } catch (e) {
      // API logout thất bại vẫn phải xóa phiên cục bộ.
    } finally {
      await authSession.endSession();
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/equiprent_logo.png',
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'EquipRent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF102B62),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    final user = _authSession.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: UserProfileCard(
        name: user!.fullName,
        role: user.roles.join(','),
        avatarUrl: user.avatarUrl,
        onTap: () {
          Navigator.of(context).pop();
          widget.onProfileTap();
        },
      ),
    );
  }

  Widget _buildNavigationItem(BuildContext context, DrawerItem item) {
    final bool selected = item.selected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? _selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _isNotificationSelected = false;
            });
            Navigator.of(context).pop();
            item.onTap();
          },
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 21,
                    color: selected ? AppColors.primary : _textColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: selected ? AppColors.primary : _textColor,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    BuildContext? context,
    bool selected = false,
    Widget? trailing,
    bool closeDrawer = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _isNotificationSelected = false;
            });
            if (closeDrawer && context != null) {
              Navigator.of(context).pop();
            }

            onTap();
          },
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: _textColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(int count) {
    return UnconstrainedBox(
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFD93648),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
