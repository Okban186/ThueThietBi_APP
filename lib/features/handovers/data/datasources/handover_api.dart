import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/handover_preparation.dart';

/// Gọi API phiếu bàn giao (`/api/handovers`): thủ kho soạn phiếu cho hợp đồng đã ký.
class HandoverApi {
  HandoverApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PreparationContract>> getContractsToPrepare({
    String? keyword,
  }) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/handovers/contracts',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );

    return response.data!
        .map((e) => PreparationContract.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PreparationContractDetail> getContract(String contractId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/handovers/contracts/$contractId',
    );

    return PreparationContractDetail.fromJson(response.data!);
  }

  Future<List<StockEquipment>> getAvailableEquipments(
    String equipmentModelId,
  ) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/handovers/available-equipments',
      queryParameters: {'equipmentModelId': equipmentModelId},
    );

    return response.data!
        .map((e) => StockEquipment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HandoverSummary>> getNotes({HandoverStatus? status}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/handovers',
      queryParameters: {if (status != null) 'status': status.code},
    );

    return response.data!
        .map((e) => HandoverSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HandoverDetail> getNote(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/handovers/$id',
    );

    return HandoverDetail.fromJson(response.data!);
  }

  Future<HandoverDetail> create(String contractId, HandoverInput input) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/handovers',
      data: {'rentalContractId': contractId, ...input.toJson()},
    );

    return HandoverDetail.fromJson(response.data!);
  }

  Future<HandoverDetail> update(String id, HandoverInput input) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/handovers/$id',
      data: input.toJson(),
    );

    return HandoverDetail.fromJson(response.data!);
  }

  /// Soạn xong: chuyển phiếu chờ quản lý duyệt xuất kho.
  Future<HandoverDetail> submit(String id) => _action(id, 'submit');

  Future<HandoverDetail> cancel(String id, String reason) =>
      _action(id, 'cancel', data: {'reason': reason});

  Future<HandoverDetail> _action(
    String id,
    String action, {
    Object? data,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/handovers/$id/$action',
      data: data,
    );

    return HandoverDetail.fromJson(response.data!);
  }
}
