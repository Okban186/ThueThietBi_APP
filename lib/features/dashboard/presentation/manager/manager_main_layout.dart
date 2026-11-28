import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/create_delivery_trip_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/create_retrieval_trip_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/manager_approvals_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/manager_contract_list_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/manager_incident_list_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/manager_schedule_screen.dart';
import 'package:thuethietbi_app/features/manager/presentation/screens/manager_supplementary_screen.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'manager_dashboard_screen.dart';
import 'manager_tab.dart';

class ManagerMainLayout extends StatefulWidget {
  const ManagerMainLayout({super.key});

  @override
  State<ManagerMainLayout> createState() => _ManagerMainLayoutState();
}

class _ManagerMainLayoutState extends State<ManagerMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ManagerTab _currentTab = ManagerTab.dashboard;

  late final ManagerApi _managerApi;
  late final RentalContractApi _contractApi;

  Map<String, dynamic> _summary = const <String, dynamic>{};
  int _reloadVersion = 0;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _managerApi = ManagerApi(apiClient);
    _contractApi = RentalContractApi(apiClient);
    _loadSummary();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await _managerApi.getDashboardSummary();
      if (mounted) setState(() => _summary = data);
    } catch (_) {}
  }

  void _refreshAll() {
    setState(() => _reloadVersion++);
    _loadSummary();
  }

  void _selectTab(ManagerTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
    if (tab == ManagerTab.dashboard) {
      _loadSummary();
    }
  }

  Future<void> _openApprovals() async {
    await ManagerApprovalsScreen.open(context, _managerApi, _contractApi);
    if (mounted) _refreshAll();
  }

  Future<void> _openCreateTrip() async {
    final created = await CreateDeliveryTripScreen.open(
      context,
      managerApi: _managerApi,
      contractApi: _contractApi,
    );
    if (created == true && mounted) {
      _refreshAll();
    }
  }

  Future<void> _openSupplementary() async {
    final changed = await ManagerSupplementaryScreen.open(
      context,
      managerApi: _managerApi,
      contractApi: _contractApi,
    );
    if (changed == true && mounted) {
      _refreshAll();
    }
  }

  Future<void> _openCreateRetrieval() async {
    final created = await CreateRetrievalTripScreen.open(
      context,
      managerApi: _managerApi,
    );
    if (created == true && mounted) {
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == ManagerTab.dashboard;

    return PopScope(
      canPop: isDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(ManagerTab.dashboard);
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
                actions: [
                  IconButton(
                    tooltip: 'Duyệt yêu cầu nhân viên',
                    icon: const Icon(Icons.fact_check_outlined),
                    onPressed: _openApprovals,
                  ),
                  const NotificationButton(),
                  const SizedBox(width: 4),
                ],
              ),
        drawer: AppDrawer(
          items: [
            for (final tab in ManagerTab.drawerTabs)
              DrawerItem(
                icon: tab.icon,
                title: tab.title,
                selected: _currentTab == tab,
                onTap: () => _selectTab(tab),
              ),
            DrawerItem(
              icon: Icons.replay_circle_filled_outlined,
              title: 'Quản lý & Tạo lịch giao bù',
              onTap: _openSupplementary,
            ),
            DrawerItem(
              icon: Icons.assignment_return_outlined,
              title: 'Lập chuyến thu hồi ',
              onTap: _openCreateRetrieval,
            ),
            DrawerItem(
              icon: Icons.fact_check_outlined,
              title: 'Duyệt yêu cầu & Hóa đơn thu',
              onTap: _openApprovals,
            ),
          ],
          onProfileTap: () => _selectTab(ManagerTab.account),
          onSettingsTap: () {},
        ),
        body: IndexedStack(
          index: _currentTab.index,
          children: [
            ManagerDashboardScreen(
              user: user,
              summary: _summary,
              onRefresh: _loadSummary,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigate: _selectTab,
              onOpenApprovals: _openApprovals,
              onOpenCreateTrip: _openCreateTrip,
              onOpenSupplementary: _openSupplementary,
              onOpenCreateRetrieval: _openCreateRetrieval,
            ),
            ManagerContractListScreen(
              contractApi: _contractApi,
              managerApi: _managerApi,
              reloadVersion: _reloadVersion,
              onChanged: _refreshAll,
            ),
            ManagerScheduleScreen(
              managerApi: _managerApi,
              reloadVersion: _reloadVersion,
            ),
            ManagerIncidentListScreen(
              managerApi: _managerApi,
              reloadVersion: _reloadVersion,
              onChanged: _loadSummary,
            ),
            DefaultAccountPage(
              name: user.fullName,
              role: user.staff?.position ?? 'Quản lý vận hành',
              email: user.email ?? '',
              avatarUrl: user.avatarUrl,
              onProfileTap: () {},
              onSettingsTap: () {},
            ),
          ],
        ),
        floatingActionButton: _currentTab == ManagerTab.schedule
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                icon: const Icon(Icons.route_rounded),
                label: const Text('Lập / Ghép chuyến'),
                onPressed: _openCreateTrip,
              )
            : null,
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab.index,
          onTap: (i) => _selectTab(ManagerTab.values[i]),
          items: [
            for (final tab in ManagerTab.values)
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
