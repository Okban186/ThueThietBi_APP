import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

class QuickImportEquipmentSheet extends StatefulWidget {
  const QuickImportEquipmentSheet({
    super.key,
    required this.provider,
    this.preselectedModelId,
  });

  final StorekeeperEquipmentProvider provider;
  final String? preselectedModelId;

  static Future<bool?> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider, {
    String? preselectedModelId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickImportEquipmentSheet(
        provider: provider,
        preselectedModelId: preselectedModelId,
      ),
    );
  }

  @override
  State<QuickImportEquipmentSheet> createState() =>
      _QuickImportEquipmentSheetState();
}

class _QuickImportEquipmentSheetState extends State<QuickImportEquipmentSheet> {
  bool _autoMode = true;
  bool _showBatchExtra = false;
  bool _saving = false;
  bool _loadingPreview = false;

  String? _modelId;
  int _quantity = 1;

  // Preview serial từ Backend
  String? _previewPrefix;
  int? _previewNextSeq;
  int _previewPad = 3;

  // Chế độ nhập mã NSX
  final _manualSerialCtrl = TextEditingController();
  final List<String> _manualSerials = [];

  // Thông tin lô hàng tùy chọn
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _acquiredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _modelId = widget.preselectedModelId;
    if (_modelId != null) {
      _loadSerialPreview(_modelId!);
    }
  }

  @override
  void dispose() {
    _manualSerialCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _selectedModel {
    if (_modelId == null) return null;
    for (final m in widget.provider.models) {
      if (m['id'] == _modelId) return m;
    }
    return null;
  }

  Future<void> _loadSerialPreview(String modelId) async {
    setState(() => _loadingPreview = true);
    try {
      final res = await widget.provider.api.getNextSerialPreview(modelId);
      if (!mounted) return;
      setState(() {
        _previewPrefix = res.prefix;
        _previewNextSeq = res.nextSequence;
        _previewPad = res.padLength;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewPrefix = null;
        _previewNextSeq = null;
      });
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  String _formatSerialPreviewRange() {
    if (_previewPrefix == null || _previewNextSeq == null) return '';
    final start = _previewNextSeq!;
    final end = start + _quantity - 1;
    final pad = end.toString().length > _previewPad
        ? end.toString().length
        : _previewPad;
    final first = '$_previewPrefix${start.toString().padLeft(pad, '0')}';
    if (_quantity == 1) return first;
    final last = '$_previewPrefix${end.toString().padLeft(pad, '0')}';
    return '$first  →  $last';
  }

  Future<void> _pickModelWithSearch() async {
    String query = '';
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = widget.provider.models.where((m) {
            if (query.trim().isEmpty) return true;
            final q = query.trim().toLowerCase();
            return (m['code'] as String? ?? '').toLowerCase().contains(q) ||
                (m['name'] as String? ?? '').toLowerCase().contains(q);
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    children: [
                      const Text(
                        'Chọn Model thiết bị',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModalState(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã hoặc tên model...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy model phù hợp'),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            return ListTile(
                              title: Text(
                                m['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(m['code'] as String),
                              trailing: m['id'] == _modelId
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () =>
                                  Navigator.pop(ctx, m['id'] as String),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (pickedId != null) {
      setState(() => _modelId = pickedId);
      _loadSerialPreview(pickedId);
    }
  }

  void _addManualSerial() {
    final raw = _manualSerialCtrl.text.trim();
    if (raw.isEmpty) return;

    // Hỗ trợ dán nhiều mã cách nhau bởi dấu phẩy, khoảng trắng hoặc xuống dòng
    final parts = raw
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty);

    setState(() {
      for (final sn in parts) {
        if (!_manualSerials.contains(sn)) {
          _manualSerials.add(sn);
        }
      }
      _manualSerialCtrl.clear();
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_modelId == null) {
      _showMsg('Vui lòng chọn Model thiết bị.');
      return;
    }

    if (!_autoMode) {
      // Nếu người dùng gõ mã vào ô nhưng chưa bấm nút "+" thì tự thêm luôn
      if (_manualSerialCtrl.text.trim().isNotEmpty) _addManualSerial();
      if (_manualSerials.isEmpty) {
        _showMsg('Vui lòng nhập ít nhất 1 mã Serial từ NSX.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final cost = double.tryParse(_costCtrl.text.trim());
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      final acquiredAtIso = DateFormatter.isoDate(_acquiredAt);

      if (_autoMode) {
        await widget.provider.api.autoGenerateEquipments({
          'equipmentModelId': _modelId,
          'quantity': _quantity,
          'acquiredAt': acquiredAtIso,
          if (cost != null) 'acquisitionCost': cost,
          if (note != null) 'note': note,
        });
      } else {
        if (widget.provider.warehouses.isEmpty) {
          await widget.provider.loadMetadata();
        }
        if (widget.provider.warehouses.isEmpty) {
          throw Exception('Chưa có kho mặc định trong hệ thống.');
        }

        await widget.provider.api.batchCreateEquipments({
          'equipmentModelId': _modelId,
          'warehouseId': widget.provider.warehouses.first.id,
          'serialNumbers': _manualSerials,
          'condition': 'GOOD',
          'acquiredAt': acquiredAtIso,
          if (cost != null) 'acquisitionCost': cost,
          if (note != null) 'note': note,
        });
      }

      await Future.wait([
        widget.provider.loadEquipments(),
        widget.provider.loadModels(),
      ]);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showMsg(apiErrorMessage(e, fallback: 'Nhập kho thất bại.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _selectedModel;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final submitCount = _autoMode ? _quantity : _manualSerials.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh kéo & tiêu đề
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nhập thiết bị vào kho',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Chọn Model (có tìm kiếm)
            InkWell(
              onTap: _saving ? null : _pickModelWithSearch,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.devices_other_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        model != null
                            ? '${model['code']} • ${model['name']}'
                            : 'Chọn Model thiết bị...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: model != null
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: model != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Chuyển 2 chế độ: Tự cấp mã / Mã từ NSX
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text('Tự động cấp mã'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_note_rounded, size: 18),
                  label: Text('Mã từ NSX'),
                ),
              ],
              selected: {_autoMode},
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() => _autoMode = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.comfortable,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primaryLight;
                  }
                  return AppColors.surface;
                }),
              ),
            ),
            const SizedBox(height: 16),

            // 3A. Chế độ Tự động cấp mã
            if (_autoMode) ...[
              const Text(
                'Số lượng máy nhập kho',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepBtn(
                    icon: Icons.remove_rounded,
                    onTap: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  _stepBtn(
                    icon: Icons.add_rounded,
                    onTap: _quantity < 200
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Chọn nhanh mốc số lượng phổ biến
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in const [1, 5, 10, 20])
                      ChoiceChip(
                        label: Text('+$preset'),
                        selected: _quantity == preset,
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) => setState(() => _quantity = preset),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_modelId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _loadingPreview
                      ? const Text(
                          'Đang lấy số thứ tự tiếp theo...',
                          style: TextStyle(fontSize: 12.5),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hệ thống sẽ tự cấp nối tiếp:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSerialPreviewRange(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                ),
            ]
            // 3B. Chế độ Nhập mã từ NSX (không camera)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualSerialCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _addManualSerial(),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã NSX (VD: 8H9K2P3)...',
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(48, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: _addManualSerial,
                    child: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_manualSerials.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Đã thêm (${_manualSerials.length} máy):',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final sn in _manualSerials)
                      InputChip(
                        label: Text(
                          sn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        backgroundColor: AppColors.primaryLight,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        onDeleted: () =>
                            setState(() => _manualSerials.remove(sn)),
                      ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 12),

            // 4. Thông tin lô hàng (mặc định THU GỌN)
            InkWell(
              onTap: () => setState(() => _showBatchExtra = !_showBatchExtra),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showBatchExtra
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Thông tin lô hàng (Giá nhập, ngày, ghi chú)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showBatchExtra) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Giá nhập / 1 máy',
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _acquiredAt,
                          firstDate: DateTime(2015),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null)
                          setState(() => _acquiredAt = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ngày nhập',
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                          ),
                        ),
                        child: Text(
                          '${_acquiredAt.day.toString().padLeft(2, '0')}/${_acquiredAt.month.toString().padLeft(2, '0')}/${_acquiredAt.year}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Ghi chú lô hàng',
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ],

            const SizedBox(height: 18),

            // 5. Nút Xác nhận
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      submitCount > 0
                          ? 'Xác nhận nhập $submitCount máy'
                          : 'Xác nhận nhập kho',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primaryLight
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
    );
  }
}
