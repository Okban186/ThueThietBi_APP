import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/users/data/datasources/user_api.dart';
import 'package:thuethietbi_app/features/users/data/models/user_account.dart';
import 'package:thuethietbi_app/features/users/presentation/admin/screens/user_form_screen.dart';
import 'package:thuethietbi_app/features/users/presentation/admin/screens/user_list_screen.dart';
import 'package:thuethietbi_app/features/users/presentation/providers/user_management_provider.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'admin_dashboard_screen.dart';
import 'admin_tab.dart';

/// Khung giao diện chính của quản trị viên (ADMIN).
///
/// [UserManagementProvider] chỉ phục vụ nhánh Admin nên được tạo tại đây
/// thay vì đăng ký toàn ứng dụng.
class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key, this.initialTab = AdminTab.dashboard});

  final AdminTab initialTab;

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late AdminTab _currentTab = widget.initialTab;
  late final UserManagementProvider _userProvider;

  @override
  void initState() {
    super.initState();

    _userProvider = UserManagementProvider(UserApi(context.read<ApiClient>()))
      ..load();
  }

  @override
  void dispose() {
    _userProvider.dispose();

    // Header Tổng quan dùng chữ trắng trên thanh trạng thái; trả lại chữ tối.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _selectTab(AdminTab tab) {
    if (tab == _currentTab) return;

    setState(() => _currentTab = tab);
  }

  void _showUsers(UserAccountStatus? status) {
    _userProvider
      ..clearFilters()
      ..setStatusFilter(status);

    _selectTab(AdminTab.users);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature đang được phát triển.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _roleLabel(User user) {
    final position = user.staff?.position?.trim();

    if (position != null && position.isNotEmpty) return position;

    return user.roles.map((role) => role.name).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;

    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == AdminTab.dashboard;
    final showCreateButton = _currentTab != AdminTab.profile;

    return ChangeNotifierProvider<UserManagementProvider>.value(
      value: _userProvider,
      child: PopScope(
        canPop: isDashboard,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _selectTab(AdminTab.dashboard);
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: isDashboard
              ? null
              : AppBar(
                  title: Text(
                    _currentTab == AdminTab.users
                        ? 'Quản lý tài khoản'
                        : _currentTab.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  actions: const [NotificationButton(), SizedBox(width: 8)],
                ),
          drawer: AppDrawer(
            items: [
              for (final tab in AdminTab.drawerTabs)
                DrawerItem(
                  icon: tab.icon,
                  title: tab.title,
                  selected: _currentTab == tab,
                  onTap: () => _selectTab(tab),
                ),
            ],
            onProfileTap: () => _selectTab(AdminTab.profile),
            onSettingsTap: () => _showComingSoon('Cài đặt'),
          ),
          body: IndexedStack(
            index: _currentTab.index,
            children: [
              AdminDashboardScreen(
                user: user,
                roleLabel: _roleLabel(user),
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                onNavigate: _selectTab,
                onShowUsers: _showUsers,
              ),
              const UserListScreen(),
              DefaultAccountPage(
                name: user.fullName,
                role: _roleLabel(user),
                email: user.email ?? '',
                avatarUrl: user.avatarUrl,
                onProfileTap: () => _showComingSoon('Thông tin cá nhân'),
                onSettingsTap: () => _showComingSoon('Cài đặt ứng dụng'),
              ),
            ],
          ),
          floatingActionButton: showCreateButton
              ? Builder(
                  // Builder để context nằm dưới ChangeNotifierProvider.
                  builder: (innerContext) => FloatingActionButton.extended(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    onPressed: () => UserFormScreen.open(innerContext),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Tạo tài khoản'),
                  ),
                )
              : null,
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: _currentTab.index,
            onTap: (index) => _selectTab(AdminTab.values[index]),
            items: [
              for (final tab in AdminTab.values)
                NavigationItem(
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  title: tab.title,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
