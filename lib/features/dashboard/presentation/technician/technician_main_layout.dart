import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/payment_api.dart';
import 'package:thuethietbi_app/features/technician/data/datasources/technician_api.dart';
import 'package:thuethietbi_app/features/technician/data/datasources/technician_incident_api.dart';
import 'package:thuethietbi_app/features/technician/data/datasources/technician_maintenance_api.dart';
import 'package:thuethietbi_app/features/technician/data/models/technician_models.dart';
import 'package:thuethietbi_app/features/technician/presentation/screens/technician_incident_list_screen.dart';
import 'package:thuethietbi_app/features/technician/presentation/screens/technician_maintenance_list_screen.dart';
import 'package:thuethietbi_app/features/technician/presentation/screens/technician_trip_detail_screen.dart';
import 'package:thuethietbi_app/features/technician/presentation/screens/technician_trip_list_screen.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'technician_dashboard_screen.dart';
import 'technician_tab.dart';

class TechnicianMainLayout extends StatefulWidget {
  const TechnicianMainLayout({super.key});

  @override
  State<TechnicianMainLayout> createState() => _TechnicianMainLayoutState();
}

class _TechnicianMainLayoutState extends State<TechnicianMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  TechnicianTab _currentTab = TechnicianTab.dashboard;

  late final TechnicianApi _technicianApi;
  late final TechnicianMaintenanceApi _maintenanceApi;
  late final TechnicianIncidentApi _incidentApi;
  late final PaymentApi _paymentApi;

  TechnicianDashboard _summary = TechnicianDashboard.empty;
  String? _summaryError;
  int _reloadVersion = 0;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _technicianApi = TechnicianApi(apiClient);
    _maintenanceApi = TechnicianMaintenanceApi(apiClient);
    _incidentApi = TechnicianIncidentApi(apiClient);
    _paymentApi = PaymentApi(apiClient);
    _loadSummary();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await _technicianApi.getDashboard();
      if (mounted) {
        setState(() {
          _summary = data;
          _summaryError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _summaryError = apiErrorMessage(
            e,
            fallback: 'Không tải được số liệu tổng quan kỹ thuật viên.',
          ),
        );
      }
    }
  }

  void _refreshAll() {
    setState(() => _reloadVersion++);
    _loadSummary();
  }

  void _selectTab(TechnicianTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
    if (tab == TechnicianTab.dashboard) {
      _loadSummary();
    }
  }

  Future<void> _openTripById(String assignmentId) async {
    final changed = await TechnicianTripDetailScreen.open(
      context,
      api: _technicianApi,
      paymentApi: _paymentApi,
      assignmentId: assignmentId,
    );
    if (changed == true && mounted) {
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == TechnicianTab.dashboard;

    return PopScope(
      canPop: isDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(TechnicianTab.dashboard);
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
                actions: const [NotificationButton(), SizedBox(width: 4)],
              ),
        drawer: AppDrawer(
          items: [
            for (final tab in TechnicianTab.drawerTabs)
              DrawerItem(
                icon: tab.icon,
                title: tab.title,
                selected: _currentTab == tab,
                onTap: () => _selectTab(tab),
              ),
          ],
          onProfileTap: () => _selectTab(TechnicianTab.account),
          onSettingsTap: () {},
        ),
        body: IndexedStack(
          index: _currentTab.index,
          children: [
            TechnicianDashboardScreen(
              user: user,
              summary: _summary,
              errorMessage: _summaryError,
              onRefresh: _loadSummary,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigate: _selectTab,
              onOpenTrip: _openTripById,
            ),
            TechnicianTripListScreen(
              api: _technicianApi,
              paymentApi: _paymentApi,
              reloadVersion: _reloadVersion,
              onChanged: _refreshAll,
            ),
            TechnicianMaintenanceListScreen(
              maintenanceApi: _maintenanceApi,
              technicianApi: _technicianApi,
              reloadVersion: _reloadVersion,
              onChanged: _refreshAll,
            ),
            TechnicianIncidentListScreen(
              incidentApi: _incidentApi,
              technicianApi: _technicianApi,
              reloadVersion: _reloadVersion,
              onChanged: _refreshAll,
            ),
            DefaultAccountPage(
              name: user.fullName,
              role: user.staff?.position ?? 'Kỹ thuật viên',
              email: user.email ?? '',
              avatarUrl: user.avatarUrl,
              onProfileTap: () {},
              onSettingsTap: () {},
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab.index,
          onTap: (i) => _selectTab(TechnicianTab.values[i]),
          items: [
            for (final tab in TechnicianTab.values)
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
