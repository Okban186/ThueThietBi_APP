class ContractDocument {
  const ContractDocument({
    required this.id,
    required this.rentalContractId,
    required this.documentType,
    required this.storageFileId,
    this.representativeId,
    this.displayOrder,
    this.documentNumber,
    this.issuedDate,
    this.note,
  });
  final String id, rentalContractId, documentType, storageFileId;
  final String? representativeId, documentNumber, note;
  final int? displayOrder;
  final DateTime? issuedDate;
  factory ContractDocument.fromJson(Map<String, dynamic> j) => ContractDocument(
    id: j['id'] as String,
    rentalContractId: j['rentalContractId'] as String,
    documentType: j['documentType'] as String,
    storageFileId: j['storageFileId'] as String,
    representativeId: j['representativeId'] as String?,
    displayOrder: (j['displayOrder'] as num?)?.toInt(),
    documentNumber: j['documentNumber'] as String?,
    issuedDate: j['issuedDate'] == null
        ? null
        : DateTime.parse(j['issuedDate'] as String),
    note: j['note'] as String?,
  );
}
