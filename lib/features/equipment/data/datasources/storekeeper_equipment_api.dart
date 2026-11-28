import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/dashboard/data/models/storekeeper_dashboard_summary.dart';
import 'package:thuethietbi_app/features/equipment/data/models/category.dart';
import 'package:thuethietbi_app/features/equipment/data/models/equipment_history.dart';
import 'package:thuethietbi_app/features/equipment/data/models/paged_equipment_result.dart';
import 'package:thuethietbi_app/features/equipment/data/models/pending_model_image.dart';
import 'package:thuethietbi_app/features/equipment/data/models/warehouse.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

class StorekeeperEquipmentApi {
  StorekeeperEquipmentApi(this._apiClient, {CloudinaryUploader? uploader})
    : _uploader = uploader ?? CloudinaryUploader();

  final ApiClient _apiClient;
  final CloudinaryUploader _uploader;

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<StorekeeperDashboardSummary> getDashboardSummary() async {
    final res = await _apiClient.get<dynamic>('/api/dashboard/storekeeper');

    return StorekeeperDashboardSummary.fromJson(
      res.data as Map<String, dynamic>,
    );
  }

  // ============================================================
  // EQUIPMENT MODELS
  // ============================================================

  Future<List<dynamic>> getModels({
    String? keyword,
    String? categoryId,
    String? status,
  }) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/storekeeper/equipment-models',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (status != null) 'status': status,
      },
    );

    return res.data ?? [];
  }

  Future<dynamic> getModelDetail(String id) async {
    final res = await _apiClient.get<dynamic>(
      '/api/storekeeper/equipment-models/$id',
    );

    return res.data;
  }

  Future<dynamic> createModel(Map<String, dynamic> payload) async {
    final res = await _apiClient.post<dynamic>(
      '/api/storekeeper/equipment-models',
      data: payload,
    );

    return res.data;
  }

  Future<Uint8List> downloadModelImportTemplate() async {
    final res = await _apiClient.get<List<int>>(
      '/api/storekeeper/equipment-models/import-template',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const <int>[]);
  }

  Future<Map<String, dynamic>> importModelsFromExcel({
    String? filePath,
    Uint8List? bytes,
    required String fileName,
  }) async {
    final MultipartFile multipart;
    if (filePath != null && filePath.isNotEmpty) {
      multipart = await MultipartFile.fromFile(filePath, filename: fileName);
    } else if (bytes != null && bytes.isNotEmpty) {
      multipart = MultipartFile.fromBytes(bytes, filename: fileName);
    } else {
      throw ArgumentError('Không đọc được dữ liệu file Excel đã chọn.');
    }

    final formData = FormData.fromMap({'file': multipart});
    // Không truyền cứng contentType 'multipart/form-data' để Dio tự sinh boundary chuẩn cho ASP.NET Core IFormFile
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/storekeeper/equipment-models/import-excel',
      data: formData,
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<dynamic> updateModel(String id, Map<String, dynamic> payload) async {
    final res = await _apiClient.put<dynamic>(
      '/api/storekeeper/equipment-models/$id',
      data: payload,
    );

    return res.data;
  }

  Future<void> updateModelStatus(String id, String status) async {
    await _apiClient.put<dynamic>(
      '/api/storekeeper/equipment-models/$id/status',
      data: {'status': status},
    );
  }

  Future<void> updateCategory(String id, Map<String, dynamic> payload) async {
    await _apiClient.put<dynamic>(
      '/api/storekeeper/categories/$id',
      data: payload,
    );
  }

  Future<void> updateCategoryStatus(String id, String status) async {
    await _apiClient.put<dynamic>(
      '/api/storekeeper/categories/$id/status',
      data: {'status': status},
    );
  }

  Future<bool> uploadAndConfirmModelImages({
    required String modelId,
    required List<PendingModelImage> items,
  }) async {
    final toUpload = items
        .where((e) => e.status != PendingImageStatus.uploaded)
        .toList();

    if (toUpload.isEmpty) return true;

    for (final item in toUpload) {
      item.status = PendingImageStatus.uploading;
      item.errorMessage = null;
    }

    // Bước 1: Xin ticket cho đúng số lượng ảnh cần tải lên.
    final ticketRes = await _apiClient.post<dynamic>(
      '/api/storekeeper/equipment-models/upload-ticket',
      data: {'fileCount': toUpload.length},
    );

    final ticket = UploadTicket.fromJson(
      ticketRes.data as Map<String, dynamic>,
    );

    // Bước 2: Upload từng ảnh lên Cloudinary (ảnh nào lỗi đánh dấu riêng ảnh đó).
    final sessionToItem = <String, PendingModelImage>{};
    final uploadedSessionIds = <String>[];

    for (var i = 0; i < toUpload.length; i++) {
      final item = toUpload[i];
      final slot = ticket.uploads[i];

      try {
        await _uploader.upload(
          apiKey: ticket.apiKey,
          slot: slot,
          filePath: item.filePath,
          fileName: item.fileName,
        );
        sessionToItem[slot.sessionId] = item;
        uploadedSessionIds.add(slot.sessionId);
      } catch (_) {
        item.status = PendingImageStatus.failed;
        item.errorMessage = 'Sai định dạng hoặc vượt quá dung lượng cho phép (JPG, PNG, WEBP ≤ 5MB).';
      }
    }

    // Bước 3: Gọi Confirm 1 lần duy nhất cho các ảnh đã lên Cloudinary.
    if (uploadedSessionIds.isNotEmpty) {
      final confirmRes = await _apiClient.post<dynamic>(
        '/api/storekeeper/equipment-models/$modelId/confirm-media-upload',
        data: {'sessionIds': uploadedSessionIds},
      );

      final results =
          (confirmRes.data as Map<String, dynamic>)['results']
              as List<dynamic>? ??
          const [];

      for (final raw in results) {
        final result = ConfirmedUpload.fromJson(raw as Map<String, dynamic>);
        final item = sessionToItem[result.sessionId];
        if (item == null) continue;

        if (result.success) {
          item.status = PendingImageStatus.uploaded;
          item.errorMessage = null;
        } else {
          item.status = PendingImageStatus.failed;
          item.errorMessage =
              result.message ?? 'Ảnh không hợp lệ (sai định dạng).';
        }
      }
    }

    return items.every((e) => e.status == PendingImageStatus.uploaded);
  }

  Future<void> setPrimaryMedia(String modelId, String mediaId) async {
    await _apiClient.put<dynamic>(
      '/api/storekeeper/equipment-models/$modelId/media/$mediaId/primary',
    );
  }

  Future<void> deleteMedia(String modelId, String mediaId) async {
    await _apiClient.delete<dynamic>(
      '/api/storekeeper/equipment-models/$modelId/media/$mediaId',
    );
  }

  Future<PagedEquipmentResult> getEquipmentsPaged({
    String? modelId,
    String? warehouseId,
    String? status,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _apiClient.get<dynamic>(
      '/api/storekeeper/equipments',
      queryParameters: {
        if (modelId != null) 'modelId': modelId,
        if (warehouseId != null) 'warehouseId': warehouseId,
        if (status != null) 'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedEquipmentResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<dynamic>> getEquipments({
    String? modelId,
    String? warehouseId,
    String? status,
    String? keyword,
    int page = 1,
    int pageSize = 50,
  }) async {
    final result = await getEquipmentsPaged(
      modelId: modelId,
      warehouseId: warehouseId,
      status: status,
      keyword: keyword,
      page: page,
      pageSize: pageSize,
    );
    return result.items;
  }

  Future<void> batchCreateEquipments(Map<String, dynamic> payload) async {
    await _apiClient.post<dynamic>(
      '/api/storekeeper/equipments/batch',
      data: payload,
    );
  }

  Future<void> updateEquipment(String id, Map<String, dynamic> payload) async {
    await _apiClient.put<dynamic>(
      '/api/storekeeper/equipments/$id',
      data: payload,
    );
  }

  Future<List<Category>> getCategories({bool includeInactive = true}) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/storekeeper/categories',
      queryParameters: {'includeInactive': includeInactive},
    );

    return (res.data ?? [])
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(Map<String, dynamic> payload) async {
    await _apiClient.post<dynamic>(
      '/api/storekeeper/categories',
      data: payload,
    );
  }

  Future<({String prefix, int nextSequence, int padLength})>
  getNextSerialPreview(String modelId) async {
    final res = await _apiClient.get<dynamic>(
      '/api/storekeeper/equipment-models/$modelId/next-serial',
    );
    final data = res.data as Map<String, dynamic>;
    return (
      prefix: data['prefix'] as String,
      nextSequence: (data['nextSequence'] as num).toInt(),
      padLength: (data['padLength'] as num).toInt(),
    );
  }

  Future<void> autoGenerateEquipments(Map<String, dynamic> payload) async {
    await _apiClient.post<dynamic>(
      '/api/storekeeper/equipments/auto-generate',
      data: payload,
    );
  }

  // ============================================================
  // WAREHOUSES
  // ============================================================

  Future<List<Warehouse>> getWarehouses({bool includeInactive = true}) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/storekeeper/warehouses',
      queryParameters: {'includeInactive': includeInactive},
    );

    return (res.data ?? [])
        .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createWarehouse(Map<String, dynamic> payload) async {
    await _apiClient.post<dynamic>(
      '/api/storekeeper/warehouses',
      data: payload,
    );
  }

  /// Lịch sử vòng đời thiết bị vật lý (bảo trì, linh kiện đã thay, chi phí, sự cố, lịch sử cho thuê).
  Future<EquipmentLifecycleHistory> getEquipmentHistory(
    String equipmentId,
  ) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/storekeeper/equipments/$equipmentId/history',
    );
    return EquipmentLifecycleHistory.fromJson(res.data!);
  }

}
