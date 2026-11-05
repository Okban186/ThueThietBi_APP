class ContractRepresentative {
  const ContractRepresentative({
    required this.id,
    required this.rentalContractId,
    required this.fullName,
    required this.idNumber,
    required this.representativeType,
    this.phone,
    this.email,
  });
  final String id, rentalContractId, fullName, idNumber, representativeType;
  final String? phone, email;
  factory ContractRepresentative.fromJson(Map<String, dynamic> j) =>
      ContractRepresentative(
        id: j['id'] as String,
        rentalContractId: j['rentalContractId'] as String,
        fullName: j['fullName'] as String,
        idNumber: j['idNumber'] as String,
        representativeType: j['representativeType'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
      );
}
