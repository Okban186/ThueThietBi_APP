import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/widgets/scanner/quick_serial_scanner_sheet.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import '../widgets/evidence_media_picker.dart';

/// Màn hình KTV trưởng kiểm đếm từng thiết bị thu hồi tại hiện trường (quét barcode/nhập serial),
/// đánh giá tình trạng (GOOD / FAIR / DAMAGED) hoặc báo thiếu/mất (MISSING),
/// đính kèm ảnh/video minh chứng (video <= 500MB) và chuyển phiếu về Kho kiểm nhận.
class TechnicianCompleteRetrievalScreen extends StatefulWidget {
  const TechnicianCompleteRetrievalScreen({
    super.key,
    required this.api,
    required this.stop,
  });

  final TechnicianApi api;
  final TechnicianRetrievalStopDetail stop;

  static Future<TechnicianCompleteRetrievalResult?> open(
    BuildContext context, {
    required TechnicianApi api,
    required TechnicianRetrievalStopDetail stop,
  }) => Navigator.of(context).push<TechnicianCompleteRetrievalResult>(
    MaterialPageRoute(
      builder: (_) => TechnicianCompleteRetrievalScreen(api: api, stop: stop),
    ),
  );

  @override
  State<TechnicianCompleteRetrievalScreen> createState() =>
      _TechnicianCompleteRetrievalScreenState();
}

class _TechnicianCompleteRetrievalScreenState
    extends State<TechnicianCompleteRetrievalScreen> {
  final _noteCtrl = TextEditingController();
  late final Map<String, _RetrievalDraft> _drafts;
  final Set<String> _scannedIds = {};
  List<LocalEvidenceFile> _media = const [];
  bool _submitting = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _drafts = {
      for (final item in widget.stop.items)
        item.equipmentId: _RetrievalDraft(
          status: 'RETURNED',
          condition: item.condition == 'DAMAGED' ? 'DAMAGED' : 'GOOD',
          noteCtrl: TextEditingController(),
        ),
    };
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final d in _drafts.values) {
      d.noteCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _scanSerial() async {
    final code = await QuickSerialScannerSheet.open(
      context,
      title: 'Quét Serial thiết bị thu hồi',
      subtitle:
          'Quét mã vạch trên máy để tự động đánh dấu Đã thu (RETURNED) trên phiếu ${widget.stop.returnCode}.',
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final query = code.trim().toUpperCase();
    final matched = widget.stop.items
        .where((i) => i.serialNumber.trim().toUpperCase() == query)
        .firstOrNull;

    if (matched == null) {
      _msg(
        'Serial "$code" không nằm trong danh sách cần thu hồi của phiếu ${widget.stop.returnCode}.',
        isError: true,
      );
      return;
    }

    setState(() {
      _scannedIds.add(matched.equipmentId);
      _drafts[matched.equipmentId]!.status = 'RETURNED';
    });
    _msg('Đã xác nhận thu máy ${matched.serialNumber} (${matched.modelName}).');
  }

  Future<void> _submit() async {
    if (_media.isEmpty) {
      _msg(
        'Vui lòng chụp ít nhất 1 ảnh hoặc quay video minh chứng hiện trường thu hồi.',
        isError: true,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _uploadProgress = 0;
    });

    try {
      final fileIds = await widget.api.uploadEvidenceMedia(
        _media,
        folder: 'handover',
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      final inputs = [
        for (final item in widget.stop.items)
          TechnicianCompleteRetrievalItemInput(
            equipmentId: item.equipmentId,
            status: _drafts[item.equipmentId]!.status,
            condition: _drafts[item.equipmentId]!.status == 'RETURNED'
                ? _drafts[item.equipmentId]!.condition
                : null,
            note: _drafts[item.equipmentId]!.noteCtrl.text,
          ),
      ];

      final res = await widget.api.completeRetrievalStop(
        widget.stop.returnId,
        attachmentFileIds: fileIds,
        items: inputs,
        note: _noteCtrl.text,
      );

      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể hoàn tất xác nhận thu hồi.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    final s = widget.stop;
    final returnedCount = _drafts.values
        .where((d) => d.status == 'RETURNED')
        .length;
    final missingCount = _drafts.length - returnedCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Thu hồi • ${s.returnCode}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Quét mã vạch Serial',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _submitting ? null : _scanSerial,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.contractCode} • ${s.companyName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hết hạn HĐ: ${DateFormatter.date(s.contractEndDate)} • Đã chọn thu: $returnedCount • Thiếu/mất: $missingCount',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _submitting ? null : _scanSerial,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(
                      'Quét Barcode / Nhập Serial nhanh (${_scannedIds.length}/${s.items.length} đã quét)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kiểm đếm từng thiết bị (${s.items.length} máy)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          for (final item in s.items) _buildItemCard(item),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EvidenceMediaPicker(
                  title: 'Ảnh / Video minh chứng thu hồi *',
                  subtitle:
                      'Bắt buộc tối thiểu 1 ảnh hoặc video (tối đa 500MB) thể hiện tình trạng thiết bị lúc nhận lại từ khách.',
                  files: _media,
                  maxFiles: 10,
                  required: true,
                  onChanged: (list) => setState(() => _media = list),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú biên bản thu hồi (tùy chọn)',
                    hintText:
                        'VD: Đã tháo dỡ xong, khách ký xác nhận đủ phụ kiện...',
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
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
            children: [
              if (_submitting && _uploadProgress > 0 && _uploadProgress < 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(value: _uploadProgress),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
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
                  _submitting
                      ? 'Đang tải minh chứng & xác nhận...'
                      : 'Xác nhận thu hồi ($returnedCount thu / $missingCount thiếu)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(TechnicianRetrievalItem item) {
    final draft = _drafts[item.equipmentId]!;
    final isReturned = draft.status == 'RETURNED';
    final isScanned = _scannedIds.contains(item.equipmentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !isReturned
              ? AppColors.error.withValues(alpha: 0.45)
              : isScanned
              ? AppColors.success.withValues(alpha: 0.55)
              : AppColors.border,
        ),
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
                      item.serialNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${item.modelName} (${item.modelCode})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isScanned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Đã quét',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'RETURNED',
                icon: Icon(Icons.check_rounded, size: 16),
                label: Text('Đã thu về'),
              ),
              ButtonSegment(
                value: 'MISSING',
                icon: Icon(Icons.warning_amber_rounded, size: 16),
                label: Text('Thiếu / Mất'),
              ),
            ],
            selected: {draft.status},
            onSelectionChanged: _submitting
                ? null
                : (s) => setState(() => draft.status = s.first),
          ),
          if (isReturned) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final (code, label) in const [
                  ('GOOD', 'Tốt (GOOD)'),
                  ('FAIR', 'Khá (FAIR)'),
                  ('DAMAGED', 'Hư hỏng (DAMAGED)'),
                ])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11.5)),
                    selected: draft.condition == code,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => draft.condition = code),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: draft.noteCtrl,
            decoration: InputDecoration(
              labelText: isReturned
                  ? 'Ghi chú tình trạng máy (tùy chọn)'
                  : 'Lý do thiếu / mất máy',
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetrievalDraft {
  _RetrievalDraft({
    required this.status,
    required this.condition,
    required this.noteCtrl,
  });

  String status;
  String condition;
  final TextEditingController noteCtrl;
}
