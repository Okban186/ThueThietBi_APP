import 'dart:async';

import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import '../../../data/datasources/equipment_model_api.dart';
import '../../../data/models/equipment_model.dart';

/// Danh mục thiết bị (chỉ xem) cho nhân viên kinh doanh:
/// giá thuê và số máy còn trống hôm nay của từng model.
class EquipmentCatalogScreen extends StatefulWidget {
  const EquipmentCatalogScreen({super.key, required this.api});

  final EquipmentModelApi api;

  static Future<void> open(BuildContext context, EquipmentModelApi api) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EquipmentCatalogScreen(api: api)));
  }

  @override
  State<EquipmentCatalogScreen> createState() => _EquipmentCatalogScreenState();
}

class _EquipmentCatalogScreenState extends State<EquipmentCatalogScreen> {
  Timer? _debounce;
  List<EquipmentModel> _models = [];
  bool _isLoading = true;
  String? _error;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final models = await widget.api.getModels(keyword: _keyword);
      if (mounted) setState(() => _models = models);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được danh mục thiết bị.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String value) {
    _keyword = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thiết bị',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Tìm thiết bị theo tên, mã, hãng...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _models.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: _error,
          action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
        ),
      );
    }

    if (_models.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.devices_other_rounded,
          title: 'Không có thiết bị phù hợp',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _models.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _ModelCard(
        model: _models[index],
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ModelDetailSheet(model: _models[index]),
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.model});

  final EquipmentModel model;

  @override
  Widget build(BuildContext context) {
    final available = model.availableToday ?? 0;
    final total = model.operationalUnits ?? 0;
    final inStock = available > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: inStock ? AppColors.successLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        inStock ? 'Khả dụng $available/$total' : 'Đang thuê hết ($total máy)',
        style: TextStyle(
          color: inStock ? AppColors.success : AppColors.warning,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.onTap});

  final EquipmentModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.devices_other_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.code,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      model.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    if (model.manufacturer != null)
                      Text(
                        model.manufacturer!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _AvailabilityChip(model: model),
                        Text(
                          '${CurrencyFormatter.vnd(model.rentalPriceDaily)}/ngày',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelDetailSheet extends StatelessWidget {
  const _ModelDetailSheet({required this.model});

  final EquipmentModel model;

  @override
  Widget build(BuildContext context) {
    final specs = model.specifications ?? const {};

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            Text(
              model.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              [
                model.code,
                if (model.manufacturer != null) model.manufacturer!,
                if (model.modelNumber != null) model.modelNumber!,
              ].join(' · '),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            _AvailabilityChip(model: model),
            const SizedBox(height: AppSpacing.lg),
            _row(
              'Giá thuê theo ngày',
              CurrencyFormatter.vnd(model.rentalPriceDaily),
            ),
            _row(
              'Giá thuê theo tháng',
              CurrencyFormatter.vnd(model.rentalPriceMonthly),
            ),
            _row(
              'Thời gian lắp đặt',
              '${model.estimatedInstallationMinutes} phút',
            ),
            if (model.description != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(model.description!, style: const TextStyle(height: 1.4)),
            ],
            if (specs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Thông số kỹ thuật',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in specs.entries)
                _row(entry.key, '${entry.value}'),
            ],
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Số khả dụng tính cho hôm nay. Khi lập phiếu, hệ thống kiểm tra lại theo đúng khoảng ngày thuê.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
