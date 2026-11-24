import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/contracts/presentation/providers/rental_contract_provider.dart';
import 'package:thuethietbi_app/features/contracts/presentation/sales/screens/contract_list_screen.dart';
import 'package:thuethietbi_app/features/customers/data/datasources/company_api.dart';
import 'package:thuethietbi_app/features/customers/presentation/providers/company_provider.dart';
import 'package:thuethietbi_app/features/customers/presentation/sales/screens/company_form_screen.dart';
import 'package:thuethietbi_app/features/customers/presentation/sales/screens/company_list_screen.dart';
import 'package:thuethietbi_app/features/dashboard/data/datasources/dashboard_api.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/sales_dashboard_summary.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';
import 'package:thuethietbi_app/features/equipment/presentation/sales/screens/equipment_catalog_screen.dart';
import 'package:thuethietbi_app/features/reservations/data/datasources/reservation_api.dart';
import 'package:thuethietbi_app/features/reservations/presentation/providers/reservation_provider.dart';
import 'package:thuethietbi_app/features/reservations/presentation/sales/screens/reservation_form_screen.dart';
import 'package:thuethietbi_app/features/reservations/presentation/sales/screens/reservation_list_screen.dart';
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
/// Giữ tab đang chọn (đồng bộ Drawer và Bottom Navigation) và tạo các provider
/// chỉ dùng trong nhánh Sales: khách hàng, đặt thuê, hợp đồng.
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

  late final DashboardApi _dashboardApi;
  late final EquipmentModelApi _equipmentModelApi;
  late final CompanyProvider _companyProvider;
  late final ReservationProvider _reservationProvider;
  late final RentalContractProvider _contractProvider;

  /// Số liệu Tổng quan từ `GET /api/dashboard/sales`.
  SalesDashboardSummary _summary = const SalesDashboardSummary.empty();

  @override
  void initState() {
    super.initState();

    final apiClient = context.read<ApiClient>();
    final currentUserId = context.read<AuthSession>().currentUser?.id ?? '';

    _dashboardApi = DashboardApi(apiClient);
    _equipmentModelApi = EquipmentModelApi(apiClient);

    _companyProvider = CompanyProvider(
      CompanyApi(apiClient),
      currentUserId: currentUserId,
    )..load();
    _reservationProvider = ReservationProvider(
      ReservationApi(apiClient),
      _equipmentModelApi,
    )..load();
    _contractProvider = RentalContractProvider(
      RentalContractApi(apiClient),
      _equipmentModelApi,
    )..load();

    _loadSummary();
  }

  @override
  void dispose() {
    _companyProvider.dispose();
    _reservationProvider.dispose();
    _contractProvider.dispose();

    // Header Tổng quan dùng chữ trắng trên thanh trạng thái.
    // Trả lại chữ tối để màn hình sau (ví dụ Đăng nhập) không bị chìm biểu tượng.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _dashboardApi.getSalesSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              apiErrorMessage(
                error,
                fallback: 'Không tải được số liệu tổng quan.',
              ),
            ),
          ),
        );
    }
  }

  void _selectTab(SalesTab tab) {
    if (tab == _currentTab) return;

    setState(() => _currentTab = tab);

    // Số liệu có thể đã đổi sau khi thao tác ở tab khác.
    if (tab == SalesTab.dashboard) _loadSummary();
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

    if (position != null && position.isNotEmpty) return position;

    return user.roles.map((role) => role.name).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;

    // Phiên đăng nhập đã kết thúc, màn hình gốc sẽ chuyển về đăng nhập.
    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == SalesTab.dashboard;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CompanyProvider>.value(value: _companyProvider),
        ChangeNotifierProvider<ReservationProvider>.value(
          value: _reservationProvider,
        ),
        ChangeNotifierProvider<RentalContractProvider>.value(
          value: _contractProvider,
        ),
      ],
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
              DrawerItem(
                icon: Icons.devices_other_outlined,
                title: 'Thiết bị',
                onTap: () =>
                    EquipmentCatalogScreen.open(context, _equipmentModelApi),
              ),
            ],
            onProfileTap: () => _selectTab(SalesTab.account),
            onSettingsTap: () => _showComingSoon('Cài đặt'),
          ),
          body: IndexedStack(
            index: _currentTab.index,
            children: [
              SalesDashboardScreen(
                user: user,
                roleLabel: _roleLabel(user),
                summary: _summary,
                onRefresh: _loadSummary,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                onNavigate: _selectTab,
              ),
              const ReservationListScreen(),
              const CompanyListScreen(),
              const ContractListScreen(),
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
    // Builder để context nằm dưới các provider của layout.
    return switch (_currentTab) {
      SalesTab.dashboard => Builder(
        builder: (innerContext) => FloatingActionButton(
          tooltip: 'Tạo đặt thuê',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: const CircleBorder(),
          onPressed: () => ReservationFormScreen.open(innerContext),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      SalesTab.reservations => Builder(
        builder: (innerContext) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          onPressed: () => ReservationFormScreen.open(innerContext),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tạo đặt thuê'),
        ),
      ),
      SalesTab.customers => Builder(
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
