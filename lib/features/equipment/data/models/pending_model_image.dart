enum PendingImageStatus { pending, uploading, uploaded, failed }

class PendingModelImage {
  PendingModelImage({
    required this.filePath,
    required this.fileName,
    this.status = PendingImageStatus.pending,
    this.errorMessage,
  });

  String filePath;
  String fileName;
  PendingImageStatus status;
  String? errorMessage;
}
