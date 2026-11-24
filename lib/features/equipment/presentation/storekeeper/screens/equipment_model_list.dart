import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_model_detail_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_unit_form_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/widgets/quick_import_equipment_sheet.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import 'equipment_model_form_screen.dart';

class EquipmentModelListScreen extends StatefulWidget {
  const EquipmentModelListScreen({super.key});

  @override
  State<EquipmentModelListScreen> createState() =>
      _EquipmentModelListScreenState();
}

class _EquipmentModelListScreenState extends State<EquipmentModelListScreen> {
  String _keyword = '';
  String? _selectedCategoryId;
  String? _statusFilter;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorekeeperEquipmentProvider>();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) {
                  _keyword = v;
                  provider.loadModels(
                    keyword: _keyword,
                    categoryId: _selectedCategoryId,
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã, tên model hoặc hãng...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (val, label) in const [
                      (null, 'Tất cả trạng thái'),
                      ('ACTIVE', 'Đang hoạt động'),
                      ('INACTIVE', 'Ngừng hoạt động'),
                    ]) ...[
                      AppFilterChip(
                        label: label,
                        selected: _statusFilter == val,
                        onTap: () {
                          setState(() => _statusFilter = val);
                          provider.loadModels(
                            keyword: _keyword,
                            categoryId: _selectedCategoryId,
                            status: val,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.loadModels(
              keyword: _keyword,
              categoryId: _selectedCategoryId,
            ),
            child: provider.isLoadingModels
                ? const Center(child: CircularProgressIndicator())
                : provider.models.isEmpty
                ? const AppEmptyView(
                    icon: Icons.category_outlined,
                    title: 'Chưa có model thiết bị',
                    message: 'Thử thay đổi bộ lọc hoặc tạo model mới.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                    itemCount: provider.models.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final m = provider.models[i];
                      final media = (m['media'] as List<dynamic>? ?? const []);
                      final imgUrl = media.isNotEmpty
                          ? media.first['url'] as String?
                          : null;
                      final isActive = m['status'] == 'ACTIVE';
                      final available =
                          (m['availableToday'] as num?)?.toInt() ?? 0;
                      final total = (m['totalUnits'] as num?)?.toInt() ?? 0;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => EquipmentModelDetailScreen.open(
                          ctx,
                          provider,
                          m['id'] as String,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.surfaceSecondary,
                                  child: imgUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.devices_other_rounded,
                                          color: AppColors.primary,
                                          size: 32,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['code'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      m['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${CurrencyFormatter.vnd((m['rentalPriceDaily'] as num).toDouble())}/ngày • Sẵn: $available/$total',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.successLight
                                            : AppColors.warningLight,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        isActive
                                            ? 'Đang hoạt động'
                                            : 'Ngừng hoạt động',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? AppColors.success
                                              : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // CHỈ LEAD_STOREKEEPER mới có menu sửa / nhập máy cho model này
                              if (provider.isLeadStorekeeper)
                                PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      await EquipmentModelFormScreen.open(
                                        ctx,
                                        provider,
                                        existingModel: m,
                                      );
                                    } else if (action == 'add_unit') {
                                      await QuickImportEquipmentSheet.open(
                                        ctx,
                                        provider,
                                        preselectedModelId: m['id'] as String,
                                      );
                                    } else if (action == 'toggle') {
                                      await provider.api.updateModelStatus(
                                        m['id'] as String,
                                        isActive ? 'INACTIVE' : 'ACTIVE',
                                      );
                                      await provider.loadModels(
                                        keyword: _keyword,
                                        categoryId: _selectedCategoryId,
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Chỉnh sửa model'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'add_unit',
                                      child: Text('Nhập thiết bị (Serial)'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        isActive
                                            ? 'Ngừng hoạt động'
                                            : 'Kích hoạt lại',
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
