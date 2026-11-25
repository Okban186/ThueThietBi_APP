import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/handover_api.dart';
import '../../../data/models/handover_preparation.dart';
import 'handover_detail_screen.dart';
import 'handover_form_screen.dart';
import 'handover_home_screen.dart';

/// Chuẩn bị bàn giao cho một hợp đồng: số lượng từng model, các phiếu đã soạn,
/// nút lập phiếu mới cho số máy còn thiếu.
class HandoverContractScreen extends StatefulWidget {
  const HandoverContractScreen({
    super.key,
    required this.api,
    required this.contractId,
  });

  final HandoverApi api;
  final String contractId;

  static Future<void> open(
    BuildContext context,
    HandoverApi api,
    String contractId,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HandoverContractScreen(api: api, contractId: contractId),
      ),
    );
  }

  @override
  State<HandoverContractScreen> createState() => _HandoverContractScreenState();
}

class _HandoverContractScreenState extends State<HandoverContractScreen> {
  PreparationContractDetail? _detail;
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
      final detail = await widget.api.getContract(widget.contractId);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được hợp đồng.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNote(PreparationContractDetail detail) async {
    final created = await HandoverFormScreen.create(
      context,
      api: widget.api,
      contract: detail,
    );

    if (created != null && mounted) {
      await HandoverDetailScreen.open(context, widget.api, created.handover.id);
    }

    _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final remaining =
        detail?.items.fold<int>(0, (s, i) => s + i.remainingQuantity) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.contract.contractCode ?? 'Hợp đồng',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(detail),
      bottomNavigationBar: detail == null || remaining <= 0
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton.icon(
                  onPressed: () => _createNote(detail),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text('Lập phiếu bàn giao (còn $remaining máy)'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(PreparationContractDetail? detail) {
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

    final c = detail.contract;

    return RefreshIndicator(
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
                        c.contractCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ContractStatusBadge(status: c.contractStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.companyName} (${c.companyCode})',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  'Thời gian thuê',
                  DateFormatter.dateRange(c.startDate, c.endDate),
                ),
                _InfoRow('Địa chỉ giao', c.deliveryAddress),
                _InfoRow('Ghi chú giao', detail.deliveryNote),
                _InfoRow(
                  'Người nhận',
                  [
                    detail.representativeName,
                    detail.representativePhone,
                  ].whereType<String>().join(' · '),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Thiết bị cần chuẩn bị',
            child: Column(
              children: [
                for (final item in detail.items) _ItemProgress(item: item),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Phiếu bàn giao (${detail.notes.length})',
            child: detail.notes.isEmpty
                ? const Text(
                    'Chưa có phiếu nào. Bấm "Lập phiếu bàn giao" để chọn máy.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                : Column(
                    children: [
                      for (final note in detail.notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: HandoverNoteCard(
                            note: note,
                            onTap: () async {
                              await HandoverDetailScreen.open(
                                context,
                                widget.api,
                                note.id,
                              );
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ItemProgress extends StatelessWidget {
  const _ItemProgress({required this.item});

  final PreparationItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.remainingQuantity <= 0;
    final shortage = !done && item.availableInStock < item.remainingQuantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.modelName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${item.allocatedQuantity}/${item.quantity} ${item.unit.toLowerCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: done ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.quantity == 0
                  ? 0
                  : (item.allocatedQuantity / item.quantity).clamp(0, 1),
              minHeight: 6,
              color: done ? AppColors.success : AppColors.primary,
              backgroundColor: AppColors.surfaceSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? '${item.modelCode} · Đã xếp đủ máy'
                : '${item.modelCode} · Còn thiếu ${item.remainingQuantity} · Kho sẵn ${item.availableInStock}',
            style: TextStyle(
              fontSize: 12.5,
              color: shortage ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          if (shortage)
            const Text(
              'Kho không đủ máy sẵn sàng, cần báo quản lý.',
              style: TextStyle(fontSize: 12.5, color: AppColors.error),
            ),
        ],
      ),
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
            const SizedBox(height: AppSpacing.sm),
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
