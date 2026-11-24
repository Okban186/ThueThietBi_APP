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
import '../widgets/equipment_image_gallery.dart';
import 'equipment_detail_screen.dart';

/// Danh mục thiết bị (chỉ xem) cho nhân viên kinh doanh:
/// giá thuê và số máy còn trống hôm nay của từng model; chạm để xem chi tiết.
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
        onTap: () =>
            EquipmentDetailScreen.open(context, widget.api, _models[index]),
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
              _Thumbnail(image: model.primaryImage),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image});

  final EquipmentModelMedia? image;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(
      Icons.devices_other_rounded,
      color: AppColors.primary,
      size: 30,
    );

    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: image == null
          ? placeholder
          : EquipmentNetworkImage(
              media: image!,
              fit: BoxFit.cover,
              placeholder: placeholder,
            ),
    );
  }
}
