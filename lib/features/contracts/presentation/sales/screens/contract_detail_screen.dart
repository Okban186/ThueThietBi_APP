import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import '../../../data/datasources/payment_api.dart';
import '../../../data/datasources/rental_contract_api.dart';
import '../../../data/models/contract_billing.dart';
import '../../../data/models/rental_contract.dart';
import '../../common/widgets/contract_status_badge.dart';
import '../../common/widgets/contract_status_timeline.dart';
import '../../common/widgets/vnpay_qr_sheet.dart';
import '../../providers/rental_contract_provider.dart';
import 'contract_form_screen.dart';

/// Chi tiết hợp đồng và thao tác của Sales theo trạng thái.
class ContractDetailScreen extends StatefulWidget {
  const ContractDetailScreen({super.key, required this.contractId});

  final String contractId;

  static Future<void> open(BuildContext context, String contractId) {
    final provider = context.read<RentalContractProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: ContractDetailScreen(contractId: contractId),
        ),
      ),
    );
  }

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  ContractBillingSummary? _billing;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildSalesDepositPanel(RentalContract c) {
    final remaining = (c.depositRequiredAmount - c.depositPaidAmount)
        .clamp(0.0, double.infinity);
    final pendingCash = (_billing?.transactions ?? const [])
        .where(
          (t) =>
              t.targetType == PaymentTargetType.deposit &&
              t.paymentMethod == PaymentMethod.cash &&
              t.status == PaymentTransactionStatus.pending,
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            c.status == RentalContractStatus.pendingDeposit
                ? 'Chờ đặt cọc ${CurrencyFormatter.vnd(remaining)} (hạn chót trước ${DateFormatter.date(c.depositDeadline)} — quá hạn hợp đồng tự hủy)'
                : 'Tiền đặt cọc còn thiếu: ${CurrencyFormatter.vnd(remaining)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: AppColors.warning,
            ),
          ),
          if (pendingCash.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final txn in pendingCash)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hóa đơn thu trực tiếp: ${txn.txnRef}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.warning,
                      ),
                    ),
                    Text(
                      'Số tiền: ${CurrencyFormatter.vnd(txn.amount)} • Người thu: ${txn.createdByName ?? 'Sales'} • Đang chờ Quản lý duyệt',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final paid = await VnpayQrSheet.open(
                          context,
                          api: PaymentApi(context.read<ApiClient>()),
                          contractId: c.id,
                          title: 'Đặt cọc ${c.contractCode}',
                          targetType: PaymentTargetType.deposit,
                        );
                        if (paid && mounted) _load();
                      },
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Mã QR VNPAY thu cọc'),
              ),
              if (pendingCash.isEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _openDirectCashDepositDialog(c, remaining),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Đã nhận cọc trực tiếp'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectCashDepositDialog(
    RentalContract c,
    double remainingAmount,
  ) async {
    final amountCtrl = TextEditingController(
      text: remainingAmount.round().toString(),
    );
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đã nhận cọc trực tiếp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hệ thống sẽ tạo 1 hóa đơn thanh toán cọc gắn với tài khoản của bạn (Sales) và gửi lên Quản lý duyệt trước khi chuyển sang chuẩn bị hàng.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền cọc đã nhận (VNĐ) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú hóa đơn (VD: Người nộp, chuyển khoản/tiền mặt...)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tạo hóa đơn thu cọc'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      amountCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    final raw = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(raw) ?? 0;
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();

    if (amount < 1000) {
      _showMessage('Số tiền cọc phải tối thiểu 1.000 đ.', isError: true);
      return;
    }

    await _run(() async {
      final txn = await PaymentApi(context.read<ApiClient>()).createCashPayment(
        rentalContractId: c.id,
        targetType: PaymentTargetType.deposit,
        amount: amount,
        note: note.isEmpty ? 'Sales xác nhận đã nhận tiền cọc trực tiếp' : note,
      );
      await _load();
      if (mounted) {
        _showMessage(
          'Đã tạo hóa đơn thu cọc ${txn.txnRef} (${CurrencyFormatter.vnd(txn.amount)}). Chờ Quản lý duyệt!',
        );
      }
    }, 'Đã ghi nhận hóa đơn thu cọc.');
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await context.read<RentalContractProvider>().loadDetail(
        widget.contractId,
      );
      try {
        final billing = await RentalContractApi(
          context.read<ApiClient>(),
        ).getBilling(widget.contractId);
        if (mounted) _billing = billing;
      } catch (_) {}
    } catch (error) {
      _loadError = apiErrorMessage(error, fallback: 'Không tải được hợp đồng.');
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
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _isSubmitting = true);

    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is UploadFailedException
              ? error.message
              : apiErrorMessage(error),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message,
    String confirmLabel, {
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit(RentalContract contract) async {
    final ok = await _confirm(
      'Gửi duyệt ${contract.contractCode}?',
      'Hợp đồng sẽ chuyển cho quản lý duyệt. Trong lúc chờ duyệt bạn không sửa được hợp đồng.',
      'Gửi duyệt',
    );
    if (!ok || !mounted) return;

    final provider = context.read<RentalContractProvider>();
    await _run(() => provider.submit(contract.id), 'Đã gửi duyệt hợp đồng.');
  }

  /// Giới hạn của Backend cho bản hợp đồng đã ký.
  static const _maxSignedPdfBytes = 10 * 1024 * 1024;

  Future<void> _uploadSigned(RentalContract contract) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null || !mounted) return;

    if (file.extension?.toLowerCase() != 'pdf') {
      _showMessage('Vui lòng chọn file PDF.', isError: true);
      return;
    }

    if (await file.xFile.length() > _maxSignedPdfBytes) {
      if (mounted) _showMessage('File PDF tối đa 10 MB.', isError: true);
      return;
    }
    if (!mounted) return;

    final ok = await _confirm(
      'Tải lên bản đã ký?',
      'File: ${file.name}\n\n'
          'Sau khi tải lên, hợp đồng ${contract.contractCode} chuyển sang '
          '"Đã ký" và không sửa được nữa.',
      'Tải lên',
    );
    if (!ok || !mounted) return;

    final provider = context.read<RentalContractProvider>();
    await _run(() async {
      // File chọn qua bộ chọn hệ thống có thể chưa có đường dẫn thật:
      // khi đó chép vào thư mục tạm để upload.
      var path = file.path;

      if (path == null) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}${Platform.pathSeparator}${file.name}';
        await file.xFile.saveTo(path);
      }

      await provider.markSigned(contract.id, path);
    }, 'Hợp đồng đã chuyển sang "Đã ký".');
  }

  /// Xuất hợp đồng PDF từ mẫu để in và ký.
  Future<void> _exportPdf(RentalContract contract) {
    final api = context.read<RentalContractProvider>().api;

    return _openPdf(
      '${contract.contractCode}.pdf',
      () => api.exportPdf(contract.id),
    );
  }

  /// Mở bản hợp đồng đã ký (PDF lưu trên Cloudinary).
  Future<void> _openSignedPdf(RentalContract contract, String url) {
    final api = context.read<RentalContractProvider>().api;

    return _openPdf(
      '${contract.contractCode}_da_ky.pdf',
      () => api.downloadFile(url),
    );
  }

  /// Tải PDF về thư mục tạm rồi mở bằng ứng dụng đọc PDF của máy
  /// (từ đó có thể in, lưu hoặc chia sẻ).
  Future<void> _openPdf(
    String fileName,
    Future<Uint8List> Function() load,
  ) async {
    setState(() => _isSubmitting = true);

    try {
      final bytes = await load();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path, type: 'application/pdf');

      if (result.type != ResultType.done && mounted) {
        _showMessage(
          'Không mở được file PDF. Hãy cài một ứng dụng đọc PDF (ví dụ Google Drive).',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          apiErrorMessage(error, fallback: 'Không tải được file PDF.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancel(RentalContract contract) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(code: contract.contractCode),
    );
    if (reason == null || !mounted) return;

    final provider = context.read<RentalContractProvider>();
    await _run(
      () =>
          provider.cancel(contract.id, reason: reason.isEmpty ? null : reason),
      'Đã hủy hợp đồng ${contract.contractCode}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final contract = context.watch<RentalContractProvider>().detailOf(
      widget.contractId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          contract?.contractCode ?? 'Hợp đồng',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (contract?.detail != null &&
              contract!.status != RentalContractStatus.cancelled)
            IconButton(
              tooltip: 'Xuất hợp đồng PDF',
              onPressed: _isSubmitting ? null : () => _exportPdf(contract),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
        bottom: _isSubmitting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(contract),
      bottomNavigationBar: contract == null ? null : _buildActions(contract),
    );
  }

  Widget _buildBody(RentalContract? contract) {
    if (contract?.detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contract?.detail == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _loadError,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final c = contract!;
    final detail = c.detail!;
    final itemsTotal = detail.items.fold<double>(0, (s, i) => s + i.amount);
    final servicesTotal = detail.services
        .where((s) => s.isCharged)
        .fold<double>(0, (sum, s) => sum + s.total);

    return AbsorbPointer(
      absorbing: _isSubmitting,
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
                  const SizedBox(height: 4),
                  Text(
                    '${c.companyName ?? ''} (${c.companyCode ?? ''})',
                    style: const TextStyle(color: AppColors.textSecondary),
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
                    'Đặt cọc ${CurrencyFormatter.vnd(c.depositRequiredAmount)}'
                    '${c.depositRequiredAmount > 0 ? ' · Đã đóng ${CurrencyFormatter.vnd(c.depositPaidAmount)}' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (c.status == RentalContractStatus.signed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Đã tải bản hợp đồng ký. Đang chờ Quản lý kiểm tra và duyệt bản ký để mở bước đặt cọc.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                  if (c.status == RentalContractStatus.pendingDeposit ||
                      c.status == RentalContractStatus.preparing ||
                      c.status == RentalContractStatus.partiallyDelivered ||
                      c.status == RentalContractStatus.delivered)
                    if (c.depositRequiredAmount > c.depositPaidAmount) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildSalesDepositPanel(c),
                    ],
                ],
              ),
            ),
            if (c.status == RentalContractStatus.rejected &&
                c.rejectionReason != null) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: AppColors.error,
                background: AppColors.errorLight,
                icon: Icons.report_gmailerrorred_rounded,
                text:
                    'Bị từ chối: ${c.rejectionReason}\nHãy sửa hợp đồng rồi gửi duyệt lại.',
              ),
            ],
            if (!c.canEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: AppColors.info,
                background: AppColors.infoLight,
                icon: Icons.info_outline_rounded,
                text:
                    'Hợp đồng do ${c.createdByName ?? 'nhân viên khác'} tạo. Bạn chỉ có quyền xem.',
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
                  _InfoRow('Phiếu giữ chỗ', c.reservationCode),
                  _InfoRow('Địa chỉ giao', detail.deliveryAddress),
                  _InfoRow('Ghi chú giao', detail.deliveryNote),
                  _InfoRow('Ghi chú', detail.note),
                  _InfoRow('Người tạo', c.createdByName),
                  if (detail.approvedByName != null)
                    _InfoRow(
                      'Người duyệt',
                      '${detail.approvedByName} · ${DateFormatter.dateTime(detail.approvedAt!)}',
                    ),
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (detail.representative != null)
              _Section(
                title: 'Người đại diện ký',
                child: Column(
                  children: [
                    _InfoRow('Họ tên', detail.representative!.fullName),
                    _InfoRow(
                      'Tư cách',
                      detail.representative!.representativeType.label,
                    ),
                    _InfoRow('Số CCCD', detail.representative!.idNumber),
                    _InfoRow('Điện thoại', detail.representative!.phone),
                    _InfoRow('Email', detail.representative!.email),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Giấy tờ',
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.25,
                children: [
                  for (final document in detail.documents)
                    _ImageTile(
                      label: document.kind.label,
                      url: document.url,
                      cacheKey: document.storageFileId,
                    ),
                ],
              ),
            ),
            if (detail.signedContractUrl != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Hợp đồng đã ký',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                  title: Text(
                    '${c.contractCode}_da_ky.pdf',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: detail.signedAt == null
                      ? null
                      : Text(
                          'Ký ngày ${DateFormatter.dateTime(detail.signedAt!)}',
                        ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openSignedPdf(c, detail.signedContractUrl!),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Lịch sử trạng thái',
              child: ContractStatusTimeline(history: detail.statusHistory),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget? _buildActions(RentalContract contract) {
    if (!contract.canEdit || contract.detail == null) return null;

    final buttons = <Widget>[];

    if (contract.isEditable) {
      buttons.addAll([
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : () => _submit(contract),
            icon: const Icon(Icons.send_rounded),
            label: Text(
              contract.status == RentalContractStatus.rejected
                  ? 'Gửi duyệt lại'
                  : 'Gửi duyệt',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.outlined(
          tooltip: 'Sửa hợp đồng',
          onPressed: _isSubmitting
              ? null
              : () => ContractFormScreen.edit(context, contract: contract),
          icon: const Icon(Icons.edit_outlined),
        ),
      ]);
    } else if (contract.status == RentalContractStatus.pendingSignature) {
      buttons.addAll([
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : () => _exportPdf(contract),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Xuất PDF'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : () => _uploadSigned(contract),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Tải bản đã ký'),
          ),
        ),
      ]);
    } else if (contract.status == RentalContractStatus.pendingApproval) {
      buttons.add(
        const Expanded(
          child: Text(
            'Đang chờ quản lý duyệt.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (contract.isCancellable) {
      buttons.addAll([
        const SizedBox(width: AppSpacing.sm),
        IconButton.outlined(
          tooltip: 'Hủy hợp đồng',
          color: AppColors.error,
          onPressed: _isSubmitting ? null : () => _cancel(contract),
          icon: const Icon(Icons.cancel_outlined),
        ),
      ]);
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: buttons),
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
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              child,
            ],
          ),
        ),
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
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value!.isEmpty ? '—' : value!,
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
  const _Banner({
    required this.color,
    required this.background,
    required this.icon,
    required this.text,
  });

  final Color color, background;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.label, required this.url, this.cacheKey});

  final String label;
  final String? url;

  /// URL ảnh có chữ ký thay đổi mỗi lần tải chi tiết; dùng id file làm khóa
  /// cache để ảnh không bị tải lại (nháy trắng) sau mỗi thao tác.
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: url == null
          ? null
          : () => MediaViewerGallery.openImageViewer(
              context,
              url!,
              title: label,
              cacheKey: cacheKey,
            ),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              CachedNetworkImage(
                imageUrl: url!,
                cacheKey: cacheKey,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              )
            else
              const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textDisabled,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.code});

  final String code;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Hủy hợp đồng ${widget.code}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thiết bị giữ cho hợp đồng sẽ được nhả ra. Không thể hoàn tác.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Lý do hủy (không bắt buộc)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Không hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Hủy hợp đồng'),
        ),
      ],
    );
  }
}
