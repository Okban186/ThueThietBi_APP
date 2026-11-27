import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/return_api.dart';
import '../../../data/models/return_receipt.dart';

/// Chi tiết phiếu nhận trả / thu hồi:
/// - Nếu phiếu ở trạng thái PROCESSING (thu hồi do hủy giao giữa chừng): cho phép Thủ kho
///   kiểm đếm đủ 100% serial và xác nhận đưa toàn bộ vào MAINTENANCE.
class ReturnDetailScreen extends StatefulWidget {
  const ReturnDetailScreen({
    super.key,
    required this.api,
    required this.returnId,
  });

  final ReturnApi api;
  final String returnId;

  static Future<void> open(BuildContext context, ReturnApi api, String id) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReturnDetailScreen(api: api, returnId: id),
      ),
    );
  }

  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  ReturnReceiptDetail? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  final Map<String, ReturnCheck> _verifyChecks = {};
  final _verifyNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verifyNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await widget.api.getReturn(widget.returnId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _verifyChecks.clear();
          if (detail.receipt.isProcessing) {
            for (final line in detail.items) {
              _verifyChecks[line.equipmentId] = line.condition == 'DAMAGED'
                  ? ReturnCheck.damaged
                  : (line.condition == 'FAIR'
                        ? ReturnCheck.fair
                        : ReturnCheck.good);
            }
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được phiếu nhận trả.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmProcessing(ReturnReceiptDetail detail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nhận hàng thu hồi?'),
        content: Text(
          'Hệ thống sẽ đối chiếu đủ ${detail.items.length} serial trong phiếu ${detail.receipt.returnCode} và chuyển toàn bộ thiết bị nhận về sang trạng thái BẢO DƯỠNG (MAINTENANCE) để kiểm tra trước khi nhập kho khả dụng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kiểm lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận nhập bảo dưỡng'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isSubmitting = true);
    try {
      final inputs = [
        for (final line in detail.items)
          ReturnCheckInput(
            equipmentId: line.equipmentId,
            check: _verifyChecks[line.equipmentId] ?? ReturnCheck.good,
          ),
      ];
      final updated = await widget.api.confirmProcessing(
        detail.receipt.id,
        inputs,
        note: _verifyNoteCtrl.text.trim().isEmpty
            ? null
            : _verifyNoteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã xác nhận thu hồi đủ serial & tạo phiếu kiểm tra bảo dưỡng!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _claim(ReturnReceiptDetail detail) async {
    setState(() => _isSubmitting = true);
    try {
      final claimed = await widget.api.claim(detail.receipt.id);
      if (mounted) {
        setState(() => _detail = claimed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Bạn đã tiếp nhận phụ trách phiếu thu hồi ${claimed.receipt.returnCode}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              apiErrorMessage(
                error,
                fallback: 'Không thể tiếp nhận phiếu thu hồi.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final isProcessing = detail?.receipt.isProcessing ?? false;
    final isClaimed = detail?.receipt.isClaimed ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.receipt.returnCode ?? 'Phiếu nhận trả',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(detail),
      bottomNavigationBar: detail == null || !isProcessing
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: !isClaimed
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _isSubmitting ? null : () => _claim(detail),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.assignment_ind_outlined),
                        label: const Text(
                          'Tiếp nhận xử lý phiếu thu hồi này',
                        ),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _confirmProcessing(detail),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(
                          'Xác nhận đủ ${detail.items.length} máy → Chuyển Bảo dưỡng',
                        ),
                      ),
              ),
            ),
    );
  }

  Widget _buildBody(ReturnReceiptDetail? detail) {
    if (detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final r = detail.receipt;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (r.isProcessing)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.isDefectiveOnDelivery
                          ? 'Phiếu thu hồi tự động cho các máy bị lỗi khi giao/lắp đặt. Thủ kho bắt buộc kiểm đúng từng serial dưới đây; sau khi xác nhận, toàn bộ máy sẽ chuyển sang BẢO DƯỠNG (MAINTENANCE) để kiểm tra.'
                          : r.isIncidentReturn
                          ? 'Phiếu thu hồi tự động từ sự cố thiết bị tại hiện trường. Thủ kho bắt buộc kiểm đúng từng serial dưới đây; sau khi xác nhận, toàn bộ máy sẽ chuyển sang BẢO DƯỠNG (MAINTENANCE) để KTV sửa chữa.'
                          : 'Phiếu thu hồi do hủy giao giữa chừng. Thủ kho bắt buộc kiểm đúng từng serial dưới đây; sau khi xác nhận, toàn bộ máy sẽ chuyển sang BẢO DƯỠNG (MAINTENANCE) chứ không đưa vào kho cho thuê ngay.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.returnCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.contractCode} · ${r.companyName}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  'Thời điểm nhận',
                  DateFormatter.dateTime(r.returnedAt),
                ),
                _InfoRow('Người lập / nhận', r.receivedByName),
                _InfoRow(
                  'Thủ kho phụ trách',
                  r.isClaimed
                      ? (r.assignedStorekeeperName ?? 'Đã tiếp nhận')
                      : 'Chưa có người tiếp nhận',
                ),
                _InfoRow(
                  'Kết quả',
                  r.isProcessing
                      ? 'Chờ kiểm nhận (${detail.items.length} máy)'
                      : 'Nhận ${r.returnedCount} (hỏng ${r.damagedCount}) · Thất lạc ${r.missingCount}',
                ),
                _InfoRow('Ghi chú', r.note),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danh sách máy (${detail.items.length})',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final line in detail.items)
                    if (r.isProcessing)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.serialNumber} · ${line.modelName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final opt in ReturnCheck.values)
                                  ChoiceChip(
                                    label: Text(opt.label),
                                    selected:
                                        _verifyChecks[line.equipmentId] == opt,
                                    onSelected: (_) => setState(
                                      () =>
                                          _verifyChecks[line.equipmentId] = opt,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    showCheckmark: false,
                                  ),
                              ],
                            ),
                            const Divider(height: 12),
                          ],
                        ),
                      )
                    else
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_icon(line), color: _color(line)),
                        title: Text(
                          line.serialNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            line.modelName,
                            if (line.note != null) line.note!,
                          ].join(' · '),
                        ),
                        trailing: Text(
                          _label(line),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _color(line),
                          ),
                        ),
                      ),
                  if (r.isProcessing) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _verifyNoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú kiểm nhận kho',
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static String _label(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return 'Thất lạc';
    if (line.equipmentStatus == 'MAINTENANCE') return 'Đang bảo dưỡng';

    return switch (line.condition) {
      'DAMAGED' => 'Hỏng · chờ sửa',
      'FAIR' => 'Khá · về kho',
      _ => 'Tốt · về kho',
    };
  }

  static Color _color(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return AppColors.error;
    if (line.equipmentStatus == 'MAINTENANCE') return AppColors.warning;
    return line.condition == 'DAMAGED' ? AppColors.warning : AppColors.success;
  }

  static IconData _icon(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return Icons.help_outline_rounded;
    if (line.equipmentStatus == 'MAINTENANCE') {
      return Icons.build_circle_outlined;
    }
    return line.condition == 'DAMAGED'
        ? Icons.build_circle_outlined
        : Icons.check_circle_outline_rounded;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
