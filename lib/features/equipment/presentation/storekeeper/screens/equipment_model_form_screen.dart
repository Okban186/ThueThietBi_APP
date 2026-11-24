import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/data/models/pending_model_image.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

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

  bool get _isEdit => widget.existingModel != null;
  bool get _hasFailedImages =>
      _pendingImages.any((e) => e.status == PendingImageStatus.failed);

  @override
  void initState() {
    super.initState();
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
    dynamic specsJson;
    if (_specsCtrl.text.trim().isNotEmpty) {
      specsJson = jsonDecode(_specsCtrl.text.trim());
    }

    return {
      'code': _codeCtrl.text.trim(),
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
      'specifications': specsJson,
      'categoryIds': _selectedCategoryIds.toList(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // 1. Tạo hoặc cập nhật model (không tạo trùng nếu đã lưu ở lần bấm trước)
      final payload = _buildPayload();
      if (_savedModelId == null) {
        final created = await widget.provider.api.createModel(
          payload,
        ) as Map<String, dynamic>;
        _savedModelId = created['id'] as String;
      } else if (!_hasFailedImages) {
        await widget.provider.api.updateModel(_savedModelId!, payload);
      }

      // 2. Upload & Confirm các ảnh chưa thành công
      final allImagesOk = await widget.provider.api.uploadAndConfirmModelImages(
        modelId: _savedModelId!,
        items: _pendingImages,
      );

      // Luôn reload danh sách vì model & các ảnh hợp lệ đã lưu trên BE
      await widget.provider.loadModels();

      if (!mounted) return;

      if (allImagesOk) {
        Navigator.pop(context, true);
      } else {
        // Có ảnh lỗi -> ở lại trang để highlight ảnh lỗi
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Không thể lưu model thiết bị.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPrimaryExistingMedia(Map<String, dynamic> media) async {
    if (_savedModelId == null) return;
    try {
      await widget.provider.api.setPrimaryMedia(
        _savedModelId!,
        media['id'] as String,
      );
      setState(() {
        for (final item in _existingMedia) {
          item['isPrimary'] = item['id'] == media['id'];
        }
      });
      await widget.provider.loadModels();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Không đặt được ảnh chính.'),
          ),
        ),
      );
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
                  if (media['isPrimary'] == true)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Chính',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                _codeCtrl,
                'Mã Model *',
                hint: 'VD: TB-RICOH-MP305',
                required: true,
              ),
              _field(
                _nameCtrl,
                'Tên Model thiết bị *',
                hint: 'VD: Máy photocopy Ricoh MP 305',
                required: true,
              ),
              Row(
                children: [
                  Expanded(child: _field(_mfgCtrl, 'Hãng sản xuất')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_modelNumCtrl, 'Số hiệu Model')),
                ],
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
                  decoration: InputDecoration(
                    labelText: 'Thông số kỹ thuật (JSON)',
                    alignLabelWithHint: true,
                    hintText: '{\n  "ram": "16GB",\n  "power": "220V",\n  "weight": "12kg"\n}',
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

              if (_hasFailedImages) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _saving ? null : _finishAndExit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Bỏ qua ảnh lỗi & Hoàn tất'),
                ),
              ],
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
    final successCount = _pendingImages
        .where((e) => e.status == PendingImageStatus.uploaded)
        .length;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Model${successCount > 0 ? ' và $successCount ảnh hợp lệ' : ''} đã được lưu. '
              'Có $failedCount ảnh bị lỗi (đánh dấu đỏ bên dưới). '
              'Bạn có thể đổi ảnh để tải lại hoặc bấm "Bỏ qua ảnh lỗi & Hoàn tất".',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingImagesList() {
    if (_pendingImages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 12),
        for (var i = 0; i < _pendingImages.length; i++)
          Builder(
            builder: (_) {
              final item = _pendingImages[i];
              final isFailed = item.status == PendingImageStatus.failed;
              final isDone = item.status == PendingImageStatus.uploaded;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? AppColors.errorLight.withValues(alpha: 0.45)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFailed
                        ? AppColors.error
                        : (isDone ? AppColors.success : AppColors.border),
                    width: isFailed ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(item.filePath),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          if (isFailed)
                            Text(
                              item.errorMessage ??
                                  'Ảnh bị lỗi, vui lòng chọn ảnh khác.',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (isDone)
                            const Text(
                              'Đã tải lên thành công',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                              ),
                            )
                          else
                            const Text(
                              'Chờ tải lên',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isFailed)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                final replacement = await ImagePicker()
                                    .pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 85,
                                    );
                                if (replacement == null) return;
                                setState(() {
                                  item.filePath = replacement.path;
                                  item.fileName = replacement.name;
                                  item.status = PendingImageStatus.pending;
                                  item.errorMessage = null;
                                });
                              },
                        child: const Text('Đổi ảnh'),
                      ),
                    if (!isDone)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _pendingImages.removeAt(i)),
                      ),
                  ],
                ),
              );
            },
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
