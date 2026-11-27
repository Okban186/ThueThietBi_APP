import 'dart:io';

import 'package:dio/dio.dart';

import '../models/upload_ticket.dart';

/// Upload file thẳng lên Cloudinary theo vé đã ký của Backend.
///
/// - File nhỏ (≤ 15 MB): upload 1 request multipart thông thường.
/// - File lớn (> 15 MB, hỗ trợ video tới 500 MB): tự động dùng Cloudinary Chunked Upload
///   (`Content-Range` + `X-Unique-Upload-Id`, mỗi chunk 10 MB) để tránh timeout / tràn RAM.
class CloudinaryUploader {
  CloudinaryUploader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(minutes: 10),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;

  static const int _chunkThresholdBytes = 15 * 1024 * 1024; // 15 MB
  static const int _chunkSizeBytes = 10 * 1024 * 1024; // 10 MB mỗi chunk

  /// Upload một file vào [slot]. Ném lỗi nếu Cloudinary từ chối.
  Future<void> upload({
    required String apiKey,
    required UploadSlot slot,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    final totalBytes = await file.length();

    // Phải gửi đúng các tham số đã được Backend ký.
    final allowedFormats = slot.allowedFormats
        .map((format) => format.replaceAll('.', '').trim().toLowerCase())
        .join(',');

    if (totalBytes <= _chunkThresholdBytes) {
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

      await _dio.post<dynamic>(
        slot.uploadUrl,
        data: form,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );
      onProgress?.call(1.0);
      return;
    }

    // Chunked Upload cho file lớn (video lên tới 500 MB)
    final uniqueUploadId =
        'uq_${slot.sessionId}_${DateTime.now().millisecondsSinceEpoch}';
    final raf = await file.open();
    try {
      var offset = 0;
      while (offset < totalBytes) {
        final remaining = totalBytes - offset;
        final currentSize =
            remaining < _chunkSizeBytes ? remaining : _chunkSizeBytes;
        final chunkBytes = await raf.read(currentSize);
        final endByte = offset + chunkBytes.length - 1;

        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(chunkBytes, filename: fileName),
          'api_key': apiKey,
          'timestamp': slot.timestamp.toString(),
          'signature': slot.signature,
          'public_id': slot.publicId,
          'folder': slot.folder,
          'overwrite': slot.overwrite,
          'type': slot.type,
          'allowed_formats': allowedFormats,
        });

        await _dio.post<dynamic>(
          slot.uploadUrl,
          data: form,
          options: Options(
            headers: {
              'X-Unique-Upload-Id': uniqueUploadId,
              'Content-Range': 'bytes $offset-$endByte/$totalBytes',
            },
          ),
          onSendProgress: (sent, total) {
            if (onProgress != null && total > 0) {
              final chunkFraction = (sent / total).clamp(0.0, 1.0);
              final uploaded = offset + (chunkBytes.length * chunkFraction);
              onProgress((uploaded / totalBytes).clamp(0.0, 1.0));
            }
          },
        );

        offset += chunkBytes.length;
        onProgress?.call((offset / totalBytes).clamp(0.0, 1.0));
      }
    } finally {
      await raf.close();
    }
  }
}
