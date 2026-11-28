import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/handover_api.dart';
import '../../../data/models/handover_preparation.dart';
import '../../common/widgets/handover_status_badge.dart';
import 'handover_form_screen.dart';

/// Chi tiết phiếu bàn giao: danh sách máy theo model, thao tác của thủ kho
/// (sửa, soạn xong, hủy) theo trạng thái.
class HandoverDetailScreen extends StatefulWidget {
  const HandoverDetailScreen({
    super.key,
    required this.api,
    required this.handoverId,
  });

  final HandoverApi api;
  final String handoverId;

  static Future<void> open(
    BuildContext context,
    HandoverApi api,
    String handoverId,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HandoverDetailScreen(api: api, handoverId: handoverId),
      ),
    );
  }

  @override
  State<HandoverDetailScreen> createState() => _HandoverDetailScreenState();
}

class _HandoverDetailScreenState extends State<HandoverDetailScreen> {
  HandoverDetail? _detail;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await widget.api.getNote(widget.handoverId);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được phiếu bàn giao.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  Future<void> _run(
    Future<HandoverDetail> Function() action,
    String success,
  ) async {
    setState(() => _isBusy = true);

    try {
      final detail = await action();
      if (!mounted) return;
      setState(() => _detail = detail);
      _showMessage(success);
    } catch (error) {
      if (mounted) _showMessage(apiErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _edit(HandoverDetail detail) async {
    setState(() => _isBusy = true);

    try {
      final contract = await widget.api.getContract(
        detail.handover.rentalContractId,
      );
      if (!mounted) return;
      setState(() => _isBusy = false);

      final updated = await HandoverFormScreen.edit(
        context,
        api: widget.api,
        contract: contract,
        existing: detail,
      );

      if (updated != null && mounted) {
        setState(() => _detail = updated);
        _showMessage('Đã lưu phiếu ${updated.handover.handoverCode}.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isBusy = false);
        _showMessage(apiErrorMessage(error), isError: true);
      }
    }
  }

  Future<void> _submit(HandoverDetail detail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Soạn xong phiếu?'),
        content: Text(
          'Phiếu ${detail.handover.handoverCode} (${detail.items.length} máy) sẽ chuyển sang chờ quản lý duyệt xuất kho. Sau đó không sửa được danh sách máy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Soạn xong'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _run(
      () => widget.api.submit(detail.handover.id),
      'Phiếu đã chuyển sang chờ duyệt xuất kho.',
    );
  }

  Future<void> _cancel(HandoverDetail detail) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(code: detail.handover.handoverCode),
    );

    if (reason == null) return;

    await _run(
      () => widget.api.cancel(detail.handover.id, reason),
      'Đã hủy phiếu, máy đã trả về kho.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.handover.handoverCode ?? 'Phiếu bàn giao',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(detail),
      bottomNavigationBar: detail == null ? null : _buildActions(detail),
    );
  }

  Widget _buildBody(HandoverDetail? detail) {
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

    final h = detail.handover;
    final byModel = <String, List<HandoverLine>>{};
    for (final line in detail.items) {
      byModel.putIfAbsent(line.modelName, () => []).add(line);
    }

    return AbsorbPointer(
      absorbing: _isBusy,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.handoverCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      HandoverStatusBadge(status: h.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${h.contractCode} · ${h.companyName}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(
                    'Loại phiếu',
                    h.isIncidentReplacement
                        ? 'Giao máy thay thế sự cố'
                        : h.isSupplementary
                        ? 'Giao bù máy lỗi (miễn phí ship)'
                        : 'Phiếu bàn giao gốc',
                  ),
                  _InfoRow(
                    'Ngày giao',
                    DateFormatter.weekdayDate(h.handoverDate),
                  ),
                  _InfoRow(
                    'Người nhận',
                    [
                      h.receivedByName,
                      h.receivedByPhone,
                    ].whereType<String>().join(' · '),
                  ),
                  _InfoRow('Địa chỉ giao', detail.deliveryAddress),
                  _InfoRow('Ghi chú giao (HĐ)', detail.deliveryNote),
                  _InfoRow('Ghi chú phiếu', h.note),
                  _InfoRow('Người tạo phiếu', h.createdByName),
                  _InfoRow(
                    'Thủ kho phụ trách',
                    h.isClaimed
                        ? (h.assignedStorekeeperName ?? 'Đã tiếp nhận')
                        : 'Chưa có người tiếp nhận',
                  ),
                ],
              ),
            ),
            if (h.isEditable && !h.isClaimed) ...[
              const SizedBox(height: AppSpacing.md),
              const _Banner(
                text:
                    'Phiếu bàn giao này chưa có Thủ kho tiếp nhận. Bấm "Tiếp nhận soạn phiếu này" bên dưới để khóa quyền phụ trách (các Thủ kho khác sẽ không thấy phiếu này nữa).',
              ),
            ],
            if (h.status == HandoverStatus.pendingApproval) ...[
              const SizedBox(height: AppSpacing.md),
              const _Banner(
                text: 'Đã soạn xong, đang chờ quản lý duyệt xuất kho. Kỹ thuật viên sẽ nhận phiếu để đi giao.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Danh sách máy (${detail.items.length})',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in byModel.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '${entry.key} × ${entry.value.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    for (final line in entry.value)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          line.serialNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            line.warehouseName,
                            if (line.note != null) line.note!,
                          ].join(' · '),
                        ),
                        trailing: Text(
                          _equipmentStatusLabel(line.equipmentStatus),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(HandoverDetail detail) async {
    await _run(
      () => widget.api.claim(detail.handover.id),
      'Bạn đã tiếp nhận phụ trách phiếu ${detail.handover.handoverCode}.',
    );
  }

  Widget? _buildActions(HandoverDetail detail) {
    final h = detail.handover;
    if (!h.isCancellable) return null;

    if (h.isEditable && !h.isClaimed) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _isBusy ? null : () => _claim(detail),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Tiếp nhận soạn phiếu này'),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (h.isEditable) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : () => _submit(detail),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Soạn xong'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                tooltip: 'Sửa phiếu',
                onPressed: _isBusy ? null : () => _edit(detail),
                icon: const Icon(Icons.edit_outlined),
              ),
            ] else
              const Expanded(
                child: Text(
                  'Chờ quản lý duyệt xuất kho.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.outlined(
              tooltip: 'Hủy phiếu',
              color: AppColors.error,
              onPressed: _isBusy ? null : () => _cancel(detail),
              icon: const Icon(Icons.cancel_outlined),
            ),
          ],
        ),
      ),
    );
  }

  static String _equipmentStatusLabel(String status) => switch (status) {
    'RESERVED' => 'Đã giữ',
    'RENTED' => 'Đã giao',
    'AVAILABLE' => 'Trong kho',
    _ => status,
  };
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.code});

  final String code;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Hủy phiếu ${widget.code}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Các máy trong phiếu sẽ được trả về kho.'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Lý do hủy *',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Không'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) {
              setState(() => _error = 'Vui lòng nhập lý do.');
              return;
            }
            Navigator.pop(context, reason);
          },
          child: const Text('Hủy phiếu'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
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

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.warning, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
