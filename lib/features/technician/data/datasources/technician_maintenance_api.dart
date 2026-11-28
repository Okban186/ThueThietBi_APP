import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/technician_maintenance_models.dart';

/// API quản lý phiếu bảo trì tại kho (`/api/technician/maintenance-tasks`).
class TechnicianMaintenanceApi {
  TechnicianMaintenanceApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MaintenanceTaskSummary>> getTasks({
    String? status,
    String? type,
    String? keyword,
  }) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/technician/maintenance-tasks',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    return (res.data ?? const [])
        .map((e) => MaintenanceTaskSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MaintenanceTaskDetail> getTaskDetail(String id) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/maintenance-tasks/$id',
    );
    return MaintenanceTaskDetail.fromJson(res.data!);
  }

  /// KTV tự tiếp nhận phụ trách phiếu bảo trì (khóa độc quyền, KTV khác không thấy nữa).
  Future<MaintenanceTaskDetail> claimTask(String id) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/maintenance-tasks/$id/claim',
    );
    return MaintenanceTaskDetail.fromJson(res.data!);
  }

  Future<MaintenanceTaskDetail> startTask(String id) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/maintenance-tasks/$id/start',
    );
    return MaintenanceTaskDetail.fromJson(res.data!);
  }

  Future<CompleteMaintenanceResult> completeTask(
    String id, {
    required String description,
    required String result,
    required String outcome,
    required List<String> attachmentFileIds,
    String? newCondition,
    double laborCost = 0,
    String? note,
    List<MaintenancePartInput> parts = const [],
    String? incidentFaultType,
    String? proposedChargeType,
    double? proposedChargeAmount,
    String? proposedChargeDescription,
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/maintenance-tasks/$id/complete',
      data: {
        'description': description.trim(),
        'result': result.trim(),
        'outcome': outcome,
        if (newCondition != null && newCondition.isNotEmpty)
          'newCondition': newCondition,
        'laborCost': laborCost,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'parts': [for (final p in parts) p.toJson()],
        'attachmentFileIds': attachmentFileIds,
        if (incidentFaultType != null && incidentFaultType.isNotEmpty)
          'incidentFaultType': incidentFaultType,
        if (proposedChargeType != null && proposedChargeType.isNotEmpty)
          'proposedChargeType': proposedChargeType,
        if (proposedChargeAmount != null)
          'proposedChargeAmount': proposedChargeAmount,
        if (proposedChargeDescription != null &&
            proposedChargeDescription.trim().isNotEmpty)
          'proposedChargeDescription': proposedChargeDescription.trim(),
      },
    );
    return CompleteMaintenanceResult.fromJson(res.data!);
  }
}
