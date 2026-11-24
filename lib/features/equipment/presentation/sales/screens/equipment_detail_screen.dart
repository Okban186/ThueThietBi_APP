import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import '../../../data/datasources/equipment_model_api.dart';
import '../../../data/models/equipment_model.dart';
import '../widgets/equipment_image_gallery.dart';
import '../widgets/equipment_specs_card.dart';

/// Chi tiết model thiết bị cho Sales (chỉ xem): ảnh, giá thuê, số máy, thông số.
/// Không có thao tác sửa model, ảnh hay nhập máy (thuộc thủ kho).
class EquipmentDetailScreen extends StatefulWidget {
  const EquipmentDetailScreen({
    super.key,
    required this.api,
    required this.initial,
  });

  final EquipmentModelApi api;

  /// Dữ liệu từ danh sách, hiển thị ngay trong lúc tải bản mới.
  final EquipmentModel initial;

  static Future<void> open(
    BuildContext context,
    EquipmentModelApi api,
    EquipmentModel model,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EquipmentDetailScreen(api: api, initial: model),
      ),
    );
  }

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  late EquipmentModel _model = widget.initial;

  @override
  void initState() {
    super.initState();
    // Link ảnh có hạn dùng nên luôn tải lại khi mở.
    _load();
  }

  Future<void> _load() async {
    try {
      final model = await widget.api.getModel(widget.initial.id);
      if (mounted) setState(() => _model = model);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              error,
              fallback: 'Không tải được chi tiết thiết bị.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          model.code,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            EquipmentImageGallery(images: model.images),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _SummaryCard(model: model),
                  const SizedBox(height: AppSpacing.lg),
                  EquipmentSpecsCard(specifications: model.specifications),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.model});

  final EquipmentModel model;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      model.manufacturer ?? 'Chưa rõ hãng',
      'Model: ${model.modelNumber ?? '-'}',
      'ĐVT: ${model.unit}',
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (model.categoryNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in model.categoryNames)
                  Chip(
                    label: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primaryLight,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Giá thuê / ngày',
                  value: CurrencyFormatter.vnd(model.rentalPriceDaily),
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Giá thuê / tháng',
                  value: CurrencyFormatter.vnd(model.rentalPriceMonthly),
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Tổng máy',
                  value: '${model.totalUnits ?? '-'}',
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Hoạt động',
                  value: '${model.operationalUnits ?? '-'}',
                  color: AppColors.info,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Khả dụng hôm nay',
                  value: '${model.availableToday ?? '-'}',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (model.description?.isNotEmpty == true) ...[
            const Divider(height: 24),
            Text(
              model.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Thuê từ 3 đến 10 ngày tính theo giá ngày; trên 10 ngày tính theo giá tháng '
            '(làm tròn lên theo tháng). Số khả dụng tính cho hôm nay, khi lập phiếu '
            'hệ thống kiểm tra lại theo khoảng ngày thuê.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
