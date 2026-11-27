import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/return_receipt.dart';

/// Gọi API nhận trả & thu hồi thiết bị (`/api/equipment-returns`).
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

  /// Thủ kho tiếp nhận phụ trách kiểm nhận phiếu thu hồi (tách bạch giữa các Thủ kho).
  Future<ReturnReceiptDetail> claim(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/equipment-returns/$id/claim',
    );

    return ReturnReceiptDetail.fromJson(response.data!);
  }

  /// Xác nhận kiểm đếm phiếu thu hồi tự động (hủy giao / máy lỗi khi giao / sự cố).
  Future<ReturnReceiptDetail> confirmProcessing(
    String id,
    List<ReturnCheckInput> items, {
    String? note,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/equipment-returns/$id/confirm-processing',
      data: {
        'note': note,
        'items': [for (final item in items) item.toJson()],
      },
    );

    return ReturnReceiptDetail.fromJson(response.data!);
  }
}
