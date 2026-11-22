import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/customers/data/datasources/company_api.dart';
import 'package:thuethietbi_app/features/customers/presentation/providers/company_provider.dart';
import 'package:thuethietbi_app/features/customers/presentation/sales/screens/company_form_screen.dart';
import 'package:thuethietbi_app/features/customers/presentation/sales/screens/company_list_screen.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/sales_dashboard_summary.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'sales_dashboard_screen.dart';
import 'sales_tab.dart';

/// Khung giao diện chính của nhân viên kinh doanh (SALES).
///
/// Giữ tab đang chọn, đồng bộ giữa Drawer và Bottom Navigation.
/// Màn hình nghiệp vụ (đặt thuê, khách hàng, hợp đồng) nằm trong feature
/// tương ứng và được gắn vào đây khi hoàn thành.
class SalesMainLayout extends StatefulWidget {
  const SalesMainLayout({super.key, this.initialTab = SalesTab.dashboard});

  /// Tab hiển thị khi mở, ví dụ mở thẳng "Hợp đồng" từ thông báo.
  final SalesTab initialTab;

  @override
  State<SalesMainLayout> createState() => _SalesMainLayoutState();
}

class _SalesMainLayoutState extends State<SalesMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late SalesTab _currentTab = widget.initialTab;

  // TODO: Thay bằng dữ liệu từ API thống kê khi Backend hoàn thành.
  // Riêng số "Công ty" đã lấy thật từ CompanyProvider.
  final SalesDashboardSummary _sampleSummary = SalesDashboardSummary.sample();

  /// Công ty khách hàng: dùng cho tab Khách hàng và thẻ "Công ty" ở Tổng quan.
  late final CompanyProvider _companyProvider;

  @override
  void initState() {
    super.initState();

    _companyProvider = CompanyProvider(
      CompanyApi(context.read<ApiClient>()),
      currentUserId: context.read<AuthSession>().currentUser?.id ?? '',
    )..load();
  }

  @override
  void dispose() {
    _companyProvider.dispose();

    // Header Tổng quan dùng chữ trắng trên thanh trạng thái.
    // Trả lại chữ tối để màn hình sau (ví dụ Đăng nhập) không bị chìm biểu tượng.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _selectTab(SalesTab tab) {
    if (tab == _currentTab) return;

    setState(() {
      _currentTab = tab;
    });
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature đang được phát triển.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Nhãn vai trò: ưu tiên chức vụ nhân viên, sau đó là tên role.
  String _roleLabel(User user) {
    final position = user.staff?.position?.trim();

    if (position != null && position.isNotEmpty) {
      return position;
    }

    return user.roles.map((role) => role.name).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;

    // Phiên đăng nhập đã kết thúc, màn hình gốc sẽ chuyển về đăng nhập.
    if (user == null) {
      return const SizedBox.shrink();
    }

    final isDashboard = _currentTab == SalesTab.dashboard;

    return ChangeNotifierProvider<CompanyProvider>.value(
      value: _companyProvider,
      child: PopScope(
        // Nút Back: quay về Tổng quan trước khi thoát ứng dụng.
        canPop: isDashboard,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _selectTab(SalesTab.dashboard);
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: isDashboard
              ? null
              : AppBar(
                  title: Text(
                    _currentTab.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  actions: const [NotificationButton(), SizedBox(width: 8)],
                ),
          drawer: AppDrawer(
            items: [
              for (final tab in SalesTab.drawerTabs)
                DrawerItem(
                  icon: tab.icon,
                  title: tab.title,
                  selected: _currentTab == tab,
                  onTap: () => _selectTab(tab),
                ),
            ],
            onProfileTap: () => _selectTab(SalesTab.account),
            onSettingsTap: () => _showComingSoon('Cài đặt'),
          ),
          body: IndexedStack(
            index: _currentTab.index,
            children: [
              ListenableBuilder(
                listenable: _companyProvider,
                builder: (context, _) => SalesDashboardScreen(
                  user: user,
                  roleLabel: _roleLabel(user),
                  summary: _companyProvider.hasLoaded
                      ? _sampleSummary.copyWith(
                          companies: _companyProvider.myCompanyCount,
                        )
                      : _sampleSummary,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  onNavigate: _selectTab,
                ),
              ),
              const AppEmptyView(
                icon: Icons.calendar_month_outlined,
                title: 'Đặt thuê',
                message: 'Danh sách phiếu đặt thuê đang được phát triển.',
              ),
              const CompanyListScreen(),
              const AppEmptyView(
                icon: Icons.description_outlined,
                title: 'Hợp đồng',
                message: 'Danh sách hợp đồng đang được phát triển.',
              ),
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
          floatingActionButton: _buildFloatingActionButton(),
          floatingActionButtonLocation: isDashboard
              ? FloatingActionButtonLocation.centerFloat
              : FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: _currentTab.index,
            onTap: (index) => _selectTab(SalesTab.values[index]),
            items: [
              for (final tab in SalesTab.values)
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

  Widget? _buildFloatingActionButton() {
    return switch (_currentTab) {
      SalesTab.dashboard => FloatingActionButton(
        tooltip: 'Tạo đặt thuê',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: const CircleBorder(),
        onPressed: () => _showComingSoon('Tạo phiếu đặt thuê'),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      SalesTab.customers => Builder(
        // Builder để context nằm dưới ChangeNotifierProvider<CompanyProvider>.
        builder: (innerContext) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          onPressed: () => CompanyFormScreen.open(innerContext),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Thêm khách hàng'),
        ),
      ),
      _ => null,
    };
  }
}
