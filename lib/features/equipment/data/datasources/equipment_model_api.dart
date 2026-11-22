import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../models/equipment_availability.dart';
import '../models/equipment_model.dart';

/// Gọi API model thiết bị (chỉ đọc) và số lượng khả dụng.
class EquipmentModelApi {
  EquipmentModelApi(this._apiClient);

  final ApiClient _apiClient;

  /// Model đang hoạt động, kèm `operationalUnits` và `availableToday`.
  Future<List<EquipmentModel>> getModels({String? keyword}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/equipment-models',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );

    return response.data!
        .map((json) => EquipmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Số lượng khả dụng của nhiều model trong cùng khoảng ngày.
  /// [excludeReservationId]: phiếu đang sửa, bỏ qua số lượng của chính phiếu đó.
  Future<Map<String, EquipmentAvailability>> checkAvailability({
    required List<String> equipmentModelIds,
    required DateTime from,
    required DateTime to,
    String? excludeReservationId,
  }) async {
    if (equipmentModelIds.isEmpty) return {};

    final response = await _apiClient.post<List<dynamic>>(
      '/api/equipment-models/availability',
      data: {
        'equipmentModelIds': equipmentModelIds,
        'from': DateFormatter.isoDate(from),
        'to': DateFormatter.isoDate(to),
        'excludeReservationId': excludeReservationId,
      },
    );

    final results = response.data!.map(
      (json) => EquipmentAvailability.fromJson(json as Map<String, dynamic>),
    );

    return {for (final result in results) result.equipmentModelId: result};
  }
}
