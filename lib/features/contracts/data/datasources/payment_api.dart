import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/contract_billing.dart';

/// Gọi API thanh toán VNPAY Sandbox (QR + polling + hủy) tại `/api/payments`.
class PaymentApi {
  PaymentApi(this._apiClient);

  final ApiClient _apiClient;

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
        'rentalChargeId': ?rentalChargeId,
        'incidentChargeId': ?incidentChargeId,
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
}
