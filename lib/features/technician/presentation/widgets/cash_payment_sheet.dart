import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/payment_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/contract_billing.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';

import 'evidence_photo_picker.dart';

/// Bottom sheet thu tiền mặt tại hiện trường cho KTV trưởng (bắt buộc chụp ảnh phiếu thu / biên bản ký 2 bên).
class CashPaymentSheet extends StatefulWidget {
  const CashPaymentSheet({
    super.key,
    required this.paymentApi,
    required this.rentalContractId,
    required this.title,
    required this.suggestedAmount,
    required this.targetType,
    this.rentalChargeId,
  });

  final PaymentApi paymentApi;
  final String rentalContractId;
  final String title;
  final double suggestedAmount;
  final PaymentTargetType targetType;
  final String? rentalChargeId;

  static Future<bool> open(
    BuildContext context, {
    required PaymentApi paymentApi,
    required String rentalContractId,
    required String title,
    required double suggestedAmount,
    required PaymentTargetType targetType,
    String? rentalChargeId,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CashPaymentSheet(
        paymentApi: paymentApi,
        rentalContractId: rentalContractId,
        title: title,
        suggestedAmount: suggestedAmount,
        targetType: targetType,
        rentalChargeId: rentalChargeId,
      ),
    );
    return ok ?? false;
  }

  @override
  State<CashPaymentSheet> createState() => _CashPaymentSheetState();
}

class _CashPaymentSheetState extends State<CashPaymentSheet> {
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  List<String> _receiptPhotos = const [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.suggestedAmount.round().toString(),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(raw) ?? 0;
    if (amount < 1000) {
      _msg('Số tiền thu phải tối thiểu 1.000 đ.', isError: true);
      return;
    }
    if (_receiptPhotos.isEmpty) {
      _msg(
        'Vui lòng chụp ảnh phiếu thu / biên bản ký 2 bên làm minh chứng.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fileId = await widget.paymentApi.uploadCashReceiptImage(
        _receiptPhotos.first,
      );
      await widget.paymentApi.createCashPayment(
        rentalContractId: widget.rentalContractId,
        targetType: widget.targetType,
        rentalChargeId: widget.rentalChargeId,
        amount: amount,
        receiptFileId: fileId,
        note: _noteCtrl.text,
      );
      if (mounted) {
        _msg('Đã ghi nhận thu tiền mặt (chờ Quản lý xác nhận đối soát).');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể ghi nhận thu tiền mặt.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thu tiền mặt tại hiện trường',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '${widget.title} • Cần thu: ${CurrencyFormatter.vnd(widget.suggestedAmount)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số tiền thực thu (VNĐ) *',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú (VD: Người nộp tiền, số phiếu thu giấy...)',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EvidencePhotoPicker(
              title: 'Ảnh phiếu thu / biên bản ký nhận tiền',
              subtitle: 'Bắt buộc 1 ảnh rõ chữ ký hai bên để Quản lý duyệt.',
              filePaths: _receiptPhotos,
              maxPhotos: 1,
              required: true,
              compact: true,
              onChanged: (list) => setState(() => _receiptPhotos = list),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payments_outlined),
              label: const Text('Gửi xác nhận thu tiền mặt'),
            ),
          ],
        ),
      ),
    );
  }
}
