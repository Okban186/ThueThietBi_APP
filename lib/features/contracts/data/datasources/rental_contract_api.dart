import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

import '../models/contract_representative.dart';
import '../models/rental_contract.dart';
import '../models/rental_contract_item.dart';
import '../models/rental_contract_service_model.dart';
import '../models/rental_contract_suggestion.dart';

/// Gọi API hợp đồng thuê (`/api/rental-contracts`).
class RentalContractApi {
  RentalContractApi(this._apiClient, {CloudinaryUploader? uploader})
    : _uploader = uploader ?? CloudinaryUploader();

  final ApiClient _apiClient;
  final CloudinaryUploader _uploader;

  Future<List<RentalContract>> getContracts() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/rental-contracts',
    );

    return response.data!
        .map((json) => RentalContract.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<RentalContract> getDetail(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/rental-contracts/$id',
    );

    return RentalContract.fromDetailJson(response.data!);
  }

  Future<RentalContractSuggestion> getSuggestion(String reservationId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/rental-contracts/suggestion',
      queryParameters: {'reservationId': reservationId},
    );

    return RentalContractSuggestion.fromJson(response.data!);
  }

  /// Upload ảnh (giấy tờ / bản hợp đồng đã ký) và trả `storageFileId` theo đúng thứ tự [filePaths].
  ///
  /// Xin vé → upload thẳng lên Cloudinary → xác nhận. Ném lỗi nếu có ảnh không xác nhận được.
  Future<List<String>> uploadImages(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];

    final ticketResponse = await _apiClient.post<Map<String, dynamic>>(
      '/api/rental-contracts/upload-ticket',
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
      '/api/rental-contracts/confirm-upload',
      data: {'sessionIds': ticket.uploads.map((u) => u.sessionId).toList()},
    );

    final results = (confirmResponse.data!['results'] as List<dynamic>)
        .map((e) => ConfirmedUpload.fromJson(e as Map<String, dynamic>))
        .toList();

    final failed = results.where((r) => !r.success || r.storageFileId == null);

    if (failed.isNotEmpty) {
      throw UploadFailedException(
        failed.first.message ?? 'Không xác nhận được ảnh đã tải lên.',
      );
    }

    // Trả theo thứ tự vé (cùng thứ tự với filePaths).
    final bySession = {for (final r in results) r.sessionId: r.storageFileId!};

    return ticket.uploads.map((u) => bySession[u.sessionId]!).toList();
  }

  Future<RentalContract> create(
    String reservationId,
    RentalContractInput input,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/rental-contracts',
      data: {'reservationId': reservationId, ...input.toJson()},
    );

    return RentalContract.fromDetailJson(response.data!);
  }

  Future<RentalContract> update(String id, RentalContractInput input) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/rental-contracts/$id',
      data: input.toJson(),
    );

    return RentalContract.fromDetailJson(response.data!);
  }

  Future<RentalContract> submit(String id) => _action(id, 'submit');

  Future<RentalContract> cancel(String id, {String? reason}) =>
      _action(id, 'cancel', data: {'reason': reason});

  Future<RentalContract> markSigned(String id, String contractFileId) =>
      _action(id, 'signed', data: {'contractFileId': contractFileId});

  /// Dành cho giao diện Manager (quyền MANAGER).
  Future<RentalContract> approve(String id) => _action(id, 'approve');

  /// Dành cho giao diện Manager (quyền MANAGER).
  Future<RentalContract> reject(String id, String reason) =>
      _action(id, 'reject', data: {'reason': reason});

  Future<RentalContract> _action(
    String id,
    String action, {
    Object? data,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/rental-contracts/$id/$action',
      data: data,
    );

    return RentalContract.fromDetailJson(response.data!);
  }
}

/// Nội dung tạo/sửa hợp đồng (thời gian, model, số lượng lấy theo phiếu).
class RentalContractInput {
  const RentalContractInput({
    required this.rentalType,
    required this.items,
    required this.services,
    required this.representative,
    required this.depositRequiredAmount,
    required this.idCardFrontFileId,
    required this.idCardBackFileId,
    required this.businessLicenseFileId,
    this.authorizationLetterFileId,
    this.deliveryAddress,
    this.deliveryNote,
    this.note,
  });

  final RentalType rentalType;
  final List<RentalContractItem> items;
  final List<RentalContractServiceModel> services;
  final ContractRepresentative representative;
  final double depositRequiredAmount;
  final String idCardFrontFileId, idCardBackFileId, businessLicenseFileId;
  final String? authorizationLetterFileId;
  final String? deliveryAddress, deliveryNote, note;

  Map<String, dynamic> toJson() => {
    'rentalType': rentalType.code,
    'deliveryAddress': deliveryAddress,
    'deliveryNote': deliveryNote,
    'note': note,
    'depositRequiredAmount': depositRequiredAmount,
    'items': [
      for (final item in items)
        {
          'equipmentModelId': item.equipmentModelId,
          'billingUnit': item.billingUnit.code,
          'agreedUnitPrice': item.agreedUnitPrice,
          'note': item.note,
        },
    ],
    'services': [for (final service in services) service.toJson()],
    'representative': representative.toJson(),
    'documents': {
      'idCardFrontFileId': idCardFrontFileId,
      'idCardBackFileId': idCardBackFileId,
      'businessLicenseFileId': businessLicenseFileId,
      'authorizationLetterFileId': authorizationLetterFileId,
    },
  };
}

class UploadFailedException implements Exception {
  const UploadFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
