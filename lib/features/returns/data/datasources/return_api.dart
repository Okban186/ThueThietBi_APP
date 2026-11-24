import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/return_receipt.dart';

/// Gọi API nhận trả thiết bị (`/api/equipment-returns`): kỹ thuật viên thu hồi
/// máy về kho, thủ kho kiểm từng serial và lập phiếu.
class ReturnApi {
  ReturnApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ReturnContract>> getContracts() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/equipment-returns/contracts',
    );

    return response.data!
        .map((e) => ReturnContract.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReturnContractDetail> getContract(String contractId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/equipment-returns/contracts/$contractId',
    );

    return ReturnContractDetail.fromJson(response.data!);
  }

  Future<List<ReturnReceipt>> getReturns() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/equipment-returns',
    );

    return response.data!
        .map((e) => ReturnReceipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReturnReceiptDetail> getReturn(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/equipment-returns/$id',
    );

    return ReturnReceiptDetail.fromJson(response.data!);
  }

  Future<ReturnReceiptDetail> create(
    String contractId,
    List<ReturnCheckInput> items, {
    String? note,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/equipment-returns',
      data: {
        'rentalContractId': contractId,
        'note': note,
        'items': [for (final item in items) item.toJson()],
      },
    );

    return ReturnReceiptDetail.fromJson(response.data!);
  }
}
