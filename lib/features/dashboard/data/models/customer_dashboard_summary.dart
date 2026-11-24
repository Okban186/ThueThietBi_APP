import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';

/// Công ty của tài khoản khách hàng (`GET /api/customer/company`).
class CustomerCompany {
  const CustomerCompany({
    required this.id,
    required this.companyCode,
    required this.name,
    required this.taxCode,
    this.address,
    this.salesName,
    this.salesPhone,
    this.salesEmail,
  });

  final String id, companyCode, name, taxCode;
  final String? address;

  /// Nhân viên kinh doanh phụ trách (đầu mối liên hệ).
  final String? salesName, salesPhone, salesEmail;

  factory CustomerCompany.fromJson(Map<String, dynamic> json) =>
      CustomerCompany(
        id: json['id'] as String,
        companyCode: json['companyCode'] as String,
        name: json['name'] as String,
        taxCode: json['taxCode'] as String,
        address: json['address'] as String?,
        salesName: json['salesName'] as String?,
        salesPhone: json['salesPhone'] as String?,
        salesEmail: json['salesEmail'] as String?,
      );
}

/// Hợp đồng rút gọn ở mục "Sắp kết thúc" của Tổng quan.
class CustomerContractBrief {
  const CustomerContractBrief({
    required this.id,
    required this.contractCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.contractTotalAmount,
    required this.daysLeft,
  });

  final String id, contractCode;
  final DateTime startDate, endDate;
  final RentalContractStatus status;
  final double contractTotalAmount;

  /// Số ngày còn lại tới ngày kết thúc (âm nếu đã quá hạn).
  final int daysLeft;

  factory CustomerContractBrief.fromJson(Map<String, dynamic> json) =>
      CustomerContractBrief(
        id: json['id'] as String,
        contractCode: json['contractCode'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        status: RentalContractStatus.fromCode(json['status'] as String),
        contractTotalAmount: (json['contractTotalAmount'] as num).toDouble(),
        daysLeft: (json['daysLeft'] as num).toInt(),
      );
}

/// Số liệu Tổng quan của khách hàng (`GET /api/customer/dashboard`).
class CustomerDashboardSummary {
  const CustomerDashboardSummary({
    required this.company,
    required this.activeContracts,
    required this.pendingSignatureContracts,
    required this.endingSoonContracts,
    required this.rentedUnits,
    required this.activeContractsValue,
    required this.outstandingAmount,
    required this.upcomingContracts,
  });

  final CustomerCompany company;
  final int activeContracts,
      pendingSignatureContracts,
      endingSoonContracts,
      rentedUnits;
  final double activeContractsValue, outstandingAmount;
  final List<CustomerContractBrief> upcomingContracts;

  factory CustomerDashboardSummary.fromJson(Map<String, dynamic> json) =>
      CustomerDashboardSummary(
        company: CustomerCompany.fromJson(
          json['company'] as Map<String, dynamic>,
        ),
        activeContracts: (json['activeContracts'] as num).toInt(),
        pendingSignatureContracts: (json['pendingSignatureContracts'] as num)
            .toInt(),
        endingSoonContracts: (json['endingSoonContracts'] as num).toInt(),
        rentedUnits: (json['rentedUnits'] as num).toInt(),
        activeContractsValue: (json['activeContractsValue'] as num).toDouble(),
        outstandingAmount: (json['outstandingAmount'] as num).toDouble(),
        upcomingContracts: [
          for (final e in json['upcomingContracts'] as List<dynamic>)
            CustomerContractBrief.fromJson(e as Map<String, dynamic>),
        ],
      );
}
