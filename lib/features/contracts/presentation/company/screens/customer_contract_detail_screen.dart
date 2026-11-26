import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/dashboard/data/datasources/customer_portal_api.dart';
import 'package:thuethietbi_app/features/handovers/data/models/handover_preparation.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/utils/pdf_opener.dart';

import '../../../data/datasources/payment_api.dart';
import '../../../data/models/contract_billing.dart';
import '../../../data/models/rental_contract.dart';
import '../../common/widgets/contract_status_badge.dart';
import '../../common/widgets/contract_status_timeline.dart';
import '../../common/widgets/vnpay_qr_sheet.dart';

/// Chi tiết hợp đồng cho khách hàng doanh nghiệp (COMPANY):
/// - Tổng quan chi phí, đặt cọc, tổng còn phải thanh toán.
/// - Các đợt thanh toán tiền thuê (Ngắn hạn 1 đợt / Dài hạn chu kỳ 30 ngày) kèm thanh toán VNPAY QR.
/// - Các khoản phạt & bồi thường (`rental_charges`, `incident_charges`) kèm thanh toán VNPAY QR.
/// - Lịch sử giao dịch thanh toán, thiết bị, giao hàng, văn bản PDF.
/// - Tiến trình / Lịch sử trạng thái đồng bộ với Sales & Manager (`ContractStatusTimeline`).
class CustomerContractDetailScreen extends StatefulWidget {
  const CustomerContractDetailScreen({
    super.key,
    required this.api,
    required this.contractId,
  });

  final CustomerPortalApi api;
  final String contractId;

  static Future<void> open(
    BuildContext context,
    CustomerPortalApi api,
    String contractId,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerContractDetailScreen(api: api, contractId: contractId),
      ),
    );
  }

  @override
  State<CustomerContractDetailScreen> createState() =>
      _CustomerContractDetailScreenState();
}

class _CustomerContractDetailScreenState
    extends State<CustomerContractDetailScreen> {
  RentalContract? _contract;
  List<HandoverDetail>? _handovers;
  ContractBillingSummary? _billing;

  bool _isLoading = true;
  bool _isOpeningPdf = false;
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
      final contract = await widget.api.getContract(widget.contractId);
      if (mounted) setState(() => _contract = contract);

      await Future.wait([
        widget.api
            .getHandovers(widget.contractId)
            .then((value) {
              if (mounted) setState(() => _handovers = value);
            })
            .catchError((_) {}),
        widget.api
            .getBilling(widget.contractId)
            .then((value) {
              if (mounted) setState(() => _billing = value);
            })
            .catchError((_) {}),
      ]);
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

  Future<void> _open(String fileName, Future<Uint8List> Function() load) async {
    setState(() => _isOpeningPdf = true);
    final error = await openPdf(fileName, load);
    if (!mounted) return;
    setState(() => _isOpeningPdf = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _payWithVnpay({
    required String title,
    required PaymentTargetType targetType,
    String? rentalChargeId,
    String? incidentChargeId,
  }) async {
    final paymentApi = PaymentApi(context.read<ApiClient>());
    final paid = await VnpayQrSheet.open(
      context,
      api: paymentApi,
      contractId: widget.contractId,
      title: title,
      targetType: targetType,
      rentalChargeId: rentalChargeId,
      incidentChargeId: incidentChargeId,
    );

    if (!mounted) return;
    // Reload lại dữ liệu tài chính dù khách vừa thanh toán xong hay mới hủy mã.
    await _load();
    if (paid && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đã ghi nhận thanh toán thành công!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
    }
  }

  bool _canPayContract(RentalContractStatus status) => switch (status) {
    RentalContractStatus.signed ||
    RentalContractStatus.preparing ||
    RentalContractStatus.partiallyDelivered ||
    RentalContractStatus.delivered ||
    RentalContractStatus.completed ||
    RentalContractStatus.expired ||
    RentalContractStatus.cancellationRequested => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final contract = _contract;
    final canExport =
        contract != null && contract.status != RentalContractStatus.cancelled;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          contract?.contractCode ?? 'Hợp đồng',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canExport)
            IconButton(
              tooltip: 'Xem hợp đồng PDF',
              onPressed: _isOpeningPdf
                  ? null
                  : () => _open(
                      '${contract.contractCode}.pdf',
                      () => widget.api.exportPdf(contract.id),
                    ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
        bottom: _isOpeningPdf
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(contract),
    );
  }

  Widget _buildBody(RentalContract? contract) {
    if (contract == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contract?.detail == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final c = contract!;
    final detail = c.detail!;
    final billing = _billing;
    final canPay = _canPayContract(c.status);

    final itemsTotal =
        billing?.equipmentRentalTotal ??
        detail.items.fold<double>(0, (s, i) => s + i.amount);
    final servicesTotal =
        billing?.servicesTotal ??
        detail.services
            .where((s) => s.isCharged)
            .fold<double>(0, (sum, s) => sum + s.total);
    final depositRequired =
        billing?.depositRequiredAmount ?? c.depositRequiredAmount;
    final depositPaid = billing?.depositPaidAmount ?? c.depositPaidAmount;
    final depositRemaining =
        billing?.depositRemainingAmount ??
        (depositRequired - depositPaid).clamp(0.0, double.infinity);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 1. Tiêu đề + Tổng quan chi phí
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
                    ContractStatusBadge(status: c.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  CurrencyFormatter.vnd(c.contractTotalAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                _InfoRow(
                  'Tiền thuê thiết bị',
                  CurrencyFormatter.vnd(itemsTotal),
                ),
                _InfoRow(
                  'Phí vận chuyển / dịch vụ',
                  servicesTotal == 0
                      ? 'Miễn phí (0 đ)'
                      : CurrencyFormatter.vnd(servicesTotal),
                ),
                _InfoRow(
                  'Tiền cọc yêu cầu',
                  CurrencyFormatter.vnd(depositRequired),
                ),
                _InfoRow(
                  'Tiền cọc đã đóng',
                  CurrencyFormatter.vnd(depositPaid),
                  valueColor: depositPaid >= depositRequired &&
                          depositRequired > 0
                      ? AppColors.success
                      : null,
                ),
                if (billing != null && billing.depositAppliedAmount > 0)
                  _InfoRow(
                    'Cọc đã cấn trừ',
                    CurrencyFormatter.vnd(billing.depositAppliedAmount),
                  ),
                if (billing != null && billing.depositRefundedAmount > 0)
                  _InfoRow(
                    'Cọc đã hoàn lại',
                    CurrencyFormatter.vnd(billing.depositRefundedAmount),
                  ),
                if (billing != null) ...[
                  const Divider(),
                  _InfoRow(
                    'Tổng còn phải thanh toán',
                    CurrencyFormatter.vnd(billing.totalOutstandingAmount),
                    bold: true,
                    valueColor: billing.totalOutstandingAmount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ],
                if (depositRequired > 0 && depositRemaining > 0 && canPay) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DepositActionCard(
                    remainingAmount: depositRemaining,
                    hasPendingCash: billing?.hasPendingCashDeposit ?? false,
                    onPayQr: () => _payWithVnpay(
                      title: 'Tiền đặt cọc · ${c.contractCode}',
                      targetType: PaymentTargetType.deposit,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_statusHint(c.status) case final hint?) ...[
            const SizedBox(height: AppSpacing.md),
            _Banner(text: hint),
          ],

          // 2. Lịch / Các đợt thanh toán tiền thuê
          if (billing != null && billing.installments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title:
                  'Các đợt thanh toán tiền thuê (${billing.installments.length} đợt)',
              subtitle: c.rentalType == RentalType.longTerm
                  ? 'Hợp đồng dài hạn · Chu kỳ 30 ngày/đợt (đợt 1 gộp phí vận chuyển).'
                  : 'Hợp đồng ngắn hạn · Thanh toán đủ trong 1 đợt.',
              child: Column(
                children: [
                  for (var i = 0; i < billing.installments.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    _InstallmentCard(
                      item: billing.installments[i],
                      canPay: canPay,
                      onPayQr: () => _payWithVnpay(
                        title:
                            '${billing.installments[i].description} · ${c.contractCode}',
                        targetType: PaymentTargetType.rentalInstallment,
                        rentalChargeId: billing.installments[i].id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 3. Các khoản phạt & bồi thường phát sinh
          if (billing != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: billing.penalties.isEmpty
                  ? 'Khoản phạt & bồi thường'
                  : 'Khoản phạt & bồi thường (${billing.penalties.length})',
              child: billing.penalties.isEmpty
                  ? const Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: AppColors.success,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Chưa có khoản phạt hay bồi thường phát sinh.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < billing.penalties.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.sm),
                          _PenaltyCard(
                            penalty: billing.penalties[i],
                            canPay: canPay,
                            onPayQr: () {
                              final p = billing.penalties[i];
                              final targetType =
                                  p.sourceKind == 'INCIDENT_CHARGE' &&
                                      p.rentalChargeId == null
                                  ? PaymentTargetType.incidentCharge
                                  : PaymentTargetType.charge;
                              _payWithVnpay(
                                title:
                                    '${p.chargeTypeLabel} · ${c.contractCode}',
                                targetType: targetType,
                                rentalChargeId: p.rentalChargeId,
                                incidentChargeId: p.incidentChargeId,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ],

          // 4. Lịch sử giao dịch thanh toán
          if (billing != null && billing.transactions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Lịch sử giao dịch (${billing.transactions.length})',
              child: Column(
                children: [
                  for (var i = 0; i < billing.transactions.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _TransactionRow(txn: billing.transactions[i]),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Thông tin thuê',
            child: Column(
              children: [
                _InfoRow(
                  'Thời gian',
                  '${DateFormatter.dateRange(c.startDate, c.endDate)} (${c.rentalDays} ngày)',
                ),
                _InfoRow('Loại thuê', c.rentalType.label),
                _InfoRow('Địa chỉ giao', detail.deliveryAddress),
                _InfoRow('Ghi chú giao', detail.deliveryNote),
                _InfoRow('Ghi chú', detail.note),
                _InfoRow('Nhân viên phụ trách', c.createdByName),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Thiết bị & Vận chuyển',
            child: Column(
              children: [
                for (final item in detail.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.equipmentModelName} × ${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${CurrencyFormatter.vnd(item.agreedUnitPrice)}/${item.billingUnit.unitLabel} × ${item.billableUnits} ${item.billingUnit.unitLabel}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.vnd(item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                for (final service in detail.services)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${service.serviceType.label} (${service.providedBy.label})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (service.note != null &&
                                  service.note!.isNotEmpty)
                                Text(
                                  service.note!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          service.isCharged
                              ? (service.total == 0
                                    ? 'Miễn phí'
                                    : CurrencyFormatter.vnd(service.total))
                              : 'Không tính',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (_handovers case final handovers? when handovers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Giao hàng (${handovers.length} đợt)',
              child: Column(
                children: [
                  for (final h in handovers) _DeliveryTile(delivery: h),
                ],
              ),
            ),
          ],

          if (detail.representative != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Người đại diện ký',
              child: Column(
                children: [
                  _InfoRow('Họ tên', detail.representative!.fullName),
                  _InfoRow(
                    'Tư cách',
                    detail.representative!.representativeType.label,
                  ),
                  _InfoRow('Điện thoại', detail.representative!.phone),
                  _InfoRow('Email', detail.representative!.email),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Văn bản hợp đồng',
            child: Column(
              children: [
                if (c.status != RentalContractStatus.cancelled)
                  _FileTile(
                    title: '${c.contractCode}.pdf',
                    subtitle: 'Bản hợp đồng theo mẫu để in và ký',
                    onTap: _isOpeningPdf
                        ? null
                        : () => _open(
                            '${c.contractCode}.pdf',
                            () => widget.api.exportPdf(c.id),
                          ),
                  ),
                if (detail.signedContractUrl != null)
                  _FileTile(
                    title: '${c.contractCode}_da_ky.pdf',
                    subtitle: detail.signedAt == null
                        ? 'Bản đã ký hai bên'
                        : 'Bản đã ký · ${DateFormatter.dateTime(detail.signedAt!)}',
                    onTap: _isOpeningPdf
                        ? null
                        : () => _open(
                            '${c.contractCode}_da_ky.pdf',
                            () => widget.api.downloadFile(
                              detail.signedContractUrl!,
                            ),
                          ),
                  ),
              ],
            ),
          ),

          if (detail.statusHistory.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Tiến trình hợp đồng',
              child: ContractStatusTimeline(
                history: detail.statusHistory,
                showActor: false,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// Gợi ý việc khách cần làm / đang chờ theo trạng thái hợp đồng.
  String? _statusHint(RentalContractStatus status) => switch (status) {
    RentalContractStatus.pendingSignature =>
      'Hợp đồng đã được duyệt. Vui lòng xem bản PDF, ký và gửi lại cho nhân viên kinh doanh.',
    RentalContractStatus.signed =>
      'Hợp đồng đã ký. Vui lòng hoàn tất tiền đặt cọc để kho duyệt xuất và bàn giao thiết bị.',
    RentalContractStatus.preparing =>
      'Kho đang chuẩn bị thiết bị để giao cho quý khách.',
    RentalContractStatus.partiallyDelivered =>
      'Một phần thiết bị đã được giao, phần còn lại đang được chuẩn bị.',
    _ => null,
  };
}

class _DepositActionCard extends StatelessWidget {
  const _DepositActionCard({
    required this.remainingAmount,
    required this.hasPendingCash,
    required this.onPayQr,
  });

  final double remainingAmount;
  final bool hasPendingCash;
  final VoidCallback onPayQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Cọc còn phải đóng: ${CurrencyFormatter.vnd(remainingAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (hasPendingCash) ...[
            const SizedBox(height: 4),
            const Text(
              'Đã có phiếu thu tiền mặt đang chờ Quản lý xác nhận.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onPayQr,
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Thanh toán đặt cọc (VNPAY QR)'),
          ),
        ],
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({
    required this.item,
    required this.canPay,
    required this.onPayQr,
  });

  final ContractInstallment item;
  final bool canPay;
  final VoidCallback onPayQr;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (item.status.toUpperCase()) {
      'PAID' => (AppColors.success, AppColors.successLight),
      'PARTIALLY_PAID' => (AppColors.warning, AppColors.warningLight),
      'WAIVED' => (AppColors.info, AppColors.infoLight),
      _ => (AppColors.error, AppColors.errorLight),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(label: item.statusLabel, fg: fg, bg: bg),
            ],
          ),
          const SizedBox(height: 6),
          if (item.periodStart != null && item.periodEnd != null)
            Text(
              'Kỳ: ${DateFormatter.dateRange(item.periodStart!, item.periodEnd!)}'
              '${item.dueDate != null ? ' · Hạn: ${DateFormatter.date(item.dueDate!)}' : ''}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.note!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.vnd(item.amount),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (item.paidAmount > 0 && !item.isPaid)
                      Text(
                        'Đã đóng ${CurrencyFormatter.vnd(item.paidAmount)} · Còn ${CurrencyFormatter.vnd(item.remainingAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (item.hasPendingCash)
                      const Text(
                        'Có phiếu thu tiền mặt chờ duyệt',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.isPayable && canPay)
                FilledButton.tonalIcon(
                  onPressed: onPayQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Thanh toán'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PenaltyCard extends StatelessWidget {
  const _PenaltyCard({
    required this.penalty,
    required this.canPay,
    required this.onPayQr,
  });

  final ContractPenalty penalty;
  final bool canPay;
  final VoidCallback onPayQr;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (penalty.status.toUpperCase()) {
      'PAID' || 'CHARGED' => (AppColors.success, AppColors.successLight),
      'PARTIALLY_PAID' => (AppColors.warning, AppColors.warningLight),
      'WAIVED' => (AppColors.info, AppColors.infoLight),
      _ => (AppColors.error, AppColors.errorLight),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  penalty.chargeTypeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(label: penalty.statusLabel, fg: fg, bg: bg),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            penalty.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          if (penalty.incidentCode != null || penalty.serialNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (penalty.incidentCode != null)
                  'Sự cố ${penalty.incidentCode}',
                if (penalty.serialNumber != null)
                  'Serial ${penalty.serialNumber}',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (penalty.isOffsetByDeposit) ...[
            const SizedBox(height: 6),
            const _SmallPill(
              label: 'Đã cấn trừ vào tiền cọc',
              fg: AppColors.info,
              bg: AppColors.infoLight,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.vnd(penalty.amount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                    if (penalty.paidAmount > 0 && penalty.remainingAmount > 0)
                      Text(
                        'Đã đóng ${CurrencyFormatter.vnd(penalty.paidAmount)} · Còn ${CurrencyFormatter.vnd(penalty.remainingAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (penalty.isPayable && canPay)
                FilledButton.tonalIcon(
                  onPressed: onPayQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Thanh toán'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.txn});

  final PaymentTransaction txn;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (txn.status) {
      PaymentTransactionStatus.verified => (
        AppColors.success,
        AppColors.successLight,
      ),
      PaymentTransactionStatus.pending => (
        AppColors.warning,
        AppColors.warningLight,
      ),
      PaymentTransactionStatus.cancelled ||
      PaymentTransactionStatus.expired ||
      PaymentTransactionStatus.failed => (
        AppColors.error,
        AppColors.errorLight,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          txn.paymentMethod == PaymentMethod.vnpay
              ? Icons.qr_code_2_rounded
              : Icons.payments_outlined,
          size: 20,
          color: fg,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                txn.orderInfo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${txn.paymentMethod.label} · ${txn.txnRef} · ${DateFormatter.dateTime(txn.createdAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.vnd(txn.amount),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 3),
            _SmallPill(label: txn.status.label, fg: fg, bg: bg),
          ],
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title, this.subtitle});

  final String? title;
  final String? subtitle;
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
    this.label,
    this.value, {
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String? value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
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
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.info, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.picture_as_pdf_rounded,
        color: AppColors.error,
        size: 32,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: onTap,
    );
  }
}

/// Một đợt giao: mã phiếu, ngày giao, trạng thái theo cách khách hiểu, các serial.
class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery});

  final HandoverDetail delivery;

  @override
  Widget build(BuildContext context) {
    final h = delivery.handover;
    final (label, color, icon) = switch (h.status) {
      HandoverStatus.completed => (
        'Đã giao',
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      HandoverStatus.shipping => (
        'Đang giao',
        AppColors.info,
        Icons.local_shipping_rounded,
      ),
      HandoverStatus.pendingApproval => (
        'Chờ xuất kho',
        AppColors.warning,
        Icons.inventory_rounded,
      ),
      _ => (
        'Kho đang chuẩn bị',
        AppColors.textSecondary,
        Icons.inventory_2_outlined,
      ),
    };

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        leading: Icon(icon, color: color),
        title: Text(
          '${h.handoverCode} · ${delivery.items.length} máy',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$label · ${h.status == HandoverStatus.completed ? 'Ngày giao' : 'Dự kiến'} ${DateFormatter.date(h.handoverDate)}',
          style: TextStyle(color: color, fontSize: 12.5),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Người nhận: ${h.receivedByName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final line in delivery.items)
                  Chip(
                    label: Text(line.serialNumber),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: AppColors.surfaceSecondary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
