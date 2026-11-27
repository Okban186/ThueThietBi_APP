import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import 'evidence_media_picker.dart';

/// Bottom sheet cho KTV trưởng báo "Giao không thành công" kèm lý do + ảnh/video minh chứng (video ≤ 500 MB).
class TechnicianFailHandoverSheet extends StatefulWidget {
  const TechnicianFailHandoverSheet({
    super.key,
    required this.api,
    required this.stop,
  });

  final TechnicianApi api;
  final TechnicianHandoverStopDetail stop;

  static Future<TechnicianFailHandoverResult?> open(
    BuildContext context, {
    required TechnicianApi api,
    required TechnicianHandoverStopDetail stop,
  }) {
    return showModalBottomSheet<TechnicianFailHandoverResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TechnicianFailHandoverSheet(api: api, stop: stop),
    );
  }

  @override
  State<TechnicianFailHandoverSheet> createState() =>
      _TechnicianFailHandoverSheetState();
}

class _TechnicianFailHandoverSheetState
    extends State<TechnicianFailHandoverSheet> {
  static const _quickReasons = [
    'Không liên hệ được người nhận hàng',
    'Địa điểm giao hàng đóng cửa / không có người trực',
    'Khách hàng hẹn đổi lịch sang ngày khác',
    'Mặt bằng lắp đặt chưa sẵn sàng',
  ];

  final _reasonCtrl = TextEditingController();
  List<LocalEvidenceFile> _media = const [];
  bool _submitting = false;
  double _progress = 0;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _msg(
        'Vui lòng chọn hoặc nhập lý do giao không thành công.',
        isError: true,
      );
      return;
    }
    if (_media.isEmpty) {
      _msg(
        'Vui lòng chụp ảnh hoặc quay video minh chứng tại hiện trường.',
        isError: true,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _progress = 0;
    });

    try {
      final fileIds = await widget.api.uploadEvidenceMedia(
        _media,
        folder: 'handover',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p * 0.9);
        },
      );
      final result = await widget.api.failHandover(
        widget.stop.handoverNoteId,
        reason: reason,
        attachmentFileIds: fileIds,
      );
      if (mounted) {
        setState(() => _progress = 1.0);
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể gửi báo cáo giao thất bại.'),
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
    final nextAttempt = widget.stop.failedAt != null
        ? widget.stop.deliveryAttemptNumber + 1
        : widget.stop.deliveryAttemptNumber;
    final willPenalize = !widget.stop.isSupplementary && nextAttempt > 3;

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
                    'Báo giao không thành công',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '${widget.stop.handoverCode} • ${widget.stop.companyName}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: willPenalize
                    ? AppColors.errorLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.stop.isSupplementary
                    ? 'Phiếu giao bù máy lỗi: không tính lượt thất bại và không phạt khách. Sau khi xác nhận, phiếu chuyển về Quản lý xếp lịch mới.'
                    : willPenalize
                    ? 'Cảnh báo: Đây là lần giao thất bại thứ $nextAttempt (vượt 3 lần du di). Hệ thống sẽ lập khoản phụ phí giao lại và thông báo cho khách hàng.'
                    : 'Sau khi gửi, máy vẫn giữ chỗ cho hợp đồng và phiếu chuyển về Quản lý chốt lại giờ với khách & xếp lịch mới (lần #$nextAttempt/3 miễn phạt).',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: willPenalize ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chọn nhanh lý do:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _quickReasons)
                  ActionChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _reasonCtrl.text = r),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              enabled: !_submitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Chi tiết lý do giao không thành công *',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EvidenceMediaPicker(
              title: 'Ảnh / Video minh chứng hiện trường',
              subtitle:
                  'Bắt buộc ≥ 1 ảnh hoặc video (≤ 500 MB) chứng minh cổng đóng / không gặp khách.',
              files: _media,
              allowVideo: true,
              maxFiles: 8,
              required: true,
              compact: true,
              onChanged: (list) => setState(() => _media = list),
            ),
            if (_submitting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 4),
              Text(
                'Đang tải minh chứng (${(_progress * 100).round()}%)...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
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
                  : const Icon(Icons.report_problem_outlined),
              label: const Text('Xác nhận giao không thành công'),
            ),
          ],
        ),
      ),
    );
  }
}
