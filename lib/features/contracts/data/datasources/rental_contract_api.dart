import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/storage/data/datasources/cloudinary_uploader.dart';
import 'package:thuethietbi_app/features/storage/data/models/upload_ticket.dart';

import '../models/contract_billing.dart';
import '../models/contract_representative.dart';
import '../models/rental_contract.dart';
import '../models/rental_contract_item.dart';
import '../models/rental_contract_service_model.dart';
import '../models/rental_contract_suggestion.dart';
import '../models/shipping_quote.dart';

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

  /// Báo giá phí vận chuyển tự động từ Backend (Sales chỉ xem).
  Future<ShippingQuote> getShippingQuote({
    String? reservationId,
    String? contractId,
    required ServiceProvider providedBy,
    String? deliveryAddress,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/rental-contracts/shipping-quote',
      data: {
        'reservationId': ?reservationId,
        'contractId': ?contractId,
        'providedBy': providedBy.code,
        'deliveryAddress': deliveryAddress,
      },
    );

    return ShippingQuote.fromJson(response.data!);
  }

  /// Tổng quan chi phí, các đợt thanh toán tiền thuê và khoản phạt của hợp đồng.
  Future<ContractBillingSummary> getBilling(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/rental-contracts/$id/billing',
    );

    return ContractBillingSummary.fromJson(response.data!);
  }

  /// Xuất hợp đồng PDF điền sẵn từ mẫu (bản nháp nếu chưa được duyệt).
  Future<Uint8List> exportPdf(String id) async {
    final response = await _apiClient.get<List<int>>(
      '/api/rental-contracts/$id/pdf',
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }

  /// Tải file từ URL có chữ ký của Cloudinary (bản hợp đồng đã ký).
  /// Dùng Dio riêng vì URL không thuộc Backend, không gửi token.
  Future<Uint8List> downloadFile(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }

  /// Upload ảnh giấy tờ (jpg/png/webp) và trả `storageFileId` theo đúng thứ tự [filePaths].
  Future<List<String>> uploadImages(List<String> filePaths) {
    if (filePaths.isEmpty) return Future.value(const []);

    return _uploadFiles('/api/rental-contracts/upload-ticket', {
      'fileCount': filePaths.length,
    }, filePaths);
  }

  /// Upload bản hợp đồng đã ký (1 file PDF) và trả `storageFileId`.
  Future<String> uploadSignedPdf(String filePath) async {
    final ids = await _uploadFiles(
      '/api/rental-contracts/signed-upload-ticket',
      null,
      [filePath],
    );

    return ids.single;
  }

  /// Xin vé → upload thẳng lên Cloudinary → xác nhận.
  /// Ném lỗi nếu có file không xác nhận được.
  Future<List<String>> _uploadFiles(
    String ticketPath,
    Map<String, dynamic>? ticketBody,
    List<String> filePaths,
  ) async {
    final ticketResponse = await _apiClient.post<Map<String, dynamic>>(
      ticketPath,
      data: ticketBody,
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
        failed.first.message ?? 'Không xác nhận được file đã tải lên.',
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

/// Nội dung tạo/sửa hợp đồng. Thời gian, model, số lượng lấy theo phiếu;
/// loại thuê, đơn vị tính và đơn giá do Backend tính theo giá niêm yết.
class RentalContractInput {
  const RentalContractInput({
    required this.items,
    required this.deliveryProvidedBy,
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

  final List<RentalContractItem> items;
  final ServiceProvider deliveryProvidedBy;
  final ContractRepresentative representative;
  final double depositRequiredAmount;
  final String idCardFrontFileId, idCardBackFileId, businessLicenseFileId;
  final String? authorizationLetterFileId;
  final String? deliveryAddress, deliveryNote, note;

  Map<String, dynamic> toJson() => {
    'deliveryAddress': deliveryAddress,
    'deliveryProvidedBy': deliveryProvidedBy.code,
    'deliveryNote': deliveryNote,
    'note': note,
    'depositRequiredAmount': depositRequiredAmount,
    'items': [
      for (final item in items)
        {'equipmentModelId': item.equipmentModelId, 'note': item.note},
    ],
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
