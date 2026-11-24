import 'dart:core';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/equipment/data/models/paged_equipment_result.dart';
import 'package:thuethietbi_app/features/equipment/data/models/pending_model_image.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/model_equipment_list_screen.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/widgets/quick_import_equipment_sheet.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import 'equipment_model_form_screen.dart';
import 'equipment_unit_form_screen.dart';

class EquipmentModelDetailScreen extends StatefulWidget {
  const EquipmentModelDetailScreen({
    super.key,
    required this.provider,
    required this.modelId,
  });

  final StorekeeperEquipmentProvider provider;
  final String modelId;

  static Future<void> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider,
    String modelId,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EquipmentModelDetailScreen(provider: provider, modelId: modelId),
      ),
    );
  }

  @override
  State<EquipmentModelDetailScreen> createState() =>
      _EquipmentModelDetailScreenState();
}

class _EquipmentModelDetailScreenState
    extends State<EquipmentModelDetailScreen> {
  final _pageCtrl = PageController();
  int _totalUnitsCount = 0;
  Map<String, dynamic>? _model;
  List<dynamic> _units = [];
  int _currentImageIndex = 0;
  bool _loading = true;
  bool _uploadingImages = false;
  String? _error;

  bool get _isLead => widget.provider.isLeadStorekeeper;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.provider.api.getModelDetail(widget.modelId),
        widget.provider.api.getEquipmentsPaged(
          modelId: widget.modelId,
          page: 1,
          pageSize: 5,
        ),
      ]);
      if (!mounted) return;
      final paged = results[1] as PagedEquipmentResult;
      setState(() {
        _model = results[0] as Map<String, dynamic>;
        _units = paged.items;
        _totalUnitsCount = paged.totalCount;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được chi tiết model.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final List<PendingModelImage> _failedUploads = [];

  Future<void> _pickAndUploadMultipleImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    final batch = picked
        .map((f) => PendingModelImage(filePath: f.path, fileName: f.name))
        .toList();

    await _runUploadBatch(batch);
  }

  Future<void> _runUploadBatch(List<PendingModelImage> batch) async {
    setState(() => _uploadingImages = true);
    try {
      await widget.provider.api.uploadAndConfirmModelImages(
        modelId: widget.modelId,
        items: batch,
      );

      final failed = batch
          .where((e) => e.status == PendingImageStatus.failed)
          .toList();

      await _loadData();
      await widget.provider.loadModels();

      if (!mounted) return;
      setState(() {
        _failedUploads
          ..clear()
          ..addAll(failed);
      });

      if (failed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải lên toàn bộ ảnh thành công.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: 'Tải ảnh thất bại.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  Future<void> _setPrimary(String mediaId) async {
    try {
      await widget.provider.api.setPrimaryMedia(widget.modelId, mediaId);
      await _loadData();
      await widget.provider.loadModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, fallback: 'Không đặt được ảnh đại diện.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteMedia(String mediaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hình ảnh'),
        content: const Text(
          'Bạn có chắc muốn xóa ảnh này khỏi model thiết bị?',
        ),
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
    if (confirm != true) return;

    try {
      await widget.provider.api.deleteMedia(widget.modelId, mediaId);
      await _loadData();
      await widget.provider.loadModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: 'Không thể xóa ảnh.')),
          ),
        );
      }
    }
  }

  void _openFullScreenGallery(List<dynamic> mediaList, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGalleryViewer(
          mediaList: mediaList,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _model?['code'] as String? ?? 'Chi tiết Model',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isLead && _model != null)
            IconButton(
              tooltip: 'Chỉnh sửa model',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final ok = await EquipmentModelFormScreen.open(
                  context,
                  widget.provider,
                  existingModel: _model,
                );
                if (ok == true) _loadData();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _model == null
          ? Center(child: Text(_error ?? 'Không tìm thấy dữ liệu'))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _buildGallerySection(),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildSpecsCard(),
                        const SizedBox(height: 16),
                        _buildUnitsSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGallerySection() {
    final mediaList = (_model!['media'] as List<dynamic>? ?? const []).cast();
    final currentMedia = mediaList.isNotEmpty
        ? mediaList[_currentImageIndex]
        : null;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: mediaList.isEmpty
                    ? Container(
                        color: AppColors.surfaceSecondary,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 48,
                              color: AppColors.textDisabled,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Chưa có hình ảnh nào',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : PageView.builder(
                        controller: _pageCtrl,
                        itemCount: mediaList.length,
                        onPageChanged: (i) =>
                            setState(() => _currentImageIndex = i),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _openFullScreenGallery(mediaList, i),
                          child: CachedNetworkImage(
                            imageUrl: mediaList[i]['url'] as String,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
              ),
              if (mediaList.isNotEmpty)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${mediaList.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (currentMedia != null && currentMedia['isPrimary'] == true)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Ảnh đại diện',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Dải thumbnail bên dưới
          if (mediaList.isNotEmpty)
            SizedBox(
              height: 68,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: mediaList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == _currentImageIndex;
                  return GestureDetector(
                    onTap: () => _pageCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: mediaList[i]['url'] as String,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Thanh thao tác ảnh — CHỈ HIỆN VỚI LEAD_STOREKEEPER
          if (_isLead)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _uploadingImages
                        ? null
                        : _pickAndUploadMultipleImages,
                    icon: _uploadingImages
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                    label: Text(
                      _uploadingImages ? 'Đang tải...' : 'Thêm nhiều ảnh',
                    ),
                  ),
                  if (currentMedia != null && currentMedia['isPrimary'] != true)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _setPrimary(currentMedia['id'] as String),
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Đặt làm ảnh chính'),
                    ),
                  if (currentMedia != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () =>
                          _deleteMedia(currentMedia['id'] as String),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Xóa ảnh này'),
                    ),
                ],
              ),
            ),

          // Danh sách ảnh bị lỗi (nằm trong Column, ngay dưới thanh thao tác)
          if (_failedUploads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_failedUploads.length} ảnh bị lỗi (chưa được lưu)',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _failedUploads.clear()),
                          child: const Text('Bỏ qua'),
                        ),
                      ],
                    ),
                    for (final item in _failedUploads)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.errorMessage ?? 'Sai định dạng ảnh.',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final replacement = await ImagePicker().pickImage(
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
                      ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _uploadingImages
                            ? null
                            : () => _runUploadBatch(_failedUploads),
                        child: const Text('Tải lại các ảnh đã đổi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final m = _model!;
    final cats = (m['categories'] as List<dynamic>? ?? const []).cast();
    return Container(
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
            m['name'] as String,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${m['manufacturer'] ?? 'Chưa rõ hãng'} • Model: ${m['modelNumber'] ?? '-'} • ĐVT: ${m['unit']}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in cats)
                  Chip(
                    label: Text(
                      c['name'] as String,
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
                child: _infoMetric(
                  'Giá thuê / ngày',
                  CurrencyFormatter.vnd(
                    (m['rentalPriceDaily'] as num).toDouble(),
                  ),
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _infoMetric(
                  'Giá thuê / tháng',
                  CurrencyFormatter.vnd(
                    (m['rentalPriceMonthly'] as num).toDouble(),
                  ),
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoMetric(
                  'Tổng máy',
                  '${m['totalUnits']}',
                  AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _infoMetric(
                  'Hoạt động',
                  '${m['operationalUnits']}',
                  AppColors.info,
                ),
              ),
              Expanded(
                child: _infoMetric(
                  'Khả dụng hôm nay',
                  '${m['availableToday']}',
                  AppColors.success,
                ),
              ),
            ],
          ),
          if ((m['description'] as String?)?.isNotEmpty == true) ...[
            const Divider(height: 24),
            Text(
              m['description'] as String,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoMetric(String label, String value, Color color) => Column(
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

  Widget _buildSpecsCard() {
    final specs = _model!['specifications'] as Map<String, dynamic>?;

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
          const Text(
            'Thông số kỹ thuật',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (specs == null || specs.isEmpty)
            const Text(
              'Chưa cập nhật thông số kỹ thuật.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...specs.entries.map(
              (e) => _buildSpecNode(e.key, e.value, depth: 0),
            ),
        ],
      ),
    );
  }

  /// Chuẩn hóa mọi key (snake_case, kebab-case, camelCase) theo quy luật, không fix cứng từ điển.
  String _formatSpecKey(String rawKey) {
    final separated = rawKey
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
          (_) => ' ',
        )
        .trim();

    if (separated.isEmpty) return rawKey;

    final words = separated.split(RegExp(r'\s+'));
    return words
        .asMap()
        .entries
        .map((entry) {
          final w = entry.value;
          // Giữ nguyên nếu từ gốc đã viết HOA toàn bộ (VD: USB, HDMI, RAM)
          if (w.length > 1 && w == w.toUpperCase()) return w;
          // Viết hoa chữ cái đầu của từ đầu tiên
          if (entry.key == 0) {
            return w[0].toUpperCase() + w.substring(1).toLowerCase();
          }
          return w.toLowerCase();
        })
        .join(' ');
  }

  Widget _buildSpecNode(String key, dynamic value, {required int depth}) {
    final label = _formatSpecKey(key);

    // 1. Object lồng nhau
    if (value is Map<String, dynamic>) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: depth == 0 ? 13.5 : 12.5,
              color: depth == 0 ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...value.entries.map(
            (e) => _buildSpecNode(e.key, e.value, depth: depth + 1),
          ),
        ],
      );

      if (depth == 0) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: content,
        );
      }

      return Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 8),
        child: content,
      );
    }

    // 2. Mảng (List)
    if (value is List) {
      final isCompactPrimitiveList =
          value.isNotEmpty &&
          value.length <= 5 &&
          value.every(
            (e) => e is! Map && e is! List && e.toString().length <= 12,
          );

      // Mảng ngắn (VD: [250, 300, 400]) -> hiển thị gọn trên 1 dòng
      if (value.isEmpty || isCompactPrimitiveList) {
        final text = value.isEmpty
            ? '-'
            : value.map(_formatPrimitive).join(', ');
        return _buildKeyValueRow(label, text, depth: depth);
      }

      // Mảng dài hoặc chứa object -> hiển thị thành danh sách
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: depth == 0
            ? const EdgeInsets.all(12)
            : const EdgeInsets.only(left: 8),
        decoration: depth == 0
            ? BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: depth == 0 ? 13.5 : 12.5,
                color: depth == 0 ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < value.length; i++)
              if (value[i] is Map<String, dynamic>)
                _buildSpecNode('#${i + 1}', value[i], depth: depth + 1)
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatPrimitive(value[i]),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );
    }

    // 3. Giá trị đơn
    return _buildKeyValueRow(label, _formatPrimitive(value), depth: depth);
  }

  Widget _buildKeyValueRow(String label, String value, {required int depth}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: depth == 0 ? 13 : 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: depth == 0 ? 13 : 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrimitive(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'Có' : 'Không';
    return value.toString();
  }

  Widget _buildUnitsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách thiết bị (${_units.length})',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_isLead)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await QuickImportEquipmentSheet.open(
                      context,
                      widget.provider,
                      preselectedModelId: widget.modelId,
                    );
                    if (ok == true) _loadData();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nhập máy'),
                ),
            ],
          ),
          if (_units.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có thiết bị vật lý nào thuộc model này.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final u in _units)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  u['serialNumber'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${u['warehouseName']} • Tình trạng: ${u['condition']}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: Text(
                  u['status'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: u['status'] == 'AVAILABLE'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
          if (_totalUnitsCount > _units.length) ...[
            const Divider(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ModelEquipmentListScreen.open(
                    context,
                    provider: widget.provider,
                    modelId: widget.modelId,
                    modelName: _model!['name'] as String,
                  );
                  _loadData();
                },
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('Xem tất cả $_totalUnitsCount thiết bị'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Xem ảnh phóng to toàn màn hình (vuốt chuyển ảnh + pinch-to-zoom).
class _FullScreenGalleryViewer extends StatefulWidget {
  const _FullScreenGalleryViewer({
    required this.mediaList,
    required this.initialIndex,
  });
  final List<dynamic> mediaList;
  final int initialIndex;

  @override
  State<_FullScreenGalleryViewer> createState() =>
      _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late final PageController _ctrl = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.mediaList.length}'),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.mediaList.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.mediaList[i]['url'] as String,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
