import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/dashboard/data/datasources/customer_portal_api.dart';
import 'package:thuethietbi_app/features/handovers/data/models/handover_preparation.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/utils/pdf_opener.dart';

import '../../../data/models/rental_contract.dart';
import '../../common/widgets/contract_status_badge.dart';

/// Chi tiết hợp đồng cho khách hàng (chỉ xem): thời gian, thiết bị, tiền,
/// người đại diện ký, bản PDF để ký và bản đã ký, các mốc trạng thái.
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

  /// Các đợt giao; null khi chưa tải được (không chặn xem hợp đồng).
  List<HandoverDetail>? _handovers;
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

      try {
        final handovers = await widget.api.getHandovers(widget.contractId);
        if (mounted) setState(() => _handovers = handovers);
      } catch (_) {
        // Không có thông tin giao hàng thì vẫn xem được hợp đồng.
      }
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
    final itemsTotal = detail.items.fold<double>(0, (s, i) => s + i.amount);
    final servicesTotal = detail.services
        .where((s) => s.isCharged)
        .fold<double>(0, (sum, s) => sum + s.total);

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
                Text(
                  'Đặt cọc ${CurrencyFormatter.vnd(c.depositRequiredAmount)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_statusHint(c.status) case final hint?) ...[
            const SizedBox(height: AppSpacing.md),
            _Banner(text: hint),
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
            title: 'Thiết bị',
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
                      children: [
                        Expanded(
                          child: Text(
                            '${service.serviceType.label} (${service.providedBy.label})',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          service.isCharged
                              ? CurrencyFormatter.vnd(service.total)
                              : 'Không tính',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                _InfoRow(
                  'Tiền thuê thiết bị',
                  CurrencyFormatter.vnd(itemsTotal),
                ),
                _InfoRow('Dịch vụ', CurrencyFormatter.vnd(servicesTotal)),
                _InfoRow(
                  'Tổng giá trị',
                  CurrencyFormatter.vnd(c.contractTotalAmount),
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
              title: 'Tiến trình',
              child: Column(
                children: [
                  for (final h in detail.statusHistory.reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.circle,
                        size: 10,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        h.status.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(DateFormatter.dateTime(h.changedAt)),
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

  /// Gợi ý việc khách cần làm / đang chờ theo trạng thái hợp đồng.
  String? _statusHint(RentalContractStatus status) => switch (status) {
    RentalContractStatus.pendingSignature => 'Hợp đồng đã được duyệt. Vui lòng xem bản PDF, ký và gửi lại cho nhân viên kinh doanh.',
    RentalContractStatus.signed =>
      'Hợp đồng đã ký. Kho đang lên kế hoạch chuẩn bị thiết bị.',
    RentalContractStatus.preparing =>
      'Kho đang chuẩn bị thiết bị để giao cho quý khách.',
    RentalContractStatus.partiallyDelivered =>
      'Một phần thiết bị đã được giao, phần còn lại đang được chuẩn bị.',
    _ => null,
  };
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
