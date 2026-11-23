/// Loại hoạt động hiển thị ở mục "Hoạt động gần đây".
enum SalesActivityType {
  reservation('RESERVATION'),
  contract('CONTRACT'),
  company('COMPANY');

  const SalesActivityType(this.code);

  final String code;

  static SalesActivityType fromCode(String code) => values.firstWhere(
    (t) => t.code == code.toUpperCase(),
    orElse: () => reservation,
  );
}

class SalesRecentActivity {
  const SalesRecentActivity({
    required this.type,
    required this.title,
    required this.description,
    required this.occurredAt,
    this.referenceId,
  });

  final SalesActivityType type;

  /// Id phiếu / hợp đồng / công ty liên quan.
  final String? referenceId;
  final String title;
  final String description;
  final DateTime occurredAt;

  factory SalesRecentActivity.fromJson(Map<String, dynamic> json) =>
      SalesRecentActivity(
        type: SalesActivityType.fromCode(json['type'] as String),
        referenceId: json['referenceId'] as String?,
        title: json['title'] as String,
        description: json['description'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String).toLocal(),
      );
}

/// Số liệu Tổng quan của nhân viên kinh doanh (`GET /api/dashboard/sales`).
/// Chỉ tính dữ liệu do chính nhân viên đó tạo.
class SalesDashboardSummary {
  const SalesDashboardSummary({
    required this.totalReservations,
    required this.processingReservations,
    required this.activeContracts,
    required this.companies,
    required this.rejectedContracts,
    required this.reservationsToComplete,
    required this.recentActivities,
  });

  /// Chưa có dữ liệu (đang tải lần đầu).
  const SalesDashboardSummary.empty()
    : totalReservations = 0,
      processingReservations = 0,
      activeContracts = 0,
      companies = 0,
      rejectedContracts = 0,
      reservationsToComplete = 0,
      recentActivities = const [];

  /// Tổng số phiếu đặt thuê đã lập.
  final int totalReservations;

  /// Phiếu đang xử lý: PENDING hoặc APPROVED, chưa quá hạn giữ chỗ.
  final int processingReservations;

  /// Hợp đồng đang hiệu lực: từ SIGNED đến DELIVERED.
  final int activeContracts;

  /// Số công ty khách hàng đang hoạt động (dữ liệu dùng chung, không theo người tạo).
  final int companies;

  /// Hợp đồng bị Manager từ chối, cần chỉnh sửa và gửi lại.
  final int rejectedContracts;

  /// Phiếu PENDING chưa có thiết bị, cần hoàn thiện.
  final int reservationsToComplete;

  final List<SalesRecentActivity> recentActivities;

  int get pendingTaskCount => rejectedContracts + reservationsToComplete;

  factory SalesDashboardSummary.fromJson(Map<String, dynamic> json) =>
      SalesDashboardSummary(
        totalReservations: (json['totalReservations'] as num).toInt(),
        processingReservations: (json['processingReservations'] as num).toInt(),
        reservationsToComplete: (json['reservationsToComplete'] as num).toInt(),
        activeContracts: (json['activeContracts'] as num).toInt(),
        rejectedContracts: (json['rejectedContracts'] as num).toInt(),
        companies: (json['companies'] as num).toInt(),
        recentActivities: (json['recentActivities'] as List<dynamic>)
            .map((e) => SalesRecentActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
