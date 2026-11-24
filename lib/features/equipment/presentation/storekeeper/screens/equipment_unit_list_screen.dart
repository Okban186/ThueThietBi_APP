import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

import 'equipment_unit_form_screen.dart';

class EquipmentUnitListScreen extends StatefulWidget {
  const EquipmentUnitListScreen({super.key});

  @override
  State<EquipmentUnitListScreen> createState() =>
      _EquipmentUnitListScreenState();
}

class _EquipmentUnitListScreenState extends State<EquipmentUnitListScreen> {
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  String _keyword = '';
  String? _statusFilter;

  static const _statuses = <(String?, String)>[
    (null, 'Tất cả'),
    ('AVAILABLE', 'Khả dụng'),
    ('RENTED', 'Đang thuê'),
    ('RESERVED', 'Giữ chỗ'),
    ('MAINTENANCE', 'Bảo trì'),
    ('DAMAGED', 'Hỏng'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<StorekeeperEquipmentProvider>().loadMoreEquipments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorekeeperEquipmentProvider>();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (v) {
                  _keyword = v;
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 350),
                    () => provider.loadEquipments(
                      keyword: _keyword,
                      status: _statusFilter,
                    ),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo Serial hoặc tên model...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (val, label) = _statuses[i];
                    return AppFilterChip(
                      label: label,
                      selected: _statusFilter == val,
                      onTap: () {
                        setState(() => _statusFilter = val);
                        provider.loadEquipments(keyword: _keyword, status: val);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hiển thị ${provider.equipments.length} / ${provider.equipmentsTotalCount} thiết bị',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.loadEquipments(
              keyword: _keyword,
              status: _statusFilter,
            ),
            child: provider.isLoadingEquipments
                ? const Center(child: CircularProgressIndicator())
                : provider.equipments.isEmpty
                ? const AppEmptyView(
                    icon: Icons.inventory_2_outlined,
                    title: 'Chưa có thiết bị vật lý',
                    message: 'Các thiết bị theo số serial sẽ hiển thị tại đây.',
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                    itemCount:
                        provider.equipments.length +
                        (provider.isLoadingMoreEquipments ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      if (i == provider.equipments.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final eq = provider.equipments[i];
                      final st = eq['status'] as String;
                      final canEdit =
                          provider.isLeadStorekeeper &&
                          st != 'RENTED' &&
                          st != 'RESERVED';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(
                                Icons.qr_code_2_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eq['serialNumber'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${eq['equipmentModelName']} • ${eq['warehouseName']}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _badge(
                                        st,
                                        st == 'AVAILABLE'
                                            ? AppColors.success
                                            : (st == 'DAMAGED'
                                                  ? AppColors.error
                                                  : AppColors.warning),
                                      ),
                                      _badge(
                                        'Tình trạng: ${eq['condition']}',
                                        AppColors.info,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (canEdit)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.primary,
                                ),
                                onPressed: () => EquipmentUnitFormScreen.open(
                                  ctx,
                                  provider,
                                  existingEquipment: eq,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
