import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/data/models/pending_model_image.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/widgets/model_excel_import_sheet.dart';

class EquipmentModelFormScreen extends StatefulWidget {
  const EquipmentModelFormScreen({
    super.key,
    required this.provider,
    this.existingModel,
  });

  final StorekeeperEquipmentProvider provider;
  final Map<String, dynamic>? existingModel;

  static Future<bool?> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider, {
    Map<String, dynamic>? existingModel,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EquipmentModelFormScreen(
          provider: provider,
          existingModel: existingModel,
        ),
      ),
    );
  }

  @override
  State<EquipmentModelFormScreen> createState() =>
      _EquipmentModelFormScreenState();
}

class _EquipmentModelFormScreenState extends State<EquipmentModelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mfgCtrl;
  late final TextEditingController _modelNumCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _dailyCtrl;
  late final TextEditingController _monthlyCtrl;
  late final TextEditingController _installMinCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _specsCtrl;
  final List<dynamic> _existingMedia = [];

  final Set<String> _selectedCategoryIds = {};
  final List<PendingModelImage> _pendingImages = [];

  String? _savedModelId;
  bool _saving = false;
  bool _codeManuallyEdited = false;
  late int _randomSuffix;

  bool get _isEdit => widget.existingModel != null;
  bool get _hasFailedImages =>
      _pendingImages.any((e) => e.status == PendingImageStatus.failed);

  @override
  void initState() {
    super.initState();
    _randomSuffix = 100 + Random().nextInt(900);

    if (widget.provider.categories.isEmpty) {
      widget.provider.loadMetadata().then((_) {
        if (mounted) setState(() {});
      });
    }
    final m = widget.existingModel;
    _savedModelId = m?['id'] as String?;

    _codeCtrl = TextEditingController(text: m?['code'] as String? ?? '');
    _nameCtrl = TextEditingController(text: m?['name'] as String? ?? '');
    _mfgCtrl = TextEditingController(text: m?['manufacturer'] as String? ?? '');
    _modelNumCtrl = TextEditingController(
      text: m?['modelNumber'] as String? ?? '',
    );
    _unitCtrl = TextEditingController(text: m?['unit'] as String? ?? 'UNIT');
    _dailyCtrl = TextEditingController(
      text: m != null ? '${m['rentalPriceDaily']}' : '',
    );
    _monthlyCtrl = TextEditingController(
      text: m != null ? '${m['rentalPriceMonthly']}' : '',
    );
    _installMinCtrl = TextEditingController(
      text: '${m?['estimatedInstallationMinutes'] ?? 0}',
    );
    _descCtrl = TextEditingController(text: m?['description'] as String? ?? '');

    _specsCtrl = TextEditingController(
      text: m?['specifications'] != null
          ? const JsonEncoder.withIndent('  ').convert(m!['specifications'])
          : '',
    );

    _existingMedia.addAll(
      (m?['media'] as List<dynamic>? ?? const []).cast<dynamic>(),
    );

    for (final c in (m?['categories'] as List<dynamic>? ?? const [])) {
      _selectedCategoryIds.add(c['id'] as String);
    }

    if (!_isEdit) {
      _mfgCtrl.addListener(_autoSyncCode);
      _modelNumCtrl.addListener(_autoSyncCode);
      _nameCtrl.addListener(_autoSyncCode);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _mfgCtrl.dispose();
    _modelNumCtrl.dispose();
    _unitCtrl.dispose();
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    _installMinCtrl.dispose();
    _descCtrl.dispose();
    _specsCtrl.dispose();
    super.dispose();
  }

  static String _sanitizeToken(String input) {
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    var s = input.trim();
    for (var i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  void _autoSyncCode({bool force = false}) {
    if (_isEdit || (_codeManuallyEdited && !force)) return;

    final mfg = _sanitizeToken(_mfgCtrl.text);
    final mod = _sanitizeToken(_modelNumCtrl.text);
    final fallback = _sanitizeToken(_nameCtrl.text);

    final parts = <String>[
      if (mfg.isNotEmpty) mfg.length > 10 ? mfg.substring(0, 10) : mfg,
      if (mod.isNotEmpty) mod.length > 12 ? mod.substring(0, 12) : mod,
    ];
    if (parts.isEmpty && fallback.isNotEmpty) {
      parts.add(fallback.length > 12 ? fallback.substring(0, 12) : fallback);
    }

    if (parts.isEmpty) {
      if (force) {
        _codeCtrl.text = 'MODEL-$_randomSuffix';
      }
      return;
    }

    _codeCtrl.text = '${parts.join('-')}-$_randomSuffix';
  }

  void _regenerateCode() {
    setState(() {
      _randomSuffix = 100 + Random().nextInt(900);
      _codeManuallyEdited = false;
      _autoSyncCode(force: true);
    });
  }

  /// Parse JSON thông số kỹ thuật linh hoạt:
  /// - Cho phép key bỏ trống value kiểu {"ram": "16GB", "weight": , "power": } → tự chuyển thành ""
  /// - Cho phép value là null → tự chuyển thành ""
  /// - Tự loại bỏ dấu phẩy thừa trước dấu } cuối cùng (trailing comma)
  dynamic _parseFlexibleSpecsJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var sanitized = trimmed.replaceAll(RegExp(r':\s*(?=[,}\r\n])'), ': ""');
    sanitized = sanitized.replaceAll(RegExp(r',\s*}'), '}');

    final decoded = jsonDecode(sanitized);
    if (decoded is Map<String, dynamic>) {
      final normalized = <String, dynamic>{};
      for (final entry in decoded.entries) {
        final k = entry.key.trim();
        if (k.isEmpty) continue;
        normalized[k] = entry.value ?? '';
      }
      return normalized.isEmpty ? null : normalized;
    }
    return decoded;
  }

  void _finishAndExit() {
    Navigator.pop(context, _savedModelId != null);
  }

  Future<void> _pickMultipleImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    setState(() {
      for (final f in files) {
        _pendingImages.add(
          PendingModelImage(filePath: f.path, fileName: f.name),
        );
      }
    });
  }

  Future<void> _deleteExistingMedia(Map<String, dynamic> media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ảnh cũ'),
        content: const Text('Bạn có chắc muốn xóa ảnh này khỏi model?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || _savedModelId == null) return;

    try {
      await widget.provider.api.deleteMedia(
        _savedModelId!,
        media['id'] as String,
      );
      setState(() => _existingMedia.removeWhere((e) => e['id'] == media['id']));
      await widget.provider.loadModels();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: 'Không thể xóa ảnh.')),
        ),
      );
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'code': _codeCtrl.text.trim().toUpperCase(),
      'name': _nameCtrl.text.trim(),
      'manufacturer': _mfgCtrl.text.trim().isEmpty
          ? null
          : _mfgCtrl.text.trim(),
      'modelNumber': _modelNumCtrl.text.trim().isEmpty
          ? null
          : _modelNumCtrl.text.trim(),
      'unit': _unitCtrl.text.trim(),
      'rentalPriceDaily': double.parse(_dailyCtrl.text.trim()),
      'rentalPriceMonthly': double.parse(_monthlyCtrl.text.trim()),
      'estimatedInstallationMinutes':
          int.tryParse(_installMinCtrl.text.trim()) ?? 0,
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'specifications': _parseFlexibleSpecsJson(_specsCtrl.text),
      'categoryIds': _selectedCategoryIds.toList(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final payload = _buildPayload();
      if (_savedModelId == null) {
        final created = await widget.provider.api.createModel(
          payload,
        ) as Map<String, dynamic>;
        _savedModelId = created['id'] as String;
      } else if (!_hasFailedImages) {
        await widget.provider.api.updateModel(_savedModelId!, payload);
      }

      final allImagesOk = await widget.provider.api.uploadAndConfirmModelImages(
        modelId: _savedModelId!,
        items: _pendingImages,
      );

      await widget.provider.loadModels();

      if (!mounted) return;

      if (allImagesOk) {
        Navigator.pop(context, true);
      } else {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: 'Không thể lưu model thiết bị.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildExistingMediaSection() {
    if (_existingMedia.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ảnh hiện có (${_existingMedia.length})',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _existingMedia.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final media = _existingMedia[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      media['url'] as String,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: AppColors.surfaceSecondary,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteExistingMedia(media),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _pickCategoriesWithSearch() async {
    final selectable = widget.provider.categories
        .where(
          (c) => c.status == 'ACTIVE' || _selectedCategoryIds.contains(c.id),
        )
        .toList();

    final tempSelected = Set<String>.from(_selectedCategoryIds);
    String query = '';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = selectable.where((c) {
            if (query.trim().isEmpty) return true;
            final q = query.trim().toLowerCase();
            return c.code.toLowerCase().contains(q) ||
                c.name.toLowerCase().contains(q);
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chọn danh mục (${tempSelected.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Xong'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModalState(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã hoặc tên danh mục...',
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
                          child: Text('Không tìm thấy danh mục phù hợp'),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            final checked = tempSelected.contains(c.id);
                            return CheckboxListTile(
                              value: checked,
                              activeColor: AppColors.primary,
                              title: Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(c.code),
                              onChanged: (v) => setModalState(() {
                                if (v == true) {
                                  tempSelected.add(c.id);
                                } else {
                                  tempSelected.remove(c.id);
                                }
                              }),
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

    if (confirmed == true) {
      setState(() {
        _selectedCategoryIds
          ..clear()
          ..addAll(tempSelected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _finishAndExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit ? 'Cập nhật Model thiết bị' : 'Tạo Model thiết bị',
          ),
          actions: [
            if (!_isEdit)
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final ok = await ModelExcelImportSheet.open(
                          context,
                          widget.provider,
                        );
                        if (ok == true && mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: const Text('Import Excel'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                _nameCtrl,
                'Tên Model thiết bị *',
                hint: 'VD: Máy quay Sony FX3 Cinema Line',
                required: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _mfgCtrl,
                      'Hãng sản xuất *',
                      hint: 'VD: Sony',
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _modelNumCtrl,
                      'Số hiệu Model *',
                      hint: 'VD: FX3',
                      required: true,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _codeCtrl,
                  onChanged: (_) => _codeManuallyEdited = true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Mã Model không được để trống'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Mã Model * (Tự sinh & có thể sửa)',
                    hintText: 'VD: SONY-FX3-482',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _isEdit
                        ? null
                        : IconButton(
                            tooltip: 'Sinh lại mã ngẫu nhiên',
                            onPressed: _regenerateCode,
                            icon: const Icon(Icons.autorenew_rounded),
                          ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _dailyCtrl,
                      'Giá thuê/ngày (VNĐ) *',
                      keyboard: TextInputType.number,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _monthlyCtrl,
                      'Giá thuê/tháng (VNĐ) *',
                      keyboard: TextInputType.number,
                      required: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(_unitCtrl, 'Đơn vị *', required: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _installMinCtrl,
                      'Phút lắp đặt dự kiến',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _saving ? null : _pickCategoriesWithSearch,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Danh mục thiết bị',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(Icons.search_rounded),
                  ),
                  child: _selectedCategoryIds.isEmpty
                      ? const Text(
                          'Chạm để tìm và chọn danh mục...',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in widget.provider.categories.where(
                              (e) => _selectedCategoryIds.contains(e.id),
                            ))
                              InputChip(
                                label: Text(
                                  c.name,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                backgroundColor: AppColors.primaryLight,
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                                onDeleted: _saving
                                    ? null
                                    : () => setState(
                                        () => _selectedCategoryIds.remove(c.id),
                                      ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _specsCtrl,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    try {
                      _parseFlexibleSpecsJson(v);
                      return null;
                    } catch (_) {
                      return 'JSON thông số kỹ thuật chưa đúng cú pháp (VD: {"ram": "16GB", "weight": ""}).';
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Thông số kỹ thuật (JSON)',
                    helperText:
                        'Hỗ trợ key bỏ trống value (tự gán mặc định "").',
                    alignLabelWithHint: true,
                    hintText:
                        '{\n  "ram": "16GB",\n  "power": "220V",\n  "weight": ""\n}',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              _field(_descCtrl, 'Mô tả', maxLines: 3),

              _buildExistingMediaSection(),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickMultipleImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _pendingImages.isEmpty
                      ? 'Chọn hình ảnh cho Model (nhiều ảnh)'
                      : 'Thêm ảnh khác (đang chọn ${_pendingImages.length} ảnh)',
                ),
              ),

              if (_hasFailedImages) _buildPartialErrorBanner(),
              _buildPendingImagesList(),

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
                        _hasFailedImages
                            ? 'Tải lại các ảnh bị lỗi'
                            : (_isEdit ? 'Lưu thay đổi' : 'Tạo Model thiết bị'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartialErrorBanner() {
    final failedCount = _pendingImages
        .where((e) => e.status == PendingImageStatus.failed)
        .length;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Model đã được lưu. Có $failedCount ảnh bị lỗi bên dưới.',
        style: const TextStyle(color: AppColors.error, fontSize: 12.5),
      ),
    );
  }

  Widget _buildPendingImagesList() {
    if (_pendingImages.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 12),
        for (var i = 0; i < _pendingImages.length; i++)
          ListTile(
            dense: true,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_pendingImages[i].filePath),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(_pendingImages[i].fileName),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: _saving
                  ? null
                  : () => setState(() => _pendingImages.removeAt(i)),
            ),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập $label'
                  : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
