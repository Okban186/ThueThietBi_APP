import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

import '../models/customer_incident.dart';

/// Gọi API sự cố phía khách hàng (`/api/customer/incidents`).
class CustomerIncidentApi {
  CustomerIncidentApi(this._apiClient, {CloudinaryUploader? uploader})
    : _uploader = uploader ?? CloudinaryUploader();

  final ApiClient _apiClient;
  final CloudinaryUploader _uploader;

  Future<List<RentedEquipment>> getRentedEquipments() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/customer/equipments',
    );

    return response.data!
        .map((e) => RentedEquipment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tra cứu chính xác máy công ty đang thuê bằng quét mã vạch / nhập số Serial.
  Future<RentedEquipment> lookupRentedSerial(String serial) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/equipments/lookup-serial',
      queryParameters: {'serial': serial.trim()},
    );

    return RentedEquipment.fromJson(response.data!);
  }

  Future<List<CustomerIncident>> getIncidents() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/customer/incidents',
    );

    return response.data!
        .map((e) => CustomerIncident.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerIncidentDetail> getIncident(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/incidents/$id',
    );

    return CustomerIncidentDetail.fromJson(response.data!);
  }

  Future<CustomerIncidentDetail> create(IncidentInput input) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/customer/incidents',
      data: input.toJson(),
    );

    return CustomerIncidentDetail.fromJson(response.data!);
  }

  Future<CustomerIncidentDetail> cancel(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/customer/incidents/$id/cancel',
    );

    return CustomerIncidentDetail.fromJson(response.data!);
  }

  /// Upload ảnh sự cố: xin vé → upload thẳng lên Cloudinary → xác nhận.
  /// Trả `storageFileId` theo đúng thứ tự [filePaths].
  Future<List<String>> uploadImages(List<String> filePaths) async {
    if (filePaths.isEmpty) return const [];

    final ticketResponse = await _apiClient.post<Map<String, dynamic>>(
      '/api/customer/incidents/upload-ticket',
      data: {'fileCount': filePaths.length},
    );
    final ticket = UploadTicket.fromJson(ticketResponse.data!);

    for (var i = 0; i < filePaths.length; i++) {
      await _uploader.upload(
        apiKey: ticket.apiKey,
        slot: ticket.uploads[i],
        filePath: filePaths[i],
        fileName: filePaths[i].split(RegExp(r'[\\/]')).last,
      );
    }

    final confirmResponse = await _apiClient.post<Map<String, dynamic>>(
      '/api/customer/incidents/confirm-upload',
      data: {'sessionIds': ticket.uploads.map((u) => u.sessionId).toList()},
    );

    final results = (confirmResponse.data!['results'] as List<dynamic>)
        .map((e) => ConfirmedUpload.fromJson(e as Map<String, dynamic>))
        .toList();

    final failed = results.where((r) => !r.success || r.storageFileId == null);

    if (failed.isNotEmpty) {
      throw IncidentUploadException(
        failed.first.message ?? 'Không tải được ảnh lên, vui lòng thử lại.',
      );
    }

    final bySession = {for (final r in results) r.sessionId: r.storageFileId!};
    return ticket.uploads.map((u) => bySession[u.sessionId]!).toList();
  }
}

class IncidentUploadException implements Exception {
  const IncidentUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
