import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import '../../../data/datasources/payment_api.dart';
import '../../../data/models/contract_billing.dart';

/// Màn hình thanh toán VNPAY Sandbox bằng mã QR (vẽ trực tiếp từ `paymentUrl`
/// bằng `qr_flutter`, không dùng WebView):
/// - Đồng hồ đếm ngược 15 phút theo `expiresAt`; hết giờ tự khóa QR và cho tạo mã mới.
/// - Polling trạng thái mỗi 4 giây để tự động cập nhật khi IPN/ReturnUrl xác nhận.
/// - Nút "Chia sẻ / Lưu ảnh QR" và "Mở trang thanh toán VNPAY" (trình duyệt ngoài).
/// - Nút "Hủy giao dịch" cập nhật `CANCELLED` trên Backend.
class VnpayQrSheet extends StatefulWidget {
  const VnpayQrSheet({
    super.key,
    required this.api,
    required this.contractId,
    required this.title,
    required this.targetType,
    this.rentalChargeId,
    this.incidentChargeId,
  });

  final PaymentApi api;
  final String contractId;
  final String title;
  final PaymentTargetType targetType;
  final String? rentalChargeId;
  final String? incidentChargeId;

  /// Trả về `true` nếu giao dịch đã được xác nhận thanh toán thành công (`VERIFIED`).
  static Future<bool> open(
    BuildContext context, {
    required PaymentApi api,
    required String contractId,
    required String title,
    required PaymentTargetType targetType,
    String? rentalChargeId,
    String? incidentChargeId,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VnpayQrSheet(
        api: api,
        contractId: contractId,
        title: title,
        targetType: targetType,
        rentalChargeId: rentalChargeId,
        incidentChargeId: incidentChargeId,
      ),
    );
    return result ?? false;
  }

  @override
  State<VnpayQrSheet> createState() => _VnpayQrSheetState();
}

class _VnpayQrSheetState extends State<VnpayQrSheet> {
  final _qrBoundaryKey = GlobalKey();

  PaymentTransaction? _transaction;
  bool _isCreating = true;
  bool _isBusyAction = false;
  String? _error;

  Timer? _countdownTimer;
  Timer? _pollTimer;
  Duration _remaining = Duration.zero;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _createPayment() async {
    _stopTimers();
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final txn = await widget.api.createVnpayPayment(
        rentalContractId: widget.contractId,
        targetType: widget.targetType,
        rentalChargeId: widget.rentalChargeId,
        incidentChargeId: widget.incidentChargeId,
      );
      if (!mounted) return;
      setState(() {
        _transaction = txn;
        _isCreating = false;
      });
      _startCountdownAndPolling(txn);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = apiErrorMessage(
          error,
          fallback: 'Không tạo được mã thanh toán VNPAY.',
        );
      });
    }
  }

  void _startCountdownAndPolling(PaymentTransaction txn) {
    _stopTimers();
    if (txn.status != PaymentTransactionStatus.pending) return;

    void updateRemaining() {
      if (!mounted) return;
      final expiresAt = txn.expiresAt;
      if (expiresAt == null) return;

      final diff = expiresAt.difference(DateTime.now());
      if (diff.isNegative || diff.inSeconds <= 0) {
        _stopTimers();
        setState(() {
          _remaining = Duration.zero;
          _transaction = PaymentTransaction(
            id: txn.id,
            rentalContractId: txn.rentalContractId,
            contractCode: txn.contractCode,
            rentalChargeId: txn.rentalChargeId,
            incidentChargeId: txn.incidentChargeId,
            targetType: txn.targetType,
            paymentMethod: txn.paymentMethod,
            txnRef: txn.txnRef,
            amount: txn.amount,
            orderInfo: txn.orderInfo,
            status: PaymentTransactionStatus.expired,
            paymentUrl: txn.paymentUrl,
            expiresAt: txn.expiresAt,
            createdAt: txn.createdAt,
          );
        });
        // Đồng bộ trạng thái EXPIRED về Backend.
        widget.api.getStatus(txn.id).catchError((_) => txn);
        return;
      }

      setState(() => _remaining = diff);
    }

    updateRemaining();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateRemaining(),
    );

    // Polling mỗi 4 giây kiểm tra IPN/ReturnUrl đã xác nhận giao dịch chưa.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollStatus(),
    );
  }

  Future<void> _pollStatus() async {
    final current = _transaction;
    if (current == null ||
        _isPolling ||
        current.status != PaymentTransactionStatus.pending) {
      return;
    }

    _isPolling = true;
    try {
      final latest = await widget.api.getStatus(current.id);
      if (!mounted) return;

      if (latest.status != PaymentTransactionStatus.pending) {
        _stopTimers();
        setState(() => _transaction = latest);
      }
    } catch (_) {
      // Bỏ qua lỗi mạng tạm thời trong lúc polling.
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _openInBrowser() async {
    final url = _transaction?.paymentUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showToast('Không mở được trình duyệt ngoài.', isError: true);
    }
  }

  Future<void> _shareOrSaveQr() async {
    final txn = _transaction;
    if (txn == null) return;

    setState(() => _isBusyAction = true);
    try {
      if (kIsWeb) {
        final shareText =
            'Thanh toán ${widget.title}\nSố tiền: ${CurrencyFormatter.vnd(txn.amount)}\nNội dung: ${txn.orderInfo}\nLink VNPAY: ${txn.paymentUrl ?? ''}';
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          _showToast('Đã sao chép thông tin & link thanh toán VNPAY.');
        }
        return;
      }

      final boundary =
          _qrBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showToast('Không chụp được ảnh mã QR.', isError: true);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}${Platform.pathSeparator}VNPAY_${txn.txnRef}.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'Thanh toán ${widget.title}\nSố tiền: ${CurrencyFormatter.vnd(txn.amount)}\nNội dung: ${txn.orderInfo}\nLink VNPAY: ${txn.paymentUrl ?? ''}',
          subject: 'Mã QR thanh toán VNPAY - ${txn.txnRef}',
        ),
      );
    } catch (error) {
      if (mounted) {
        _showToast('Không thể chia sẻ / lưu ảnh QR.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusyAction = false);
    }
  }

  Future<void> _cancelTransaction() async {
    final txn = _transaction;
    if (txn == null) {
      Navigator.of(context).pop(false);
      return;
    }

    if (txn.status != PaymentTransactionStatus.pending) {
      Navigator.of(context).pop(txn.status == PaymentTransactionStatus.verified);
      return;
    }

    setState(() => _isBusyAction = true);
    try {
      await widget.api.cancel(txn.id);
      _stopTimers();
      if (mounted) Navigator.of(context).pop(false);
    } catch (error) {
      if (mounted) {
        _showToast(
          apiErrorMessage(error, fallback: 'Không hủy được giao dịch.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusyAction = false);
    }
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showToast('Đã sao chép $label.');
  }

  void _showToast(String message, {bool isError = false}) {
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

  String _formatCountdown(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 99 * 60);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final txn = _transaction;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thanh toán VNPAY QR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(
                    txn?.status == PaymentTransactionStatus.verified,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isCreating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Đang khởi tạo mã thanh toán VNPAY...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else if (_error != null)
              _buildErrorState(_error!)
            else if (txn != null)
              _buildTransactionContent(txn),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _createPayment,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionContent(PaymentTransaction txn) {
    if (txn.status == PaymentTransactionStatus.verified) {
      return _buildSuccessState(txn);
    }

    final isPending = txn.status == PaymentTransactionStatus.pending;
    final isExpired = txn.status == PaymentTransactionStatus.expired;
    final isCancelled = txn.status == PaymentTransactionStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Đồng hồ đếm ngược / trạng thái
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isPending ? AppColors.warningLight : AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          ),
          child: Row(
            children: [
              Icon(
                isPending
                    ? Icons.timer_outlined
                    : isExpired
                    ? Icons.timer_off_outlined
                    : Icons.cancel_outlined,
                size: 18,
                color: isPending ? AppColors.warning : AppColors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isPending
                      ? 'Mã QR có hiệu lực trong ${_formatCountdown(_remaining)} · Tự động cập nhật khi thanh toán xong'
                      : isExpired
                      ? 'Mã thanh toán đã hết hạn (quá 15 phút).'
                      : isCancelled
                      ? 'Giao dịch đã bị hủy trên cổng VNPAY.'
                      : 'Giao dịch thanh toán không thành công.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isPending ? AppColors.warning : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Thẻ mã QR có thể chụp/chia sẻ qua RepaintBoundary
        RepaintBoundary(
          key: _qrBoundaryKey,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  CurrencyFormatter.vnd(txn.amount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  txn.orderInfo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isPending ? 1.0 : 0.18,
                      child: QrImageView(
                        data: txn.paymentUrl ?? txn.txnRef,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.textPrimary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isExpired
                              ? 'ĐÃ HẾT HẠN'
                              : isCancelled
                              ? 'ĐÃ HỦY'
                              : 'THẤT BẠI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Quét bằng Camera hoặc Zalo để mở trang thanh toán VNPAY',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Thông tin đối soát + sao chép
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _CopyRow(
                label: 'Mã giao dịch',
                value: txn.txnRef,
                onCopy: () => _copyText('mã giao dịch', txn.txnRef),
              ),
              const Divider(height: 14),
              _CopyRow(
                label: 'Nội dung',
                value: txn.orderInfo,
                onCopy: () => _copyText('nội dung thanh toán', txn.orderInfo),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (isPending) ...[
          FilledButton.icon(
            onPressed: _isBusyAction ? null : _openInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Mở trang thanh toán VNPAY'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusyAction ? null : _shareOrSaveQr,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Chia sẻ / Lưu QR'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: _isBusyAction ? null : _cancelTransaction,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Hủy giao dịch'),
                ),
              ),
            ],
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _createPayment,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Tạo mã thanh toán mới'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Đóng'),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessState(PaymentTransaction txn) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 56,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Thanh toán thành công!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CurrencyFormatter.vnd(txn.amount),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mã GD: ${txn.txnRef}'
            '${txn.vnpBankCode != null ? ' · Ngân hàng ${txn.vnpBankCode}' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hoàn tất'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label, value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sao chép',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
      ],
    );
  }
}
