import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/return_api.dart';
import '../../../data/models/return_receipt.dart';

/// Chi tiết phiếu nhận trả: kết quả kiểm từng máy và trạng thái máy sau khi nhận.
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
      final detail = await widget.api.getReturn(widget.returnId);
      if (mounted) setState(() => _detail = detail);
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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.receipt.returnCode ?? 'Phiếu nhận trả',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(detail),
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
                _InfoRow('Người nhận', r.receivedByName),
                _InfoRow(
                  'Kết quả',
                  'Nhận ${r.returnedCount} (hỏng ${r.damagedCount}) · Thất lạc ${r.missingCount}',
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
                  for (final line in detail.items)
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return 'Thất lạc';

    return switch (line.condition) {
      'DAMAGED' => 'Hỏng · chờ sửa',
      'FAIR' => 'Khá · về kho',
      _ => 'Tốt · về kho',
    };
  }

  static Color _color(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return AppColors.error;
    return line.condition == 'DAMAGED' ? AppColors.warning : AppColors.success;
  }

  static IconData _icon(ReturnReceiptLine line) {
    if (line.status == 'MISSING') return Icons.help_outline_rounded;
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
