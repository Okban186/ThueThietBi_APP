import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/technician_incident_models.dart';

/// API xử lý sự cố thiết bị cho Kỹ thuật viên (`/api/technician/incidents`).
class TechnicianIncidentApi {
  TechnicianIncidentApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TechnicianIncidentSummary>> getMyIncidents({
    String? status,
  }) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/technician/incidents',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return (res.data ?? const [])
        .map(
          (e) => TechnicianIncidentSummary.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TechnicianIncidentDetail> getIncidentDetail(String id) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/incidents/$id',
    );
    return TechnicianIncidentDetail.fromJson(res.data!);
  }

  /// Chỉ KTV trưởng: xác nhận đã tới hiện trường xử lý sự cố (DISPATCHING → ON_SITE).
  Future<TechnicianIncidentDetail> startOnSite(String id) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/incidents/$id/arrive',
    );
    return TechnicianIncidentDetail.fromJson(res.data!);
  }

  /// Chốt kết quả sự cố: RESOLVED hoặc RETURN_REQUIRED (tự tạo phiếu thu hồi PROCESSING).
  Future<TechnicianResolveIncidentResult> resolveIncident(
    String id, {
    required String outcome,
    required String resolution,
    List<TechnicianIncidentAssessmentInput> itemAssessments = const [],
    List<String> attachmentFileIds = const [],
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/incidents/$id/resolve',
      data: {
        'outcome': outcome,
        'resolution': resolution.trim(),
        'itemAssessments': [for (final a in itemAssessments) a.toJson()],
        'attachmentFileIds': attachmentFileIds,
      },
    );
    return TechnicianResolveIncidentResult.fromJson(res.data!);
  }
}
