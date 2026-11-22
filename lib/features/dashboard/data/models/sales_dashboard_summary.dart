/// Loại hoạt động hiển thị ở mục "Hoạt động gần đây".
enum SalesActivityType { reservation, contract, company }

class SalesRecentActivity {
  const SalesRecentActivity({
    required this.type,
    required this.title,
    required this.description,
    required this.occurredAt,
  });

  final SalesActivityType type;
  final String title;
  final String description;
  final DateTime occurredAt;
}

/// Số liệu tổng quan của nhân viên kinh doanh.
///
/// Hiện dùng dữ liệu mẫu ([SalesDashboardSummary.sample]).
/// Khi Backend có API thống kê, bổ sung `fromJson` và datasource tương ứng.
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

  /// Tổng số phiếu đặt thuê do Sales tạo.
  final int totalReservations;

  /// Phiếu đang xử lý: PENDING hoặc APPROVED chưa tạo hợp đồng.
  final int processingReservations;

  /// Hợp đồng đang hiệu lực: từ SIGNED đến DELIVERED.
  final int activeContracts;

  /// Số công ty do Sales tạo (companies.created_by).
  final int companies;

  /// Hợp đồng bị Manager từ chối, cần chỉnh sửa và gửi lại.
  final int rejectedContracts;

  /// Phiếu PENDING cần hoàn thiện (thêm model) trước khi xác nhận.
  final int reservationsToComplete;

  final List<SalesRecentActivity> recentActivities;

  int get pendingTaskCount => rejectedContracts + reservationsToComplete;

  factory SalesDashboardSummary.sample({DateTime? now}) {
    final current = now ?? DateTime.now();

    return SalesDashboardSummary(
      totalReservations: 12,
      processingReservations: 3,
      activeContracts: 8,
      companies: 15,
      rejectedContracts: 1,
      reservationsToComplete: 2,
      recentActivities: [
        SalesRecentActivity(
          type: SalesActivityType.reservation,
          title: 'Phiếu PH-2026-0042 vừa được tạo',
          description: 'Công ty TNHH ABC',
          occurredAt: current.subtract(const Duration(hours: 2)),
        ),
        SalesRecentActivity(
          type: SalesActivityType.contract,
          title: 'Hợp đồng HD-2026-0018 đã được duyệt',
          description: 'Công ty CP XYZ',
          occurredAt: current.subtract(const Duration(hours: 5)),
        ),
        SalesRecentActivity(
          type: SalesActivityType.company,
          title: 'Thêm khách hàng mới',
          description: 'Công ty TNHH Thịnh Vượng',
          occurredAt: current.subtract(const Duration(days: 1)),
        ),
      ],
    );
  }
}
