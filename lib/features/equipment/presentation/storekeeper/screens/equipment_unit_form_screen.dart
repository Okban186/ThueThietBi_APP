import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

class EquipmentUnitFormScreen extends StatefulWidget {
  const EquipmentUnitFormScreen({
    super.key,
    required this.provider,
    this.preselectedModelId,
    this.existingEquipment,
  });

  final StorekeeperEquipmentProvider provider;
  final String? preselectedModelId;
  final Map<String, dynamic>? existingEquipment;

  static Future<bool?> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider, {
    String? preselectedModelId,
    Map<String, dynamic>? existingEquipment,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EquipmentUnitFormScreen(
          provider: provider,
          preselectedModelId: preselectedModelId,
          existingEquipment: existingEquipment,
        ),
      ),
    );
  }

  @override
  State<EquipmentUnitFormScreen> createState() =>
      _EquipmentUnitFormScreenState();
}

class _EquipmentUnitFormScreenState extends State<EquipmentUnitFormScreen> {
  final _serialsCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _startNumCtrl = TextEditingController(text: '1');
  final _qtyCtrl = TextEditingController(text: '5');
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String? _modelId;
  String? _defaultWarehouseId;
  String _condition = 'GOOD';
  String _status = 'AVAILABLE';
  bool _saving = false;

  bool get _isEdit => widget.existingEquipment != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEquipment;
    _modelId = e?['equipmentModelId'] as String? ?? widget.preselectedModelId;
    _defaultWarehouseId =
        e?['warehouseId'] as String? ??
        (widget.provider.warehouses.isNotEmpty
            ? widget.provider.warehouses.first.id
            : null);
    _condition = e?['condition'] as String? ?? 'GOOD';
    _status = e?['status'] as String? ?? 'AVAILABLE';
    _serialsCtrl.text = e?['serialNumber'] as String? ?? '';
    _costCtrl.text = e?['acquisitionCost'] != null
        ? '${e!['acquisitionCost']}'
        : '';
    _noteCtrl.text = e?['note'] as String? ?? '';

    if (_defaultWarehouseId == null) {
      _ensureDefaultWarehouse();
    }
  }

  Future<void> _ensureDefaultWarehouse() async {
    await widget.provider.loadMetadata();
    if (mounted && widget.provider.warehouses.isNotEmpty) {
      setState(() => _defaultWarehouseId = widget.provider.warehouses.first.id);
    }
  }

  @override
  void dispose() {
    _serialsCtrl.dispose();
    _prefixCtrl.dispose();
    _startNumCtrl.dispose();
    _qtyCtrl.dispose();
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

  /// Mở BottomSheet tìm kiếm & chọn Model thiết bị
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
            final code = (m['code'] as String? ?? '').toLowerCase();
            final name = (m['name'] as String? ?? '').toLowerCase();
            return code.contains(q) || name.contains(q);
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
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
                          hintText: 'Nhập mã hoặc tên model để tìm...',
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
                            final selected = m['id'] == _modelId;
                            return ListTile(
                              title: Text(
                                m['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(m['code'] as String),
                              trailing: selected
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
      setState(() {
        _modelId = pickedId;
        // Gợi ý sẵn tiền tố Serial cha theo mã Model nếu đang trống
        if (_prefixCtrl.text.trim().isEmpty && _selectedModel != null) {
          _prefixCtrl.text = '${_selectedModel!['code']}-';
        }
      });
    }
  }

  /// Sinh hàng loạt Serial con từ Serial cha + số bắt đầu + số lượng
  void _generateSerials() {
    final prefix = _prefixCtrl.text.trim().toUpperCase();
    final start = int.tryParse(_startNumCtrl.text.trim()) ?? 1;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (prefix.isEmpty || qty <= 0) {
      _showMsg('Vui lòng nhập Tiền tố Serial và Số lượng > 0.');
      return;
    }
    if (qty > 200) {
      _showMsg('Mỗi lần sinh tối đa 200 serial.');
      return;
    }

    final padLength = (start + qty - 1).toString().length.clamp(3, 6);
    final generated = List.generate(
      qty,
      (i) => '$prefix${(start + i).toString().padLeft(padLength, '0')}',
    );

    setState(() {
      _serialsCtrl.text = generated.join('\n');
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
    if (_defaultWarehouseId == null) {
      _showMsg(
        'Hệ thống chưa có kho mặc định. Vui lòng kiểm tra bảng warehouses.',
      );
      return;
    }

    final serials = _serialsCtrl.text
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (!_isEdit && serials.isEmpty) {
      _showMsg('Vui lòng nhập hoặc sinh ít nhất 1 số Serial.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.provider.api.updateEquipment(
          widget.existingEquipment!['id'] as String,
          {
            'warehouseId': _defaultWarehouseId,
            'status': _status,
            'condition': _condition,
            'acquisitionCost': double.tryParse(_costCtrl.text.trim()),
            'note': _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
          },
        );
      } else {
        await widget.provider.api.batchCreateEquipments({
          'equipmentModelId': _modelId,
          'warehouseId': _defaultWarehouseId,
          'serialNumbers': serials,
          'condition': 'GOOD', // Nhập mới luôn là GOOD
          'acquisitionCost': double.tryParse(_costCtrl.text.trim()),
          'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        });
      }

      await Future.wait([
        widget.provider.loadEquipments(),
        widget.provider.loadModels(),
      ]);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showMsg(apiErrorMessage(e, fallback: 'Không thể lưu thiết bị.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _selectedModel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Cập nhật thiết bị' : 'Nhập thiết bị vào kho'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Ô chọn Model có tìm kiếm
          InkWell(
            onTap: _isEdit ? null : _pickModelWithSearch,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Model thiết bị *',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _isEdit ? null : const Icon(Icons.search_rounded),
              ),
              child: Text(
                model != null
                    ? '${model['code']} - ${model['name']}'
                    : 'Chạm để tìm và chọn model thiết bị...',
                style: TextStyle(
                  color: model != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: model != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Bộ sinh Serial nhanh từ Serial cha (chỉ hiện khi nhập mới)
          if (!_isEdit) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sinh hàng loạt Serial từ mã cha',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _prefixCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Serial cha (Tiền tố)',
                      hintText: 'VD: TB-RICOH-2026-',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startNumCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Từ số',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số lượng',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _generateSerials,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: const Text('Sinh mã'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Danh sách Serial (vẫn sửa tay được sau khi sinh)
          TextField(
            controller: _serialsCtrl,
            enabled: !_isEdit,
            minLines: _isEdit ? 1 : 4,
            maxLines: _isEdit ? 1 : 8,
            decoration: InputDecoration(
              labelText: _isEdit
                  ? 'Số Serial'
                  : 'Danh sách số Serial * (mỗi dòng 1 mã)',
              hintText: 'TB-RICOH-2026-001\nTB-RICOH-2026-002',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // 4. Chỉ hiện Tình trạng & Trạng thái khi CHỈNH SỬA (nhập mới mặc định GOOD)
          if (_isEdit) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: const InputDecoration(
                labelText: 'Tình trạng vật lý',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'GOOD', child: Text('Tốt (GOOD)')),
                DropdownMenuItem(value: 'FAIR', child: Text('Khá (FAIR)')),
                DropdownMenuItem(
                  value: 'DAMAGED',
                  child: Text('Hư hỏng (DAMAGED)'),
                ),
              ],
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Trạng thái kho',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'AVAILABLE',
                  child: Text('Khả dụng (AVAILABLE)'),
                ),
                DropdownMenuItem(
                  value: 'MAINTENANCE',
                  child: Text('Bảo trì (MAINTENANCE)'),
                ),
                DropdownMenuItem(
                  value: 'DAMAGED',
                  child: Text('Hỏng (DAMAGED)'),
                ),
                DropdownMenuItem(value: 'LOST', child: Text('Thất lạc (LOST)')),
                DropdownMenuItem(
                  value: 'DISPOSED',
                  child: Text('Thanh lý (DISPOSED)'),
                ),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],

          const SizedBox(height: 12),
          TextField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Giá nhập / 1 máy (VNĐ) — áp dụng chung cả lô',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                    _isEdit ? 'Lưu thay đổi' : 'Nhập kho',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
