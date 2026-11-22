import 'dart:async';

import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';
import 'package:thuethietbi_app/features/equipment/data/models/equipment_availability.dart';
import 'package:thuethietbi_app/features/equipment/data/models/equipment_model.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../widgets/quantity_stepper.dart';

/// Model được chọn để thêm vào phiếu.
class PickedEquipmentModel {
  const PickedEquipmentModel({
    required this.model,
    required this.quantity,
    required this.availableQuantity,
  });

  final EquipmentModel model;
  final int quantity;
  final int availableQuantity;
}

/// Chọn model thiết bị và số lượng cho phiếu giữ chỗ,
/// hiển thị số máy còn trống trong đúng khoảng ngày của phiếu.
class EquipmentModelPickerScreen extends StatefulWidget {
  const EquipmentModelPickerScreen({
    super.key,
    required this.api,
    required this.from,
    required this.to,
    required this.reservationId,
    required this.existingModelIds,
  });

  final EquipmentModelApi api;
  final DateTime from, to;

  /// Phiếu đang sửa: bỏ qua số lượng của chính phiếu khi tính khả dụng.
  final String reservationId;

  /// Model đã có trong phiếu (chỉnh số lượng tại danh sách, không thêm trùng).
  final Set<String> existingModelIds;

  static Future<PickedEquipmentModel?> open(
    BuildContext context, {
    required EquipmentModelApi api,
    required DateTime from,
    required DateTime to,
    required String reservationId,
    required Set<String> existingModelIds,
  }) {
    return Navigator.of(context).push<PickedEquipmentModel>(
      MaterialPageRoute(
        builder: (_) => EquipmentModelPickerScreen(
          api: api,
          from: from,
          to: to,
          reservationId: reservationId,
          existingModelIds: existingModelIds,
        ),
      ),
    );
  }

  @override
  State<EquipmentModelPickerScreen> createState() =>
      _EquipmentModelPickerScreenState();
}

class _EquipmentModelPickerScreenState
    extends State<EquipmentModelPickerScreen> {
  Timer? _debounce;
  List<EquipmentModel> _models = [];
  Map<String, EquipmentAvailability> _availability = {};
  bool _isLoading = true;
  String? _error;

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

  Future<void> _load({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final models = await widget.api.getModels(keyword: keyword);
      final availability = await widget.api.checkAvailability(
        equipmentModelIds: models.map((m) => m.id).toList(),
        from: widget.from,
        to: widget.to,
        excludeReservationId: widget.reservationId,
      );

      if (!mounted) return;

      setState(() {
        _models = models;
        _availability = availability;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được danh sách model.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(keyword: value),
    );
  }

  Future<void> _select(EquipmentModel model) async {
    if (widget.existingModelIds.contains(model.id)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Model đã có trong phiếu. Hãy chỉnh số lượng tại danh sách.',
            ),
          ),
        );
      return;
    }

    final available = _availability[model.id]?.availableQuantity ?? 0;

    if (available <= 0) return;

    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(model: model, maxQuantity: available),
    );

    if (quantity != null && mounted) {
      Navigator.of(context).pop(
        PickedEquipmentModel(
          model: model,
          quantity: quantity,
          availableQuantity: available,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chọn model thiết bị',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên, mã hoặc hãng...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Số máy còn trống trong ${DateFormatter.dateRange(widget.from, widget.to)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _models.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    if (_models.isEmpty) {
      return const AppEmptyView(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy model phù hợp',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _models.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final model = _models[index];

        return _ModelCard(
          model: model,
          availability: _availability[model.id],
          alreadyAdded: widget.existingModelIds.contains(model.id),
          onTap: () => _select(model),
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.availability,
    required this.alreadyAdded,
    required this.onTap,
  });

  final EquipmentModel model;
  final EquipmentAvailability? availability;
  final bool alreadyAdded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = availability?.availableQuantity ?? 0;
    final total = availability?.operationalUnits ?? model.operationalUnits ?? 0;
    final canPick = !alreadyAdded && available > 0;

    return Opacity(
      opacity: canPick ? 1 : 0.6,
      child: Material(
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.devices_other_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          model.code,
                          if (model.manufacturer != null) model.manufacturer!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      alreadyAdded ? 'Đã thêm' : '$available/$total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: alreadyAdded
                            ? AppColors.textSecondary
                            : available > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    Text(
                      alreadyAdded ? 'trong phiếu' : 'còn trống',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.model, required this.maxQuantity});

  final EquipmentModel model;
  final int maxQuantity;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.model.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Còn trống tối đa ${widget.maxQuantity} máy trong khoảng ngày của phiếu.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          QuantityStepper(
            value: _quantity,
            max: widget.maxQuantity,
            onChanged: (value) => setState(() => _quantity = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _quantity),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}
