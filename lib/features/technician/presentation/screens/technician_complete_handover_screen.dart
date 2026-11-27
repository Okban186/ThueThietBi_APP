import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/widgets/scanner/quick_serial_scanner_sheet.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import '../widgets/evidence_media_picker.dart';

class _DefectiveReportItem {
  _DefectiveReportItem({
    required this.equipmentId,
    required this.serialNumber,
    required this.modelCode,
    required this.modelName,
    required this.issueType,
    required this.description,
    required this.photos,
  });

  final String equipmentId, serialNumber, modelCode, modelName;
  String issueType;
  String description;
  List<LocalEvidenceFile> photos; // CHỈ ẢNH (không cho video với máy lỗi lẻ)

  String get issueTypeLabel => switch (issueType) {
    'DAMAGED' => 'Hư hỏng vật lý / móp vỡ',
    'MALFUNCTION' => 'Lỗi kỹ thuật / không lên nguồn',
    _ => 'Lỗi khác',
  };
}

/// Màn hình KTV trưởng xác nhận bàn giao tại hiện trường (UX tối ưu):
/// - Không hiển thị danh sách máy dài dòng hay nút toggle.
/// - Bước 1: Chụp ảnh / quay video hiện trường lắp đặt xong (bắt buộc ≥ 1 tệp, video ≤ 500 MB).
/// - Bước 2: Nếu có máy lỗi -> Quét mã vạch hoặc nhập Serial để hệ thống kiểm tra đúng máy thuộc phiếu,
///   sau đó gắn loại lỗi, mô tả chỗ hư và ảnh riêng (chỉ ảnh, tùy chọn) + ảnh/video chung cả đợt lỗi.
class TechnicianCompleteHandoverScreen extends StatefulWidget {
  const TechnicianCompleteHandoverScreen({
    super.key,
    required this.api,
    required this.stop,
  });

  final TechnicianApi api;
  final TechnicianHandoverStopDetail stop;

  static Future<TechnicianCompleteHandoverResult?> open(
    BuildContext context, {
    required TechnicianApi api,
    required TechnicianHandoverStopDetail stop,
  }) {
    return Navigator.of(context).push<TechnicianCompleteHandoverResult>(
      MaterialPageRoute(
        builder: (_) => TechnicianCompleteHandoverScreen(api: api, stop: stop),
      ),
    );
  }

  @override
  State<TechnicianCompleteHandoverScreen> createState() =>
      _TechnicianCompleteHandoverScreenState();
}

class _TechnicianCompleteHandoverScreenState
    extends State<TechnicianCompleteHandoverScreen> {
  final _noteCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();

  List<LocalEvidenceFile> _sceneMedia = const [];
  List<LocalEvidenceFile> _sharedIssueMedia = const [];
  final List<_DefectiveReportItem> _defectiveItems = [];

  bool _lookingUp = false;
  String? _lookupError;
  bool _submitting = false;
  double _uploadProgress = 0;
  String _submitStatus = '';

  @override
  void dispose() {
    _noteCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanAndLookup() async {
    final scanned = await QuickSerialScannerSheet.open(
      context,
      title: 'Quét mã máy bị lỗi',
      subtitle:
          'Quét mã vạch trên tem máy thuộc phiếu ${widget.stop.handoverCode} hoặc nhập thủ công.',
    );
    if (scanned != null && scanned.trim().isNotEmpty && mounted) {
      _serialCtrl.text = scanned.trim();
      await _lookupSerial(scanned.trim());
    }
  }

  Future<void> _lookupSerial(String rawSerial) async {
    final serial = rawSerial.trim();
    if (serial.isEmpty) {
      setState(() => _lookupError = 'Vui lòng nhập hoặc quét mã serial máy lỗi.');
      return;
    }

    // Kiểm tra trùng ngay trên client trước khi gọi API
    final dup = _defectiveItems.any(
      (e) => e.serialNumber.toLowerCase() == serial.toLowerCase(),
    );
    if (dup) {
      setState(
        () => _lookupError = 'Máy "$serial" đã có trong danh sách báo lỗi bên dưới.',
      );
      return;
    }

    setState(() {
      _lookingUp = true;
      _lookupError = null;
    });

    try {
      final res = await widget.api.lookupHandoverSerial(
        widget.stop.handoverNoteId,
        serial,
      );
      if (!mounted) return;

      if (!res.belongsToHandover || res.equipmentId == null) {
        setState(() {
          _lookupError =
              res.message ??
              'Mã serial "$serial" không thuộc phiếu bàn giao này.';
        });
        return;
      }

      // Kiểm tra lại theo equipmentId phòng trường hợp khác hoa/thường
      if (_defectiveItems.any((e) => e.equipmentId == res.equipmentId)) {
        setState(
          () => _lookupError =
              'Máy ${res.serialNumber} đã nằm trong danh sách máy lỗi.',
        );
        return;
      }

      _serialCtrl.clear();
      await _openDefectiveEditor(
        existing: null,
        equipmentId: res.equipmentId!,
        serialNumber: res.serialNumber,
        modelCode: res.modelCode ?? '',
        modelName: res.modelName ?? 'Thiết bị',
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _lookupError = apiErrorMessage(
            e,
            fallback: 'Không thể kiểm tra mã serial.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _openDefectiveEditor({
    required _DefectiveReportItem? existing,
    required String equipmentId,
    required String serialNumber,
    required String modelCode,
    required String modelName,
  }) async {
    final result = await showModalBottomSheet<_DefectiveReportItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DefectiveItemEditorSheet(
        existing: existing,
        equipmentId: equipmentId,
        serialNumber: serialNumber,
        modelCode: modelCode,
        modelName: modelName,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final idx = _defectiveItems.indexWhere(
          (e) => e.equipmentId == result.equipmentId,
        );
        if (idx >= 0) {
          _defectiveItems[idx] = result;
        } else {
          _defectiveItems.add(result);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_sceneMedia.isEmpty) {
      _msg(
        'Vui lòng đính kèm ít nhất 1 ảnh hoặc video minh chứng hiện trường bàn giao.',
        isError: true,
      );
      return;
    }

    if (_defectiveItems.isNotEmpty) {
      final hasAnyIssueMedia =
          _sharedIssueMedia.isNotEmpty ||
          _defectiveItems.any((d) => d.photos.isNotEmpty);
      if (!hasAnyIssueMedia) {
        _msg(
          'Có ${_defectiveItems.length} máy lỗi: vui lòng chụp/quay ít nhất 1 ảnh hoặc video chung cho đợt lỗi (hoặc ảnh riêng từng máy).',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _uploadProgress = 0;
      _submitStatus = 'Đang tải ảnh/video hiện trường...';
    });

    try {
      // 1. Upload ảnh/video hiện trường
      final sceneIds = await widget.api.uploadEvidenceMedia(
        _sceneMedia,
        folder: 'handover',
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p * 0.45);
        },
      );

      // 2. Upload ảnh/video chung đợt máy lỗi
      List<String> sharedIssueIds = const [];
      if (_sharedIssueMedia.isNotEmpty) {
        if (mounted) {
          setState(() => _submitStatus = 'Đang tải ảnh/video chung máy lỗi...');
        }
        sharedIssueIds = await widget.api.uploadEvidenceMedia(
          _sharedIssueMedia,
          folder: 'handover',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = 0.45 + p * 0.25);
          },
        );
      }

      // 3. Upload ảnh riêng từng máy lỗi (chỉ ảnh)
      final defectiveInputs = <TechnicianDefectiveItemInput>[];
      final itemsWithPhotos = _defectiveItems
          .where((e) => e.photos.isNotEmpty)
          .length;
      var uploadedPhotoItemCount = 0;

      for (final d in _defectiveItems) {
        List<String> itemIds = const [];
        if (d.photos.isNotEmpty) {
          if (mounted) {
            setState(
              () => _submitStatus = 'Đang tải ảnh riêng máy ${d.serialNumber}...',
            );
          }
          itemIds = await widget.api.uploadEvidenceMedia(
            d.photos,
            folder: 'handover',
            onProgress: (p) {
              if (mounted && itemsWithPhotos > 0) {
                final frac = (uploadedPhotoItemCount + p) / itemsWithPhotos;
                setState(() => _uploadProgress = 0.70 + frac * 0.20);
              }
            },
          );
          uploadedPhotoItemCount++;
        }

        defectiveInputs.add(
          TechnicianDefectiveItemInput(
            equipmentId: d.equipmentId,
            issueType: d.issueType,
            description: d.description,
            attachmentFileIds: itemIds,
          ),
        );
      }

      // 4. Chốt bàn giao
      if (mounted) {
        setState(() {
          _uploadProgress = 0.92;
          _submitStatus = 'Đang lưu kết quả bàn giao...';
        });
      }

      final result = await widget.api.completeHandover(
        widget.stop.handoverNoteId,
        sceneAttachmentFileIds: sceneIds,
        issueAttachmentFileIds: sharedIssueIds,
        defectiveItems: defectiveInputs,
        note: _noteCtrl.text,
      );

      if (mounted) {
        setState(() => _uploadProgress = 1.0);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể hoàn tất bàn giao.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStatus = '';
        });
      }
    }
  }

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stop.totalEquipmentCount;
    final defectCount = _defectiveItems.length;
    final goodCount = (total - defectCount).clamp(0, total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Xác nhận bàn giao ${widget.stop.handoverCode}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.stop.contractCode} • ${widget.stop.companyName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(
                      'Tổng $total máy',
                      AppColors.primary,
                      AppColors.primaryLight,
                    ),
                    _chip(
                      'Giao đạt: $goodCount',
                      AppColors.success,
                      AppColors.successLight,
                    ),
                    if (defectCount > 0)
                      _chip(
                        'Báo lỗi thu hồi: $defectCount',
                        AppColors.error,
                        AppColors.errorLight,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: EvidenceMediaPicker(
              title: '1. Ảnh / Video hiện trường lắp đặt xong',
              subtitle:
                  'Bắt buộc ≥ 1 ảnh hoặc video (hỗ trợ video tới 500 MB) chứng minh đã giao & lắp đặt.',
              files: _sceneMedia,
              allowVideo: true,
              maxFiles: 12,
              required: true,
              onChanged: (list) => setState(() => _sceneMedia = list),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            borderColor: defectCount > 0
                ? AppColors.error.withValues(alpha: 0.4)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Ghi nhận thiết bị lỗi lúc giao/lắp (nếu có)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nếu tất cả máy đều hoạt động tốt, bạn bỏ qua bước này. Nếu có máy hư, hãy quét mã vạch hoặc nhập đúng số Serial để kiểm tra thuộc phiếu và ghi nhận lỗi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: (_submitting || _lookingUp)
                        ? null
                        : _scanAndLookup,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'Quét mã vạch máy bị lỗi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _serialCtrl,
                        enabled: !_submitting && !_lookingUp,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _lookupSerial,
                        decoration: InputDecoration(
                          labelText: 'Hoặc nhập mã Serial thiết bị lỗi',
                          hintText: 'VD: SN-SONY-001',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(86, 48),
                      ),
                      onPressed: (_submitting || _lookingUp)
                          ? null
                          : () => _lookupSerial(_serialCtrl.text),
                      child: _lookingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Kiểm tra'),
                    ),
                  ],
                ),
                if (_lookupError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lookupError!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_defectiveItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Danh sách máy báo lỗi (${_defectiveItems.length} máy)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _defectiveItems.length; i++)
                    _buildDefectiveCard(_defectiveItems[i], i),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Hệ thống sẽ tự tạo phiếu thu hồi máy lỗi (DEFECTIVE_ON_DELIVERY) cho ${_defectiveItems.length} máy này. Sau khi Kho thu hồi xong, Quản lý mới xếp lịch giao bù (miễn phí ship).',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  EvidenceMediaPicker(
                    title: 'Ảnh / Video chung cả đợt máy lỗi',
                    subtitle:
                        'Hỗ trợ cả Ảnh và Video (≤ 500 MB) để quay/chụp nhanh cả lô máy lỗi.',
                    files: _sharedIssueMedia,
                    allowVideo: true,
                    maxFiles: 12,
                    required: !_defectiveItems.any((d) => d.photos.isNotEmpty),
                    onChanged: (list) =>
                        setState(() => _sharedIssueMedia = list),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: TextField(
              controller: _noteCtrl,
              enabled: !_submitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '3. Ghi chú bàn giao (không bắt buộc)',
                hintText:
                    'VD: Đã lắp đặt, test nguồn ổn định và bàn giao đủ phụ kiện...',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_submitting) ...[
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_submitStatus (${(_uploadProgress * 100).round()}%)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: defectCount > 0
                      ? AppColors.warning
                      : AppColors.success,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  defectCount > 0
                      ? 'Xác nhận giao $goodCount máy đạt & thu hồi $defectCount máy lỗi'
                      : 'Xác nhận hoàn tất bàn giao ($goodCount máy)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefectiveCard(_DefectiveReportItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.serialNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${item.modelName} (${item.modelCode})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loại lỗi: ${item.issueTypeLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                if (item.description.trim().isNotEmpty)
                  Text(
                    'Mô tả: ${item.description.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (item.photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Ảnh riêng: ${item.photos.length} ảnh',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Sửa thông tin lỗi',
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: _submitting
                ? null
                : () => _openDefectiveEditor(
                    existing: item,
                    equipmentId: item.equipmentId,
                    serialNumber: item.serialNumber,
                    modelCode: item.modelCode,
                    modelName: item.modelName,
                  ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Xóa khỏi danh sách lỗi',
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: AppColors.error,
            ),
            onPressed: _submitting
                ? null
                : () => setState(() => _defectiveItems.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? borderColor}) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? AppColors.border),
    ),
    child: child,
  );

  Widget _chip(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

class _DefectiveItemEditorSheet extends StatefulWidget {
  const _DefectiveItemEditorSheet({
    required this.existing,
    required this.equipmentId,
    required this.serialNumber,
    required this.modelCode,
    required this.modelName,
  });

  final _DefectiveReportItem? existing;
  final String equipmentId, serialNumber, modelCode, modelName;

  @override
  State<_DefectiveItemEditorSheet> createState() =>
      _DefectiveItemEditorSheetState();
}

class _DefectiveItemEditorSheetState extends State<_DefectiveItemEditorSheet> {
  late String _issueType;
  late final TextEditingController _descCtrl;
  late List<LocalEvidenceFile> _photos;

  @override
  void initState() {
    super.initState();
    _issueType = widget.existing?.issueType ?? 'DAMAGED';
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _photos = [...(widget.existing?.photos ?? const <LocalEvidenceFile>[])];
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Vui lòng mô tả cụ thể thiết bị bị hư ở đâu / tình trạng lỗi.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _DefectiveReportItem(
        equipmentId: widget.equipmentId,
        serialNumber: widget.serialNumber,
        modelCode: widget.modelCode,
        modelName: widget.modelName,
        issueType: _issueType,
        description: _descCtrl.text.trim(),
        photos: _photos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ghi nhận chi tiết thiết bị lỗi',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.serialNumber} • ${widget.modelName} (${widget.modelCode})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _issueType,
              decoration: InputDecoration(
                labelText: 'Loại lỗi *',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'DAMAGED',
                  child: Text('Hư hỏng vật lý / móp vỡ'),
                ),
                DropdownMenuItem(
                  value: 'MALFUNCTION',
                  child: Text('Lỗi kỹ thuật / không lên nguồn'),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text('Lỗi khác')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _issueType = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mô tả hư ở đâu / tình trạng lỗi *',
                hintText:
                    'VD: Vỡ góc màn hình bên trái, cổng HDMI không xuất hình...',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            EvidenceMediaPicker(
              title: 'Ảnh chụp riêng máy ${widget.serialNumber} (tùy chọn)',
              subtitle:
                  'Riêng từng máy lỗi chỉ hỗ trợ Ảnh (nếu đã quay/chụp chung cả đợt có thể bỏ qua).',
              files: _photos,
              allowVideo: false,
              maxFiles: 5,
              compact: true,
              onChanged: (list) => setState(() => _photos = list),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _save,
              icon: const Icon(Icons.add_task_rounded),
              label: Text(
                widget.existing == null
                    ? 'Thêm vào danh sách máy lỗi'
                    : 'Lưu cập nhật lỗi',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
