import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/data/models/user.dart';
import 'drawer/app_drawer.dart';
import 'drawer/drawer_item.dart';
import 'navigation/app_bottom_navigation.dart';
import 'navigation/navigation_item.dart';
import 'user/user_profile_card.dart';

class SharedWidgetsTestScreen extends StatefulWidget {
  const SharedWidgetsTestScreen({super.key});

  @override
  State<SharedWidgetsTestScreen> createState() =>
      _SharedWidgetsTestScreenState();
}

class _SharedWidgetsTestScreenState extends State<SharedWidgetsTestScreen> {
  int currentIndex = 0;
  late AuthSession _authSession;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _authSession = context.read<AuthSession>();
    currentUser = _authSession.currentUser;
  }

  final List<NavigationItem> navigationItems = const [
    NavigationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      title: 'Tổng quan',
    ),
    NavigationItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      title: 'Đặt thuê',
    ),
    NavigationItem(
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      title: 'Khách hàng',
    ),
    NavigationItem(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      title: 'Hợp đồng',
    ),
    NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      title: 'Tài khoản',
    ),
  ];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  List<DrawerItem> _buildDrawerItems() {
    final titles = ['Tổng quan', 'Đặt thuê', 'Khách hàng', 'Hợp đồng'];

    final icons = [
      Icons.dashboard_outlined,
      Icons.calendar_month_outlined,
      Icons.business_outlined,
      Icons.description_outlined,
    ];

    return List.generate(titles.length, (index) {
      return DrawerItem(
        icon: icons[index],
        title: titles[index],
        selected: currentIndex == index,
        onTap: () {
          setState(() {
            currentIndex = index;
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardPage(),
      _buildDemoPage(
        icon: Icons.calendar_month,
        title: 'Đặt thuê',
        description: 'Màn hình kiểm thử chức năng đặt thuê.',
      ),
      _buildDemoPage(
        icon: Icons.business,
        title: 'Khách hàng',
        description: 'Màn hình kiểm thử chức năng khách hàng.',
      ),
      _buildDemoPage(
        icon: Icons.description,
        title: 'Hợp đồng',
        description: 'Màn hình kiểm thử chức năng hợp đồng.',
      ),
      DefaultAccountPage(
        name: currentUser!.fullName,
        role: currentUser!.roles.map((e) => e.name).join(','),
        email: currentUser!.email!,
        avatarUrl: currentUser!.avatarUrl,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EquipRent',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [NotificationButton(), const SizedBox(width: 8)],
      ),

      drawer: AppDrawer(
        items: _buildDrawerItems(),

        onProfileTap: () {
          setState(() {
            currentIndex = 4;
          });
        },

        onSettingsTap: () {
          _showMessage('Mở cài đặt');
        },

        onHelpTap: () {
          _showMessage('Mở trợ giúp');
        },
      ),

      body: IndexedStack(index: currentIndex, children: pages),

      bottomNavigationBar: AppBottomNavigation(
        items: navigationItems,
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }

  // Trang tổng quan kiểm thử.
  Widget _buildDashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        ],
      ),
    );
  }

  // Trang tài khoản.

  Widget _buildAccountPage() {
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
                  name: currentUser!.fullName,
                  role: currentUser!.roles.map((r) => r.name).join(','),
                  email: currentUser!.email,
                  avatarUrl: currentUser!.avatarUrl,
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
                    onTap: () {
                      _showMessage('Mở thông tin cá nhân');
                    },
                  ),

                  _buildAccountItem(
                    icon: Icons.notifications_none,
                    title: 'Thông báo',
                    notificationCount: 3,
                    onTap: () {
                      _showMessage('Mở thông báo');
                    },
                  ),

                  _buildAccountItem(
                    icon: Icons.settings_outlined,
                    title: 'Cài đặt ứng dụng',
                    onTap: () {
                      _showMessage('Mở cài đặt ứng dụng');
                    },
                  ),

                  _buildAccountItem(
                    icon: Icons.help_outline,
                    title: 'Trợ giúp',
                    onTap: () {
                      _showMessage('Mở trợ giúp');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Một dòng chức năng trong trang tài khoản.
  Widget _buildAccountItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int notificationCount = 0,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.textSecondary),

                const SizedBox(width: 14),

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

                if (notificationCount > 0) ...[
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC3545),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.7,
            indent: 48,
            color: AppColors.border,
          ),
      ],
    );
  }

  // Trang mẫu cho các tab.
  Widget _buildDemoPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
