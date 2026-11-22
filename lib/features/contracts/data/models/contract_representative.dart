/// Tư cách người ký hợp đồng.
enum RepresentativeType {
  legal('LEGAL_REPRESENTATIVE', 'Người đại diện theo pháp luật'),
  authorized('AUTHORIZED_REPRESENTATIVE', 'Người được ủy quyền');

  const RepresentativeType(this.code, this.label);

  final String code;
  final String label;

  static RepresentativeType fromCode(String code) =>
      code.toUpperCase() == 'AUTHORIZED_REPRESENTATIVE' ? authorized : legal;
}

/// Người đại diện ký hợp đồng (mỗi hợp đồng một người).
class ContractRepresentative {
  const ContractRepresentative({
    required this.fullName,
    required this.idNumber,
    required this.representativeType,
    this.phone,
    this.email,
  });

  final String fullName;

  /// Số CCCD (12 số) hoặc CMND cũ (9 số).
  final String idNumber;
  final String? phone, email;
  final RepresentativeType representativeType;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'idNumber': idNumber,
    'phone': phone,
    'email': email,
    'representativeType': representativeType.code,
  };

  factory ContractRepresentative.fromJson(Map<String, dynamic> json) =>
      ContractRepresentative(
        fullName: json['fullName'] as String,
        idNumber: json['idNumber'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        representativeType: RepresentativeType.fromCode(
          json['representativeType'] as String,
        ),
      );
}
