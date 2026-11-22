/// Loại dịch vụ đi kèm hợp đồng.
enum ContractServiceType {
  delivery('DELIVERY', 'Giao hàng'),
  loading('LOADING', 'Bốc xếp lên'),
  unloading('UNLOADING', 'Bốc xếp xuống'),
  other('OTHER', 'Khác');

  const ContractServiceType(this.code, this.label);

  final String code;
  final String label;

  static ContractServiceType fromCode(String code) => values.firstWhere(
    (t) => t.code == code.toUpperCase(),
    orElse: () => other,
  );
}

/// Bên thực hiện dịch vụ.
enum ServiceProvider {
  rentalCompany('RENTAL_COMPANY', 'Bên cho thuê'),
  customer('CUSTOMER', 'Khách tự làm');

  const ServiceProvider(this.code, this.label);

  final String code;
  final String label;

  static ServiceProvider fromCode(String code) =>
      code.toUpperCase() == 'CUSTOMER' ? customer : rentalCompany;
}

/// Dịch vụ đi kèm hợp đồng (bảng rental_contract_services).
/// Chỉ dịch vụ do bên cho thuê thực hiện mới tính vào tổng giá trị hợp đồng.
class RentalContractServiceModel {
  const RentalContractServiceModel({
    required this.serviceType,
    required this.providedBy,
    required this.quantity,
    required this.unitPrice,
    this.id,
    this.amount,
    this.note,
  });

  final String? id;
  final ContractServiceType serviceType;
  final ServiceProvider providedBy;
  final int quantity;
  final double unitPrice;
  final double? amount;
  final String? note;

  double get total => amount ?? quantity * unitPrice;

  bool get isCharged => providedBy == ServiceProvider.rentalCompany;

  Map<String, dynamic> toJson() => {
    'serviceType': serviceType.code,
    'providedBy': providedBy.code,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'note': note,
  };

  factory RentalContractServiceModel.fromJson(Map<String, dynamic> json) =>
      RentalContractServiceModel(
        id: json['id'] as String?,
        serviceType: ContractServiceType.fromCode(
          json['serviceType'] as String,
        ),
        providedBy: ServiceProvider.fromCode(json['providedBy'] as String),
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        amount: (json['amount'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );
}
