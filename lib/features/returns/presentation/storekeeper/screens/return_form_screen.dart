import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';

import '../../../data/datasources/return_api.dart';
import '../../../data/models/return_receipt.dart';

/// Lập phiếu nhận trả: chọn các máy kỹ thuật viên đã thu hồi về kho,
/// kiểm từng máy (Tốt / Khá / Hỏng / Thất lạc).
class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen._({required this.api, required this.detail});

  final ReturnApi api;
  final ReturnContractDetail detail;

  /// Trả về phiếu vừa lập (null nếu thoát).
  static Future<ReturnReceiptDetail?> open(
    BuildContext context, {
    required ReturnApi api,
    required ReturnContractDetail detail,
  }) => Navigator.of(context).push<ReturnReceiptDetail>(
    MaterialPageRoute(
      builder: (_) => ReturnFormScreen._(api: api, detail: detail),
    ),
  );

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final _noteController = TextEditingController();

  /// Máy được đưa vào phiếu này → kết quả kiểm.
  final Map<String, ReturnCheck> _checks = {};
  bool _isSaving = false;

  List<OutstandingEquipment> get _outstanding => widget.detail.outstanding;

  @override
  void initState() {
    super.initState();
    // Mặc định: nhận đủ máy, tình trạng như lúc giao.
    for (final e in _outstanding) {
      _checks[e.equipmentId] = e.condition == 'FAIR'
          ? ReturnCheck.fair
          : ReturnCheck.good;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int _count(ReturnCheck check) =>
      _checks.values.where((c) => c == check).length;

  Future<void> _save() async {
    if (_checks.isEmpty) {
      _showError('Hãy chọn ít nhất một máy đã về kho.');
      return;
    }

    final damaged = _count(ReturnCheck.damaged);
    final missing = _count(ReturnCheck.missing);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận nhận trả?'),
        content: Text(
          [
            'Nhận ${_checks.length - missing} máy về kho'
                '${damaged > 0 ? ' ($damaged máy hỏng, chờ sửa)' : ''}.',
            if (missing > 0) '$missing máy ghi nhận thất lạc.',
            'Phiếu lập xong không sửa được.',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kiểm lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _isSaving = true);

    try {
      final note = _noteController.text.trim();
      final result = await widget.api.create(
        widget.detail.contract.contractId,
        [
          for (final entry in _checks.entries)
            ReturnCheckInput(equipmentId: entry.key, check: entry.value),
        ],
        note: note.isEmpty ? null : note,
      );

      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) _showError(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        for (final e in _outstanding) {
          _checks.putIfAbsent(e.equipmentId, () => ReturnCheck.good);
        }
      } else {
        _checks.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _checks.length == _outstanding.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lập phiếu nhận trả',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              '${widget.detail.contract.contractCode} · ${widget.detail.contract.companyName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đã chọn ${_checks.length}/${_outstanding.length} máy',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleAll(!allSelected),
                  child: Text(allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                ),
              ],
            ),
            for (final e in _outstanding)
              _CheckTile(
                equipment: e,
                check: _checks[e.equipmentId],
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _checks[e.equipmentId] = ReturnCheck.good;
                  } else {
                    _checks.remove(e.equipmentId);
                  }
                }),
                onCheck: (check) =>
                    setState(() => _checks[e.equipmentId] = check),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (người thu hồi, tình trạng chung...)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.move_to_inbox_rounded),
            label: Text('Nhận trả (${_checks.length} máy)'),
          ),
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.equipment,
    required this.check,
    required this.onSelected,
    required this.onCheck,
  });

  final OutstandingEquipment equipment;

  /// null = máy chưa về, không đưa vào phiếu này.
  final ReturnCheck? check;
  final ValueChanged<bool> onSelected;
  final ValueChanged<ReturnCheck> onCheck;

  @override
  Widget build(BuildContext context) {
    final selected = check != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onSelected(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.serialNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${equipment.modelName} · ${equipment.handoverCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final option in ReturnCheck.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: check == option,
                      onSelected: (_) => onCheck(option),
                      selectedColor: _color(option).withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: check == option
                            ? _color(option)
                            : AppColors.textPrimary,
                        fontWeight: check == option
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Color _color(ReturnCheck check) => switch (check) {
    ReturnCheck.good => AppColors.success,
    ReturnCheck.fair => AppColors.info,
    ReturnCheck.damaged => AppColors.warning,
    ReturnCheck.missing => AppColors.error,
  };
}
