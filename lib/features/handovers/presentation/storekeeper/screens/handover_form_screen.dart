import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/handover_api.dart';
import '../../../data/models/handover_preparation.dart';

/// Lập / sửa phiếu bàn giao: ngày giao, người nhận, chọn máy theo serial cho
/// từng model (không vượt số máy hợp đồng còn thiếu).
class HandoverFormScreen extends StatefulWidget {
  const HandoverFormScreen._({
    required this.api,
    required this.contract,
    this.existing,
  });

  final HandoverApi api;
  final PreparationContractDetail contract;

  /// Phiếu đang sửa (null khi tạo mới).
  final HandoverDetail? existing;

  /// Trả về phiếu vừa tạo (null nếu thoát).
  static Future<HandoverDetail?> create(
    BuildContext context, {
    required HandoverApi api,
    required PreparationContractDetail contract,
  }) => Navigator.of(context).push<HandoverDetail>(
    MaterialPageRoute(
      builder: (_) => HandoverFormScreen._(api: api, contract: contract),
    ),
  );

  static Future<HandoverDetail?> edit(
    BuildContext context, {
    required HandoverApi api,
    required PreparationContractDetail contract,
    required HandoverDetail existing,
  }) => Navigator.of(context).push<HandoverDetail>(
    MaterialPageRoute(
      builder: (_) => HandoverFormScreen._(
        api: api,
        contract: contract,
        existing: existing,
      ),
    ),
  );

  @override
  State<HandoverFormScreen> createState() => _HandoverFormScreenState();
}

class _HandoverFormScreenState extends State<HandoverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _receiverController = TextEditingController();
  late final _phoneController = TextEditingController();
  late final _noteController = TextEditingController();

  late DateTime _date;
  bool _isSaving = false;

  /// Máy đã chọn theo model: modelId → (equipmentId → serial/kho).
  final Map<String, Map<String, _Picked>> _picked = {};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final today = DateUtils.dateOnly(DateTime.now());

    if (existing != null) {
      final h = existing.handover;
      _date = h.handoverDate;
      _receiverController.text = h.receivedByName;
      _phoneController.text = h.receivedByPhone ?? '';
      _noteController.text = h.note ?? '';

      for (final line in existing.items) {
        _picked.putIfAbsent(line.equipmentModelId, () => {})[line.equipmentId] =
            _Picked(line.serialNumber, line.warehouseName);
      }
    } else {
      final start = DateUtils.dateOnly(widget.contract.contract.startDate);
      _date = start.isBefore(today) ? today : start;
      _receiverController.text = widget.contract.representativeName ?? '';
      _phoneController.text = widget.contract.representativePhone ?? '';
    }
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Số máy tối đa được chọn cho model trong phiếu này
  /// (còn thiếu theo hợp đồng + máy của chính phiếu đang sửa).
  int _maxFor(PreparationItem item) {
    final inThisNote =
        widget.existing?.items
            .where((l) => l.equipmentModelId == item.equipmentModelId)
            .length ??
        0;
    return item.remainingQuantity + inThisNote;
  }

  int get _pickedCount => _picked.values.fold(0, (s, m) => s + m.length);

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final end = widget.contract.contract.endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: end.isBefore(today) ? today : end,
      helpText: 'Ngày giao',
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickSerials(PreparationItem item) async {
    final current = _picked[item.equipmentModelId] ?? {};
    final result = await showModalBottomSheet<Map<String, _Picked>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SerialPickerSheet(
        api: widget.api,
        item: item,
        max: _maxFor(item),
        initial: current,
        ownReserved: {
          for (final line in widget.existing?.items ?? const <HandoverLine>[])
            if (line.equipmentModelId == item.equipmentModelId)
              line.equipmentId: _Picked(line.serialNumber, line.warehouseName),
        },
      ),
    );

    if (result != null) {
      setState(() => _picked[item.equipmentModelId] = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedCount == 0) {
      _showError('Hãy chọn ít nhất một máy.');
      return;
    }

    setState(() => _isSaving = true);

    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final input = HandoverInput(
      handoverDate: _date,
      receivedByName: _receiverController.text.trim(),
      receivedByPhone: optional(_phoneController),
      note: optional(_noteController),
      equipmentIds: [for (final m in _picked.values) ...m.keys],
    );

    try {
      final result = _isEditing
          ? await widget.api.update(widget.existing!.handover.id, input)
          : await widget.api.create(widget.contract.contract.contractId, input);

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

  @override
  Widget build(BuildContext context) {
    final c = widget.contract.contract;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Sửa ${widget.existing!.handover.handoverCode}'
              : 'Lập phiếu bàn giao',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${c.contractCode} · ${c.companyName}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Thông tin giao',
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadius,
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ngày giao *',
                        prefixIcon: Icon(Icons.event_outlined),
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(DateFormatter.weekdayDate(_date)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _receiverController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Người nhận *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Vui lòng nhập người nhận.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại người nhận',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      return RegExp(r'^[0-9+ ]{8,20}$').hasMatch(value)
                          ? null
                          : 'Số điện thoại không hợp lệ.';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho đội giao',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Chọn máy ($_pickedCount)',
                children: [
                  for (final item in widget.contract.items)
                    _ModelPickTile(
                      item: item,
                      max: _maxFor(item),
                      picked: _picked[item.equipmentModelId] ?? const {},
                      onPick: () => _pickSerials(item),
                      onRemove: (id) => setState(
                        () => _picked[item.equipmentModelId]?.remove(id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
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
                : const Icon(Icons.save_outlined),
            label: Text(
              _isEditing ? 'Lưu phiếu' : 'Tạo phiếu ($_pickedCount máy)',
            ),
          ),
        ),
      ),
    );
  }
}

class _Picked {
  const _Picked(this.serial, this.warehouse);

  final String serial, warehouse;
}

class _ModelPickTile extends StatelessWidget {
  const _ModelPickTile({
    required this.item,
    required this.max,
    required this.picked,
    required this.onPick,
    required this.onRemove,
  });

  final PreparationItem item;
  final int max;
  final Map<String, _Picked> picked;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.modelName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${item.modelCode} · Đã chọn ${picked.length}/$max',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (max > 0)
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Chọn máy'),
                ),
            ],
          ),
          if (max <= 0 && picked.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Model này đã xếp đủ máy ở các phiếu khác.',
                style: TextStyle(fontSize: 12.5, color: AppColors.success),
              ),
            ),
          if (picked.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in picked.entries)
                  InputChip(
                    label: Text(entry.value.serial),
                    avatar: const Icon(Icons.qr_code_2_rounded, size: 16),
                    onDeleted: () => onRemove(entry.key),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Chọn nhiều serial của một model (tìm theo serial, giới hạn số lượng).
class _SerialPickerSheet extends StatefulWidget {
  const _SerialPickerSheet({
    required this.api,
    required this.item,
    required this.max,
    required this.initial,
    required this.ownReserved,
  });

  final HandoverApi api;
  final PreparationItem item;
  final int max;
  final Map<String, _Picked> initial;

  /// Máy đang giữ cho chính phiếu này (RESERVED, không có trong danh sách kho).
  final Map<String, _Picked> ownReserved;

  @override
  State<_SerialPickerSheet> createState() => _SerialPickerSheetState();
}

class _SerialPickerSheetState extends State<_SerialPickerSheet> {
  late final Map<String, _Picked> _selected = Map.of(widget.initial);
  List<StockEquipment> _stock = [];
  bool _isLoading = true;
  String? _error;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stock = await widget.api.getAvailableEquipments(
        widget.item.equipmentModelId,
      );
      if (mounted) setState(() => _stock = stock);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được máy trong kho.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggle(String id, _Picked value) {
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else if (_selected.length < widget.max) {
        _selected[id] = value;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chỉ cần tối đa ${widget.max} máy cho model này.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Chọn nhanh đủ số máy còn thiếu theo thứ tự danh sách.
  void _autoFill() {
    setState(() {
      for (final e in _visible) {
        if (_selected.length >= widget.max) break;
        _selected.putIfAbsent(
          e.id,
          () => _Picked(e.serialNumber, e.warehouseName),
        );
      }
    });
  }

  List<StockEquipment> get _visible {
    final keyword = _keyword.trim().toLowerCase();

    // Máy đã chọn sẵn trong phiếu (đang RESERVED) không nằm trong danh sách kho.
    final own = [
      for (final e in {...widget.ownReserved, ...widget.initial}.entries)
        if (!_stock.any((s) => s.id == e.key))
          StockEquipment(
            id: e.key,
            serialNumber: e.value.serial,
            equipmentModelId: widget.item.equipmentModelId,
            warehouseName: e.value.warehouse,
            condition: '',
          ),
    ];

    return [...own, ..._stock]
        .where(
          (e) =>
              keyword.isEmpty || e.serialNumber.toLowerCase().contains(keyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.modelName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Đã chọn ${_selected.length}/${widget.max} máy',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.length >= widget.max
                        ? null
                        : _autoFill,
                    child: const Text('Chọn đủ'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                onChanged: (v) => setState(() => _keyword = v),
                decoration: const InputDecoration(
                  hintText: 'Tìm theo serial...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(child: _buildList(visible)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text('Xong (${_selected.length} máy)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<StockEquipment> visible) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }

    if (visible.isEmpty) {
      return const Center(
        child: Text(
          'Không còn máy sẵn sàng trong kho.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final e = visible[index];
        final selected = _selected.containsKey(e.id);

        return CheckboxListTile(
          value: selected,
          onChanged: (_) =>
              _toggle(e.id, _Picked(e.serialNumber, e.warehouseName)),
          title: Text(
            e.serialNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              e.warehouseName,
              if (e.condition.isNotEmpty)
                'Tình trạng ${_conditionLabel(e.condition)}',
            ].join(' · '),
          ),
          secondary: const Icon(Icons.qr_code_2_rounded),
        );
      },
    );
  }

  static String _conditionLabel(String condition) => switch (condition) {
    'GOOD' => 'tốt',
    'FAIR' => 'khá',
    _ => condition,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
