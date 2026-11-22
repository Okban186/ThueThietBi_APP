import 'package:dio/dio.dart';

import '../models/upload_ticket.dart';

/// Upload file thẳng lên Cloudinary theo vé đã ký của Backend.
///
/// Quy trình chung (xem QuyTacKhiCodeBe.md, mục 6):
/// 1. Gọi API cấp vé của feature (ví dụ `/api/rental-contracts/upload-ticket`).
/// 2. [upload] từng file lên Cloudinary bằng thông tin trong vé.
/// 3. Gọi API xác nhận của feature để nhận `storageFileId`.
///
/// Dùng Dio riêng, không gắn token của hệ thống vì request đi thẳng tới Cloudinary.
class CloudinaryUploader {
  CloudinaryUploader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  final Dio _dio;

  /// Upload một file vào [slot]. Ném lỗi nếu Cloudinary từ chối.
  Future<void> upload({
    required String apiKey,
    required UploadSlot slot,
    required String filePath,
    required String fileName,
  }) async {
    // Phải gửi đúng các tham số đã được Backend ký.
    final allowedFormats = slot.allowedFormats
        .map((format) => format.replaceAll('.', '').trim().toLowerCase())
        .join(',');

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'api_key': apiKey,
      'timestamp': slot.timestamp.toString(),
      'signature': slot.signature,
      'public_id': slot.publicId,
      'folder': slot.folder,
      'overwrite': slot.overwrite,
      'type': slot.type,
      'allowed_formats': allowedFormats,
    });

    await _dio.post<dynamic>(slot.uploadUrl, data: form);
  }
}
