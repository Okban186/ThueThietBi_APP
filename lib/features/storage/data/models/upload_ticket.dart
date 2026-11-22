/// Vé upload do Backend cấp (`FileUploadTicket`) để upload thẳng lên Cloudinary.
class UploadTicket {
  const UploadTicket({
    required this.apiKey,
    required this.maxFileSizeBytes,
    required this.uploads,
  });

  final String apiKey;
  final int maxFileSizeBytes;
  final List<UploadSlot> uploads;

  factory UploadTicket.fromJson(Map<String, dynamic> json) => UploadTicket(
    apiKey: json['apiKey'] as String,
    maxFileSizeBytes: (json['maxFileSizeBytes'] as num).toInt(),
    uploads: (json['uploads'] as List<dynamic>)
        .map((e) => UploadSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Thông tin upload (đã ký) cho một file.
class UploadSlot {
  const UploadSlot({
    required this.sessionId,
    required this.uploadUrl,
    required this.allowedFormats,
    required this.folder,
    required this.overwrite,
    required this.publicId,
    required this.timestamp,
    required this.signature,
    required this.type,
  });

  final String sessionId;
  final String uploadUrl;
  final List<String> allowedFormats;
  final String folder;
  final String overwrite;
  final String publicId;
  final int timestamp;
  final String signature;
  final String type;

  factory UploadSlot.fromJson(Map<String, dynamic> json) => UploadSlot(
    sessionId: json['sessionId'] as String,
    uploadUrl: json['uploadUrl'] as String,
    allowedFormats: (json['allowedFormats'] as List<dynamic>).cast<String>(),
    folder: json['folder'] as String,
    overwrite: json['overWrite'] as String? ?? 'false',
    publicId: json['publicId'] as String,
    timestamp: (json['timestamp'] as num).toInt(),
    signature: json['signature'] as String,
    type: json['type'] as String? ?? 'authenticated',
  );
}

/// Kết quả xác nhận một file (`ConfirmFileUploadResult`).
class ConfirmedUpload {
  const ConfirmedUpload({
    required this.sessionId,
    required this.success,
    this.storageFileId,
    this.message,
  });

  final String sessionId;
  final bool success;
  final String? storageFileId;
  final String? message;

  factory ConfirmedUpload.fromJson(Map<String, dynamic> json) =>
      ConfirmedUpload(
        sessionId: json['sessionId'] as String,
        success: json['success'] as bool? ?? false,
        storageFileId: json['storageFileId'] as String?,
        message: json['message'] as String?,
      );
}
