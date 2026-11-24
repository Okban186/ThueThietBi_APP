import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/auth/data/models/user.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/storekeeper_dashboard_summary.dart';
import 'package:thuethietbi_app/features/dashboard/presentation/storekeeper/storekeeper_dashboard_screen.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/storekeeper_equipment_api.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/category_warehourse_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_model_form_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_model_list.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_unit_form_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_unit_list_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/widgets/quick_import_equipment_sheet.dart';
import 'package:thuethietbi_app/shared/widgets/account/default_account_page.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/app_drawer.dart';
import 'package:thuethietbi_app/shared/widgets/drawer/drawer_item.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:thuethietbi_app/shared/widgets/navigation/navigation_item.dart';
import 'package:thuethietbi_app/shared/widgets/notification/notification_button.dart';

import 'storekeeper_tab.dart';

class StorekeeperMainLayout extends StatefulWidget {
  const StorekeeperMainLayout({super.key, required this.isLeadStorekeeper});

  final bool isLeadStorekeeper;

  @override
  State<StorekeeperMainLayout> createState() => _StorekeeperMainLayoutState();
}

class _StorekeeperMainLayoutState extends State<StorekeeperMainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StorekeeperTab _currentTab = StorekeeperTab.dashboard;

  late final StorekeeperEquipmentApi _api;
  late final StorekeeperEquipmentProvider _provider;
  StorekeeperDashboardSummary _summary =
      const StorekeeperDashboardSummary.empty();

  @override
  void initState() {
    super.initState();
    _api = StorekeeperEquipmentApi(context.read<ApiClient>());
    _provider = StorekeeperEquipmentProvider(
      _api,
      isLeadStorekeeper: widget.isLeadStorekeeper,
    )..loadAll();
    _loadSummary();
  }

  @override
  void dispose() {
    _provider.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await _api.getDashboardSummary();
      if (mounted) setState(() => _summary = data);
    } catch (_) {}
  }

  void _selectTab(StorekeeperTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
    if (tab == StorekeeperTab.dashboard) _loadSummary();
  }

  String _roleLabel(User user) {
    if (widget.isLeadStorekeeper) return 'Thủ kho tổng hợp';
    final pos = user.staff?.position?.trim();
    return (pos != null && pos.isNotEmpty) ? pos : 'Thủ kho';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDashboard = _currentTab == StorekeeperTab.dashboard;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: PopScope(
        canPop: isDashboard,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selectTab(StorekeeperTab.dashboard);
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
              for (final tab in StorekeeperTab.drawerTabs)
                DrawerItem(
                  icon: tab.icon,
                  title: tab.title,
                  selected: _currentTab == tab,
                  onTap: () => _selectTab(tab),
                ),
              // CHỈ LEAD_STOREKEEPER mới thấy mục quản lý Kho bãi & Danh mục
              if (widget.isLeadStorekeeper) ...[
                DrawerItem(
                  icon: Icons.account_tree_outlined,
                  title: 'Danh mục thiết bị',
                  onTap: () => CategoryWarehouseScreen.open(
                    context,
                    _provider,
                    initialTab: 1,
                  ),
                ),
              ],
            ],
            onProfileTap: () => _selectTab(StorekeeperTab.account),
            onSettingsTap: () {},
          ),
          body: IndexedStack(
            index: _currentTab.index,
            children: [
              StorekeeperDashboardScreen(
                user: user,
                roleLabel: _roleLabel(user),
                isLeadStorekeeper: widget.isLeadStorekeeper,
                summary: _summary,
                onRefresh: () async {
                  await _loadSummary();
                  await _provider.loadAll();
                },
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                onNavigate: _selectTab,
                onOpenWarehouses: () => CategoryWarehouseScreen.open(
                  context,
                  _provider,
                  initialTab: 0,
                ),
              ),
              const EquipmentModelListScreen(),
              const EquipmentUnitListScreen(),
              DefaultAccountPage(
                name: user.fullName,
                role: _roleLabel(user),
                email: user.email ?? '',
                avatarUrl: user.avatarUrl,
                onProfileTap: () {},
                onSettingsTap: () {},
              ),
            ],
          ),
          // ẨN HOÀN TOÀN nút tạo mới nếu chỉ là STOREKEEPER thường
          floatingActionButton: widget.isLeadStorekeeper
              ? _buildLeadFab()
              : null,
          floatingActionButtonLocation: isDashboard
              ? FloatingActionButtonLocation.centerFloat
              : FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: _currentTab.index,
            onTap: (i) => _selectTab(StorekeeperTab.values[i]),
            items: [
              for (final tab in StorekeeperTab.values)
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

  Widget? _buildLeadFab() {
    return switch (_currentTab) {
      StorekeeperTab.dashboard => Builder(
        builder: (ctx) => FloatingActionButton(
          tooltip: 'Tạo nhanh',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: const CircleBorder(),
          onPressed: () => _showQuickCreateSheet(ctx),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      StorekeeperTab.models => Builder(
        builder: (ctx) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm Model'),
          onPressed: () async {
            final ok = await EquipmentModelFormScreen.open(ctx, _provider);
            if (ok == true) _loadSummary();
          },
        ),
      ),
      StorekeeperTab.equipments => Builder(
        builder: (ctx) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text('Nhập thiết bị'),
          onPressed: () async {
            final ok = await QuickImportEquipmentSheet.open(ctx, _provider);
            if (ok == true) _loadSummary();
          },
        ),
      ),
      _ => null,
    };
  }

  void _showQuickCreateSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thao tác Trưởng kho',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.category_rounded, color: AppColors.primary),
                ),
                title: const Text(
                  'Tạo Model thiết bị mới',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Khai báo mã, giá thuê, thông số & hình ảnh',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  EquipmentModelFormScreen.open(ctx, _provider);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.successLight,
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.success,
                  ),
                ),
                title: const Text(
                  'Nhập thiết bị vật lý (theo Serial)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Hỗ trợ nhập 1 máy hoặc nhiều serial cùng lúc',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  QuickImportEquipmentSheet.open(ctx, _provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
