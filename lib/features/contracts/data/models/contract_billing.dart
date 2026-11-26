/// Loại khoản thanh toán.
enum PaymentTargetType {
  deposit('DEPOSIT', 'Tiền đặt cọc'),
  rentalInstallment('RENTAL_INSTALLMENT', 'Tiền thuê theo đợt'),
  charge('CHARGE', 'Khoản phạt / phát sinh'),
  incidentCharge('INCIDENT_CHARGE', 'Chi phí sự cố');

  const PaymentTargetType(this.code, this.label);

  final String code;
  final String label;

  static PaymentTargetType fromCode(String code) => values.firstWhere(
    (v) => v.code == code.toUpperCase(),
    orElse: () => PaymentTargetType.charge,
  );
}

/// Phương thức thanh toán.
enum PaymentMethod {
  vnpay('VNPAY', 'VNPAY QR'),
  cash('CASH', 'Tiền mặt');

  const PaymentMethod(this.code, this.label);

  final String code;
  final String label;

  static PaymentMethod fromCode(String code) =>
      code.toUpperCase() == 'CASH' ? cash : vnpay;
}

/// Trạng thái giao dịch thanh toán.
enum PaymentTransactionStatus {
  pending('PENDING', 'Đang chờ'),
  verified('VERIFIED', 'Đã xác nhận'),
  failed('FAILED', 'Thất bại'),
  cancelled('CANCELLED', 'Đã hủy'),
  expired('EXPIRED', 'Hết hạn');

  const PaymentTransactionStatus(this.code, this.label);

  final String code;
  final String label;

  static PaymentTransactionStatus fromCode(String code) => values.firstWhere(
    (v) => v.code == code.toUpperCase(),
    orElse: () => PaymentTransactionStatus.pending,
  );
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.rentalContractId,
    required this.contractCode,
    required this.targetType,
    required this.paymentMethod,
    required this.txnRef,
    required this.amount,
    required this.orderInfo,
    required this.status,
    required this.createdAt,
    this.rentalChargeId,
    this.incidentChargeId,
    this.paymentUrl,
    this.expiresAt,
    this.vnpTransactionNo,
    this.vnpBankCode,
    this.vnpResponseCode,
    this.receiptUrl,
    this.createdByName,
    this.verifiedByName,
    this.verifiedAt,
    this.rejectedReason,
    this.note,
  });

  final String id, rentalContractId, contractCode, txnRef, orderInfo;
  final String? rentalChargeId,
      incidentChargeId,
      paymentUrl,
      vnpTransactionNo,
      vnpBankCode,
      vnpResponseCode,
      receiptUrl,
      createdByName,
      verifiedByName,
      rejectedReason,
      note;
  final PaymentTargetType targetType;
  final PaymentMethod paymentMethod;
  final PaymentTransactionStatus status;
  final double amount;
  final DateTime createdAt;
  final DateTime? expiresAt, verifiedAt;

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        id: json['id'] as String,
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        rentalChargeId: json['rentalChargeId'] as String?,
        incidentChargeId: json['incidentChargeId'] as String?,
        targetType: PaymentTargetType.fromCode(json['targetType'] as String),
        paymentMethod: PaymentMethod.fromCode(json['paymentMethod'] as String),
        txnRef: json['txnRef'] as String,
        amount: _num(json['amount']),
        orderInfo: json['orderInfo'] as String? ?? '',
        status: PaymentTransactionStatus.fromCode(json['status'] as String),
        paymentUrl: json['paymentUrl'] as String?,
        expiresAt: _date(json['expiresAt']),
        vnpTransactionNo: json['vnpTransactionNo'] as String?,
        vnpBankCode: json['vnpBankCode'] as String?,
        vnpResponseCode: json['vnpResponseCode'] as String?,
        receiptUrl: json['receiptUrl'] as String?,
        createdByName: json['createdByName'] as String?,
        verifiedByName: json['verifiedByName'] as String?,
        verifiedAt: _date(json['verifiedAt']),
        rejectedReason: json['rejectedReason'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class ContractInstallment {
  const ContractInstallment({
    required this.id,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.periodStart,
    this.periodEnd,
    this.dueDate,
    this.paidAt,
    this.note,
    this.hasPendingCash = false,
  });

  final String id, description, status;
  final int installmentNumber, totalInstallments;
  final DateTime? periodStart, periodEnd, dueDate, paidAt;
  final double amount, paidAmount, remainingAmount;
  final String? note;
  final bool hasPendingCash;

  bool get isPayable =>
      remainingAmount > 0 && (status == 'UNPAID' || status == 'PARTIALLY_PAID');

  bool get isPaid => status == 'PAID';

  String get statusLabel => switch (status.toUpperCase()) {
    'PAID' => 'Đã thanh toán',
    'PARTIALLY_PAID' => 'Thanh toán 1 phần',
    'WAIVED' => 'Miễn giảm',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa thanh toán',
  };

  factory ContractInstallment.fromJson(Map<String, dynamic> json) =>
      ContractInstallment(
        id: json['id'] as String,
        installmentNumber: (json['installmentNumber'] as num).toInt(),
        totalInstallments: (json['totalInstallments'] as num).toInt(),
        description: json['description'] as String? ?? '',
        periodStart: _dateOnly(json['periodStart']),
        periodEnd: _dateOnly(json['periodEnd']),
        dueDate: _dateOnly(json['dueDate']),
        amount: _num(json['amount']),
        paidAmount: _num(json['paidAmount']),
        remainingAmount: _num(json['remainingAmount']),
        status: json['status'] as String? ?? 'UNPAID',
        paidAt: _date(json['paidAt']),
        note: json['note'] as String?,
        hasPendingCash: json['hasPendingCash'] as bool? ?? false,
      );
}

class ContractPenalty {
  const ContractPenalty({
    required this.id,
    required this.sourceKind,
    required this.chargeType,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.createdAt,
    this.rentalChargeId,
    this.incidentChargeId,
    this.incidentCode,
    this.serialNumber,
    this.isOffsetByDeposit = false,
    this.paidAt,
    this.note,
    this.hasPendingCash = false,
  });

  final String id, sourceKind, chargeType, description, status;
  final String? rentalChargeId, incidentChargeId, incidentCode, serialNumber, note;
  final double amount, paidAmount, remainingAmount;
  final bool isOffsetByDeposit, hasPendingCash;
  final DateTime createdAt;
  final DateTime? paidAt;

  bool get isPayable =>
      remainingAmount > 0 &&
      (status == 'UNPAID' || status == 'PARTIALLY_PAID' || status == 'PENDING');

  String get chargeTypeLabel => switch (chargeType.toUpperCase()) {
    'LATE_RETURN' => 'Trả thiết bị trễ hạn',
    'EARLY_CANCELLATION' => 'Hủy hợp đồng trước hạn',
    'DAMAGE' => 'Hư hỏng thiết bị',
    'LOSS' => 'Mất thiết bị',
    'TRANSPORT' => 'Phí vận chuyển phát sinh',
    'LATE_PAYMENT' => 'Chậm thanh toán',
    'REPAIR' => 'Sửa chữa sự cố',
    'REPLACEMENT' => 'Thay linh kiện / đổi máy',
    _ => 'Phí phát sinh khác',
  };

  String get statusLabel => switch (status.toUpperCase()) {
    'PAID' || 'CHARGED' => 'Đã thanh toán',
    'PARTIALLY_PAID' => 'Thanh toán 1 phần',
    'WAIVED' => 'Miễn giảm',
    'CANCELLED' => 'Đã hủy',
    'PENDING' => 'Chờ thanh toán',
    _ => 'Chưa thanh toán',
  };

  factory ContractPenalty.fromJson(Map<String, dynamic> json) => ContractPenalty(
    id: json['id'] as String,
    sourceKind: json['sourceKind'] as String? ?? 'RENTAL_CHARGE',
    rentalChargeId: json['rentalChargeId'] as String?,
    incidentChargeId: json['incidentChargeId'] as String?,
    chargeType: json['chargeType'] as String? ?? 'OTHER',
    description: json['description'] as String? ?? '',
    incidentCode: json['incidentCode'] as String?,
    serialNumber: json['serialNumber'] as String?,
    amount: _num(json['amount']),
    paidAmount: _num(json['paidAmount']),
    remainingAmount: _num(json['remainingAmount']),
    status: json['status'] as String? ?? 'UNPAID',
    isOffsetByDeposit: json['isOffsetByDeposit'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    paidAt: _date(json['paidAt']),
    note: json['note'] as String?,
    hasPendingCash: json['hasPendingCash'] as bool? ?? false,
  );
}

class ContractBillingSummary {
  const ContractBillingSummary({
    required this.rentalContractId,
    required this.contractCode,
    required this.rentalType,
    required this.startDate,
    required this.endDate,
    required this.rentalDays,
    required this.equipmentRentalTotal,
    required this.servicesTotal,
    required this.contractTotalAmount,
    required this.depositRequiredAmount,
    required this.depositPaidAmount,
    required this.depositAppliedAmount,
    required this.depositRefundedAmount,
    required this.depositRemainingAmount,
    required this.hasPendingCashDeposit,
    required this.installmentsTotal,
    required this.installmentsPaid,
    required this.installmentsRemaining,
    required this.penaltiesTotal,
    required this.penaltiesPaid,
    required this.penaltiesRemaining,
    required this.totalOutstandingAmount,
    required this.installments,
    required this.penalties,
    required this.transactions,
  });

  final String rentalContractId, contractCode, rentalType;
  final DateTime startDate, endDate;
  final int rentalDays;
  final double equipmentRentalTotal,
      servicesTotal,
      contractTotalAmount,
      depositRequiredAmount,
      depositPaidAmount,
      depositAppliedAmount,
      depositRefundedAmount,
      depositRemainingAmount,
      installmentsTotal,
      installmentsPaid,
      installmentsRemaining,
      penaltiesTotal,
      penaltiesPaid,
      penaltiesRemaining,
      totalOutstandingAmount;
  final bool hasPendingCashDeposit;
  final List<ContractInstallment> installments;
  final List<ContractPenalty> penalties;
  final List<PaymentTransaction> transactions;

  factory ContractBillingSummary.fromJson(Map<String, dynamic> json) =>
      ContractBillingSummary(
        rentalContractId: json['rentalContractId'] as String,
        contractCode: json['contractCode'] as String? ?? '',
        rentalType: json['rentalType'] as String? ?? 'SHORT_TERM',
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        rentalDays: (json['rentalDays'] as num?)?.toInt() ?? 0,
        equipmentRentalTotal: _num(json['equipmentRentalTotal']),
        servicesTotal: _num(json['servicesTotal']),
        contractTotalAmount: _num(json['contractTotalAmount']),
        depositRequiredAmount: _num(json['depositRequiredAmount']),
        depositPaidAmount: _num(json['depositPaidAmount']),
        depositAppliedAmount: _num(json['depositAppliedAmount']),
        depositRefundedAmount: _num(json['depositRefundedAmount']),
        depositRemainingAmount: _num(json['depositRemainingAmount']),
        hasPendingCashDeposit: json['hasPendingCashDeposit'] as bool? ?? false,
        installmentsTotal: _num(json['installmentsTotal']),
        installmentsPaid: _num(json['installmentsPaid']),
        installmentsRemaining: _num(json['installmentsRemaining']),
        penaltiesTotal: _num(json['penaltiesTotal']),
        penaltiesPaid: _num(json['penaltiesPaid']),
        penaltiesRemaining: _num(json['penaltiesRemaining']),
        totalOutstandingAmount: _num(json['totalOutstandingAmount']),
        installments: (json['installments'] as List<dynamic>? ?? const [])
            .map((e) => ContractInstallment.fromJson(e as Map<String, dynamic>))
            .toList(),
        penalties: (json['penalties'] as List<dynamic>? ?? const [])
            .map((e) => ContractPenalty.fromJson(e as Map<String, dynamic>))
            .toList(),
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

DateTime? _dateOnly(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
