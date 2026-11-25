import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/presentation/company/screens/customer_contract_detail_screen.dart';
import 'package:thuethietbi_app/features/contracts/presentation/company/screens/customer_contract_list_screen.dart';
import 'package:thuethietbi_app/features/dashboard/data/datasources/customer_portal_api.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/customer_dashboard_summary.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';
import 'package:thuethietbi_app/features/equipment/presentation/sales/screens/equipment_catalog_screen.dart';
import 'package:thuethietbi_app/features/incidents/data/datasources/customer_incident_api.dart';
import 'package:thuethietbi_app/features/incidents/presentation/company/screens/customer_incident_detail_screen.dart';
import 'package:thuethietbi_app/features/incidents/presentation/company/screens/customer_incident_form_screen.dart';
import 'package:thuethietbi_app/features/incidents/presentation/company/screens/customer_incident_list_screen.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'company_dashboard_screen.dart';
import 'company_tab.dart';

/// Khung giao diện chính của khách hàng doanh nghiệp (role COMPANY).
///
/// Khách chỉ xem dữ liệu công ty mình: tổng quan, hợp đồng (từ khi được duyệt),
/// danh mục thiết bị; báo sự cố cho máy đang thuê.
class CompanyMainLayout extends StatefulWidget {
  const CompanyMainLayout({super.key});

  @override
  State<CompanyMainLayout> createState() => _CompanyMainLayoutState();
}

class _CompanyMainLayoutState extends State<CompanyMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _contractListKey = GlobalKey<CustomerContractListScreenState>();
  final _incidentListKey = GlobalKey<CustomerIncidentListScreenState>();

  CompanyTab _currentTab = CompanyTab.dashboard;

  late final CustomerPortalApi _api;
  late final EquipmentModelApi _equipmentModelApi;
  late final CustomerIncidentApi _incidentApi;

  CustomerDashboardSummary? _summary;

  @override
  void initState() {
    super.initState();

    final apiClient = context.read<ApiClient>();
    _api = CustomerPortalApi(apiClient);
    _equipmentModelApi = EquipmentModelApi(apiClient);
    _incidentApi = CustomerIncidentApi(apiClient);

    _loadSummary();
  }

  @override
  void dispose() {
    // Header Tổng quan dùng chữ trắng trên thanh trạng thái; trả lại chữ tối.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _api.getDashboard();
      if (mounted) setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        apiErrorMessage(error, fallback: 'Không tải được số liệu tổng quan.'),
      );
    }
  }

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

  void _selectTab(CompanyTab tab) {
    if (tab == _currentTab) return;

    setState(() => _currentTab = tab);

    // Số liệu có thể đã đổi từ phía bên cho thuê.
    switch (tab) {
      case CompanyTab.dashboard:
        _loadSummary();
      case CompanyTab.contracts:
        _contractListKey.currentState?.reload();
      case CompanyTab.incidents:
        _incidentListKey.currentState?.reload();
      case CompanyTab.account:
        break;
    }
  }

  Future<void> _reportIncident() async {
    final user = context.read<AuthSession>().currentUser;
    final created = await CustomerIncidentFormScreen.open(
      context,
      api: _incidentApi,
      contactName: user?.fullName,
      contactPhone: user?.phone,
    );

    if (created == null || !mounted) return;

    _showMessage(
      'Đã gửi ${created.incident.incidentCode}. Bên cho thuê sẽ liên hệ sớm.',
    );
    _selectTab(CompanyTab.incidents);
    _incidentListKey.currentState?.reload();
    await CustomerIncidentDetailScreen.open(
      context,
      _incidentApi,
      created.incident.id,
    );
    _incidentListKey.currentState?.reload();
  }

  Future<void> _openContract(String id) async {
    await CustomerContractDetailScreen.open(context, _api, id);
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;

    // Phiên đăng nhập đã kết thúc, màn hình gốc sẽ chuyển về đăng nhập.
    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == CompanyTab.dashboard;
    final companyName = _summary?.company.name ?? 'Khách hàng doanh nghiệp';

    return PopScope(
      // Nút Back: quay về Tổng quan trước khi thoát ứng dụng.
      canPop: isDashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectTab(CompanyTab.dashboard);
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
            for (final tab in CompanyTab.drawerTabs)
              DrawerItem(
                icon: tab.icon,
                title: tab.title,
                selected: _currentTab == tab,
                onTap: () => _selectTab(tab),
              ),
            DrawerItem(
              icon: Icons.devices_other_outlined,
              title: 'Thiết bị cho thuê',
              onTap: () =>
                  EquipmentCatalogScreen.open(context, _equipmentModelApi),
            ),
          ],
          onProfileTap: () => _selectTab(CompanyTab.account),
          onSettingsTap: () => _showMessage('Cài đặt đang được phát triển.'),
        ),
        body: IndexedStack(
          index: _currentTab.index,
          children: [
            CompanyDashboardScreen(
              user: user,
              summary: _summary,
              onRefresh: _loadSummary,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigate: _selectTab,
              onOpenContract: _openContract,
            ),
            CustomerContractListScreen(key: _contractListKey, api: _api),
            CustomerIncidentListScreen(
              key: _incidentListKey,
              api: _incidentApi,
            ),
            DefaultAccountPage(
              name: user.fullName,
              role: companyName,
              email: user.email ?? '',
              avatarUrl: user.avatarUrl,
              onProfileTap: () =>
                  _showMessage('Thông tin cá nhân đang được phát triển.'),
              onSettingsTap: () =>
                  _showMessage('Cài đặt ứng dụng đang được phát triển.'),
            ),
          ],
        ),
        floatingActionButton: _currentTab == CompanyTab.incidents
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                onPressed: _reportIncident,
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Báo sự cố'),
              )
            : null,
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab.index,
          onTap: (index) => _selectTab(CompanyTab.values[index]),
          items: [
            for (final tab in CompanyTab.values)
              NavigationItem(
                icon: tab.icon,
                selectedIcon: tab.selectedIcon,
                title: tab.title,
              ),
          ],
        ),
      ),
    );
  }
}
