/// Loại giấy tờ hợp đồng (do Backend suy ra từ document_type + display_order).
enum ContractDocumentKind {
  idCardFront('ID_CARD_FRONT', 'CCCD mặt trước'),
  idCardBack('ID_CARD_BACK', 'CCCD mặt sau'),
  businessLicense('BUSINESS_LICENSE', 'Giấy phép kinh doanh'),
  authorizationLetter('AUTHORIZATION_LETTER', 'Giấy ủy quyền'),
  other('OTHER', 'Giấy tờ khác');

  const ContractDocumentKind(this.code, this.label);

  final String code;
  final String label;

  static ContractDocumentKind fromCode(String code) => values.firstWhere(
    (k) => k.code == code.toUpperCase(),
    orElse: () => other,
  );
}

/// Ảnh giấy tờ đính kèm hợp đồng.
class ContractDocument {
  const ContractDocument({
    required this.id,
    required this.kind,
    required this.storageFileId,
    this.originalName,
    this.url,
  });

  final String id;
  final ContractDocumentKind kind;
  final String storageFileId;
  final String? originalName;

  /// URL có thời hạn để xem ảnh.
  final String? url;

  factory ContractDocument.fromJson(Map<String, dynamic> json) =>
      ContractDocument(
        id: json['id'] as String,
        kind: ContractDocumentKind.fromCode(json['kind'] as String),
        storageFileId: json['storageFileId'] as String,
        originalName: json['originalName'] as String?,
        url: json['url'] as String?,
      );
}
