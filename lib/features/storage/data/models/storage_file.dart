class StorageFile {
  const StorageFile({
    required this.id,
    required this.objectKey,
    required this.bucketName,
    required this.originalName,
    required this.sizeBytes,
    this.contentType,
    this.metadata,
    this.uploadedBy,
  });
  final String id, objectKey, bucketName, originalName;
  final int sizeBytes;
  final String? contentType, uploadedBy;
  final Map<String, dynamic>? metadata;
  factory StorageFile.fromJson(Map<String, dynamic> j) => StorageFile(
    id: j['id'] as String,
    objectKey: j['objectKey'] as String,
    bucketName: j['bucketName'] as String,
    originalName: j['originalName'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    contentType: j['contentType'] as String?,
    metadata: j['metadata'] as Map<String, dynamic>?,
    uploadedBy: j['uploadedBy'] as String?,
  );
}
