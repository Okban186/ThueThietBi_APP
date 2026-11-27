import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/return_api.dart';
import '../../../data/models/return_receipt.dart';
import 'return_contract_screen.dart';
import 'return_detail_screen.dart';

/// Tab "Nhận trả" của thủ kho: phiếu thu hồi hủy giữa chừng chờ kiểm nhận,
/// hợp đồng còn máy ở chỗ khách và các phiếu nhận trả gần đây.
class ReturnListView extends StatefulWidget {
  const ReturnListView({super.key, required this.api});

  final ReturnApi api;

  @override
  State<ReturnListView> createState() => ReturnListViewState();
}

class ReturnListViewState extends State<ReturnListView>
    with AutomaticKeepAliveClientMixin {
  List<ReturnContract> _contracts = [];
  List<ReturnReceipt> _receipts = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.getContracts(),
        widget.api.getReturns(),
      ]);
      if (!mounted) return;
      setState(() {
        _contracts = results[0] as List<ReturnContract>;
        _receipts = results[1] as List<ReturnReceipt>;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được dữ liệu nhận trả.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(onRefresh: reload, child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading && _contracts.isEmpty && _receipts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: _error,
          action: FilledButton(onPressed: reload, child: const Text('Thử lại')),
        ),
      );
    }

    if (_contracts.isEmpty && _receipts.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.move_to_inbox_outlined,
          title: 'Chưa có máy cần nhận trả',
          message:
              'Hợp đồng có máy đã giao hoặc phiếu thu hồi hủy giao giữa chừng sẽ hiện ở đây.',
        ),
      );
    }

    final pendingProcessing =
        _receipts.where((r) => r.isProcessing).toList();
    final completedReceipts =
        _receipts.where((r) => !r.isProcessing).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (pendingProcessing.isNotEmpty) ...[
          _Header(
            'Phiếu thu hồi chờ kiểm nhận & bảo dưỡng (${pendingProcessing.length})',
          ),
          for (final r in pendingProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ReturnReceiptCard(
                receipt: r,
                onTap: () async {
                  await ReturnDetailScreen.open(context, widget.api, r.id);
                  reload();
                },
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _Header('Hợp đồng còn máy ở chỗ khách (${_contracts.length})'),
        if (_contracts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              'Không còn máy nào ở chỗ khách.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        for (final c in _contracts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ContractCard(
              contract: c,
              onTap: () async {
                await ReturnContractScreen.open(
                  context,
                  widget.api,
                  c.contractId,
                );
                reload();
              },
            ),
          ),
        if (completedReceipts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Header('Phiếu nhận trả đã hoàn tất (${completedReceipts.length})'),
          for (final r in completedReceipts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ReturnReceiptCard(
                receipt: r,
                onTap: () async {
                  await ReturnDetailScreen.open(context, widget.api, r.id);
                  reload();
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.contract, required this.onTap});

  final ReturnContract contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    final today = DateUtils.dateOnly(DateTime.now());
    final overdue = c.endDate.isBefore(today);

    return _Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.contractCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ContractStatusBadge(status: c.contractStatus),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${c.companyName} (${c.companyCode})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 14,
                color: overdue ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  overdue
                      ? 'Quá hạn trả (kết thúc ${DateFormatter.date(c.endDate)})'
                      : 'Kết thúc thuê ${DateFormatter.date(c.endDate)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: overdue ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Còn ${c.outstandingQuantity}/${c.deliveredQuantity} máy',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReturnReceiptCard extends StatelessWidget {
  const ReturnReceiptCard({
    super.key,
    required this.receipt,
    required this.onTap,
  });

  final ReturnReceipt receipt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = receipt;

    return _Card(
      onTap: onTap,
      borderColor: r.isProcessing ? AppColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.returnCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (r.isProcessing)
                _Pill(
                  'Chờ kiểm nhận',
                  AppColors.warning,
                  AppColors.warningLight,
                )
              else
                Text(
                  DateFormatter.dateTime(r.returnedAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${r.contractCode} · ${r.companyName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (r.isCancelledShipment)
                _Pill(
                  'Thu hồi hủy giữa chừng → Bảo dưỡng',
                  AppColors.error,
                  AppColors.errorLight,
                ),
              if (r.isDefectiveOnDelivery)
                _Pill(
                  'Thu hồi máy lỗi khi giao → Bảo dưỡng',
                  AppColors.error,
                  AppColors.errorLight,
                ),
              if (r.isIncidentReturn)
                _Pill(
                  'Thu hồi từ sự cố → Bảo dưỡng',
                  AppColors.error,
                  AppColors.errorLight,
                ),
              if (r.isProcessing)
                _Pill(
                  r.isClaimed
                      ? 'Phụ trách: ${r.assignedStorekeeperName ?? 'Tôi'}'
                      : 'Chưa ai tiếp nhận',
                  r.isClaimed ? AppColors.primary : AppColors.warning,
                  r.isClaimed ? AppColors.primaryLight : AppColors.warningLight,
                ),
              _Pill(
                r.isProcessing
                    ? 'Cần kiểm ${r.totalCount} máy'
                    : 'Nhận ${r.returnedCount}',
                r.isProcessing ? AppColors.warning : AppColors.success,
                r.isProcessing ? AppColors.warningLight : AppColors.successLight,
              ),
              if (!r.isProcessing && r.damagedCount > 0)
                _Pill(
                  'Hỏng ${r.damagedCount}',
                  AppColors.warning,
                  AppColors.warningLight,
                ),
              if (!r.isProcessing && r.missingCount > 0)
                _Pill(
                  'Thất lạc ${r.missingCount}',
                  AppColors.error,
                  AppColors.errorLight,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.foreground, this.background);

  final String text;
  final Color foreground, background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.onTap, this.borderColor});

  final Widget child;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
