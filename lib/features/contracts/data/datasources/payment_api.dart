import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

import '../models/contract_billing.dart';

/// Gọi API thanh toán VNPAY Sandbox (QR + polling + hủy) và thu tiền mặt tại `/api/payments`.
class PaymentApi {
  PaymentApi(this._apiClient, {CloudinaryUploader? uploader})
    : _uploader = uploader ?? CloudinaryUploader();

  final ApiClient _apiClient;
  final CloudinaryUploader _uploader;

  /// Tạo giao dịch VNPAY mới với `vnp_TxnRef` duy nhất và hạn 15 phút.
  Future<PaymentTransaction> createVnpayPayment({
    required String rentalContractId,
    required PaymentTargetType targetType,
    String? rentalChargeId,
    String? incidentChargeId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/payments/vnpay/create',
      data: {
        'rentalContractId': rentalContractId,
        'targetType': targetType.code,
        if (rentalChargeId != null) 'rentalChargeId': rentalChargeId,
        if (incidentChargeId != null) 'incidentChargeId': incidentChargeId,
      },
    );

    return PaymentTransaction.fromJson(response.data!);
  }

  /// Kiểm tra trạng thái giao dịch (dùng cho polling mỗi 3–5 giây).
  Future<PaymentTransaction> getStatus(String transactionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/payments/$transactionId/status',
    );

    return PaymentTransaction.fromJson(response.data!);
  }

  /// Hủy giao dịch VNPAY đang chờ ngay trên app.
  Future<PaymentTransaction> cancel(String transactionId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/payments/$transactionId/cancel',
    );

    return PaymentTransaction.fromJson(response.data!);
  }

  /// Upload ảnh biên bản / phiếu thu tiền mặt lên Cloudinary và trả về `storageFileId`.
  Future<String> uploadCashReceiptImage(String filePath) async {
    final ticketRes = await _apiClient.post<Map<String, dynamic>>(
      '/api/payments/cash/upload-ticket',
    );
    final ticket = UploadTicket.fromJson(ticketRes.data!);
    if (ticket.uploads.isEmpty) {
      throw Exception('Không nhận được vé upload ảnh phiếu thu.');
    }

    final slot = ticket.uploads.first;
    await _uploader.upload(
      apiKey: ticket.apiKey,
      slot: slot,
      filePath: filePath,
      fileName: filePath.split(RegExp(r'[\\/]')).last,
    );

    final confirmRes = await _apiClient.post<Map<String, dynamic>>(
      '/api/payments/cash/confirm-upload',
      data: {
        'sessionIds': [slot.sessionId],
      },
    );

    final results = (confirmRes.data!['results'] as List<dynamic>)
        .map((e) => ConfirmedUpload.fromJson(e as Map<String, dynamic>))
        .toList();

    final ok = results.firstOrNull;
    if (ok == null || !ok.success || ok.storageFileId == null) {
      throw Exception(ok?.message ?? 'Không thể xác nhận ảnh phiếu thu.');
    }

    return ok.storageFileId!;
  }

  /// Ghi nhận thu tiền mặt kèm ảnh phiếu thu ký 2 bên (trạng thái PENDING chờ Manager duyệt).
  Future<PaymentTransaction> createCashPayment({
    required String rentalContractId,
    required PaymentTargetType targetType,
    required double amount,
    String? receiptFileId,
    String? rentalChargeId,
    String? incidentChargeId,
    String? note,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/payments/cash',
      data: {
        'rentalContractId': rentalContractId,
        'targetType': targetType.code,
        'amount': amount,
        if (receiptFileId != null && receiptFileId.isNotEmpty)
          'receiptFileId': receiptFileId,
        if (rentalChargeId != null) 'rentalChargeId': rentalChargeId,
        if (incidentChargeId != null) 'incidentChargeId': incidentChargeId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return PaymentTransaction.fromJson(response.data!);
  }
}
