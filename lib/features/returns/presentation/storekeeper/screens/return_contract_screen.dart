import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/return_api.dart';
import '../../../data/models/return_receipt.dart';
import 'return_detail_screen.dart';
import 'return_form_screen.dart';
import 'return_list_view.dart';

/// Máy của một hợp đồng đang ở chỗ khách và các phiếu nhận trả đã lập.
class ReturnContractScreen extends StatefulWidget {
  const ReturnContractScreen({
    super.key,
    required this.api,
    required this.contractId,
  });

  final ReturnApi api;
  final String contractId;

  static Future<void> open(
    BuildContext context,
    ReturnApi api,
    String contractId,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReturnContractScreen(api: api, contractId: contractId),
      ),
    );
  }

  @override
  State<ReturnContractScreen> createState() => _ReturnContractScreenState();
}

class _ReturnContractScreenState extends State<ReturnContractScreen> {
  ReturnContractDetail? _detail;
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

  Future<void> _createReceipt(ReturnContractDetail detail) async {
    final created = await ReturnFormScreen.open(
      context,
      api: widget.api,
      detail: detail,
    );

    if (created != null && mounted) {
      await ReturnDetailScreen.open(context, widget.api, created.receipt.id);
    }

    _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.contract.contractCode ?? 'Nhận trả',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(detail),
      bottomNavigationBar: detail == null || detail.outstanding.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton.icon(
                  onPressed: () => _createReceipt(detail),
                  icon: const Icon(Icons.move_to_inbox_rounded),
                  label: const Text('Lập phiếu nhận trả'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(ReturnContractDetail? detail) {
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
    final byModel = <String, List<OutstandingEquipment>>{};
    for (final e in detail.outstanding) {
      byModel.putIfAbsent(e.modelName, () => []).add(e);
    }

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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Thuê ${DateFormatter.dateRange(c.startDate, c.endDate)} · Đã giao ${c.deliveredQuantity} máy',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Máy đang ở chỗ khách (${detail.outstanding.length})',
            child: detail.outstanding.isEmpty
                ? const Text(
                    'Đã nhận lại toàn bộ máy.',
                    style: TextStyle(color: AppColors.success),
                  )
                : Column(
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in entry.value)
                              Chip(
                                label: Text(e.serialNumber),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: AppColors.border),
                                backgroundColor: AppColors.surfaceSecondary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          if (detail.returns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Phiếu nhận trả (${detail.returns.length})',
              child: Column(
                children: [
                  for (final r in detail.returns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ReturnReceiptCard(
                        receipt: r,
                        onTap: () =>
                            ReturnDetailScreen.open(context, widget.api, r.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
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
            const SizedBox(height: AppSpacing.xs),
          ],
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}
