import 'package:flutter/foundation.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

import '../models/technician_models.dart';
import '../../presentation/widgets/evidence_media_picker.dart';

/// API cổng vận hành cho Kỹ thuật viên (`/api/technician`).
class TechnicianApi {
  TechnicianApi(this._apiClient, {CloudinaryUploader? uploader})
    : _uploader = uploader ?? CloudinaryUploader();

  final ApiClient _apiClient;
  final CloudinaryUploader _uploader;

  ApiClient get apiClient => _apiClient;

  Future<TechnicianDashboard> getDashboard() async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/dashboard',
    );
    return TechnicianDashboard.fromJson(res.data ?? const {});
  }

  Future<List<TechnicianAssignmentSummary>> getAssignments({
    String? status,
    String? type,
  }) async {
    final res = await _apiClient.get<List<dynamic>>(
      '/api/technician/assignments',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return (res.data ?? const [])
        .map(
          (e) =>
              TechnicianAssignmentSummary.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TechnicianAssignmentDetail> getAssignmentDetail(String id) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/assignments/$id',
    );
    return TechnicianAssignmentDetail.fromJson(res.data!);
  }

  /// Xem chi tiết đầy đủ một phiếu bàn giao (gồm kết quả giao đạt, từng máy lỗi, ảnh/video minh chứng, phiếu thu hồi, thanh toán).
  Future<TechnicianHandoverStopDetail> getHandoverDetail(
    String handoverNoteId,
  ) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/handovers/$handoverNoteId',
    );
    return TechnicianHandoverStopDetail.fromJson(res.data!);
  }

  /// Quét barcode hoặc nhập serial kiểm tra xem thiết bị vật lý có thuộc phiếu bàn giao này hay không.
  Future<TechnicianHandoverLookupSerial> lookupHandoverSerial(
    String handoverNoteId,
    String serial,
  ) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/technician/handovers/$handoverNoteId/lookup-serial',
      queryParameters: {'serial': serial.trim()},
    );
    return TechnicianHandoverLookupSerial.fromJson(res.data!);
  }

  /// Chỉ KTV trưởng: Bắt đầu xuất phát chuyến đi (PENDING → IN_PROGRESS).
  Future<TechnicianAssignmentDetail> startAssignment(String id) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/assignments/$id/start',
    );
    return TechnicianAssignmentDetail.fromJson(res.data!);
  }

  /// Upload danh sách ảnh minh chứng (giữ tương thích cho màn Bảo trì / Sự cố).
  Future<List<String>> uploadEvidenceImages(
    List<String> filePaths, {
    String folder = 'handover',
  }) async {
    final items = [
      for (final p in filePaths)
        LocalEvidenceFile(
          path: p,
          isVideo: false,
          sizeBytes: 0,
          name: p.split(RegExp(r'[\\/]')).last,
        ),
    ];
    return uploadEvidenceMedia(items, folder: folder);
  }

  /// Upload hỗn hợp Ảnh (≤10MB) và Video (≤500MB, chunked) lên Cloudinary.
  Future<List<String>> uploadEvidenceMedia(
    List<LocalEvidenceFile> files, {
    String folder = 'handover',
    ValueChanged<double>? onProgress,
  }) async {
    if (files.isEmpty) return const [];

    final imageFiles = files.where((f) => !f.isVideo).toList();
    final videoFiles = files.where((f) => f.isVideo).toList();

    final totalCount = files.length;
    var finishedCount = 0;

    Future<List<String>> uploadGroup(
      List<LocalEvidenceFile> group, {
      required bool isVideo,
    }) async {
      if (group.isEmpty) return const [];
      final batchSize = isVideo ? 3 : 10;
      final groupIds = <String>[];

      for (var start = 0; start < group.length; start += batchSize) {
        final chunk = group.sublist(
          start,
          start + batchSize > group.length ? group.length : start + batchSize,
        );

        final ticketRes = await _apiClient.post<Map<String, dynamic>>(
          '/api/technician/upload-ticket',
          queryParameters: {
            'folder': folder,
            'mediaType': isVideo ? 'video' : 'image',
          },
          data: {'fileCount': chunk.length},
        );
        final ticket = UploadTicket.fromJson(ticketRes.data!);

        for (var i = 0; i < chunk.length; i++) {
          final item = chunk[i];
          await _uploader.upload(
            apiKey: ticket.apiKey,
            slot: ticket.uploads[i],
            filePath: item.path,
            fileName: item.name,
            onProgress: (fileProgress) {
              onProgress?.call(
                ((finishedCount + fileProgress) / totalCount).clamp(0.0, 1.0),
              );
            },
          );
          finishedCount++;
          onProgress?.call((finishedCount / totalCount).clamp(0.0, 1.0));
        }

        final confirmRes = await _apiClient.post<Map<String, dynamic>>(
          '/api/technician/confirm-upload',
          data: {'sessionIds': ticket.uploads.map((u) => u.sessionId).toList()},
        );

        final results = (confirmRes.data!['results'] as List<dynamic>)
            .map((e) => ConfirmedUpload.fromJson(e as Map<String, dynamic>))
            .toList();

        final failed = results.where(
          (r) => !r.success || r.storageFileId == null,
        );
        if (failed.isNotEmpty) {
          throw Exception(
            failed.first.message ??
                'Tải tệp minh chứng thất bại, vui lòng thử lại.',
          );
        }

        groupIds.addAll(results.map((r) => r.storageFileId!));
      }

      return groupIds;
    }

    final ids = <String>[];
    ids.addAll(await uploadGroup(imageFiles, isVideo: false));
    ids.addAll(await uploadGroup(videoFiles, isVideo: true));
    return ids;
  }

  /// Chỉ KTV trưởng: Hoàn tất bàn giao tại hiện trường.
  Future<TechnicianCompleteHandoverResult> completeHandover(
    String handoverNoteId, {
    required List<String> sceneAttachmentFileIds,
    List<String> issueAttachmentFileIds = const [],
    List<TechnicianDefectiveItemInput> defectiveItems = const [],
    String? note,
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/handovers/$handoverNoteId/complete',
      data: {
        'sceneAttachmentFileIds': sceneAttachmentFileIds,
        'issueAttachmentFileIds': issueAttachmentFileIds,
        'defectiveItems': [for (final d in defectiveItems) d.toJson()],
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TechnicianCompleteHandoverResult.fromJson(res.data!);
  }

  /// Chỉ KTV trưởng: Báo giao không thành công kèm lý do và ảnh/video minh chứng.
  Future<TechnicianFailHandoverResult> failHandover(
    String handoverNoteId, {
    required String reason,
    required List<String> attachmentFileIds,
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/handovers/$handoverNoteId/fail',
      data: {
        'reason': reason.trim(),
        'attachmentFileIds': attachmentFileIds,
      },
    );
    return TechnicianFailHandoverResult.fromJson(res.data!);
  }

  /// Chỉ KTV trưởng: Xác nhận thu hồi máy tại điểm dừng (chuyển phiếu thu hồi DRAFT → PROCESSING mang về kho).
  Future<TechnicianCompleteRetrievalResult> completeRetrievalStop(
    String returnId, {
    required List<String> attachmentFileIds,
    required List<TechnicianCompleteRetrievalItemInput> items,
    String? note,
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/technician/retrievals/$returnId/complete',
      data: {
        'attachmentFileIds': attachmentFileIds,
        'items': [for (final item in items) item.toJson()],
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TechnicianCompleteRetrievalResult.fromJson(res.data!);
  }

}
