import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/sales_dashboard_summary.dart';

/// Gọi API số liệu trang Tổng quan (`/api/dashboard`).
class DashboardApi {
  DashboardApi(this._apiClient);

  final ApiClient _apiClient;

  Future<SalesDashboardSummary> getSalesSummary() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/dashboard/sales',
    );

    return SalesDashboardSummary.fromJson(response.data!);
  }
}
