import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/features/contracts/data/models/contract_billing.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';
import 'package:thuethietbi_app/features/handovers/data/models/handover_preparation.dart';

import '../models/customer_dashboard_summary.dart';

/// Gọi API cổng khách hàng (`/api/customer`, role COMPANY): chỉ dữ liệu của
/// công ty mình, hợp đồng chỉ hiện từ khi đã được duyệt (chờ ký) trở đi.
class CustomerPortalApi {
  CustomerPortalApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CustomerDashboardSummary> getDashboard() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/dashboard',
    );

    return CustomerDashboardSummary.fromJson(response.data!);
  }

  Future<CustomerCompany> getCompany() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/company',
    );

    return CustomerCompany.fromJson(response.data!);
  }

  Future<List<RentalContract>> getContracts() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/customer/contracts',
    );

    return response.data!
        .map((json) => RentalContract.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<RentalContract> getContract(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/contracts/$id',
    );

    return RentalContract.fromDetailJson(response.data!);
  }

  /// Các đợt giao của hợp đồng (trừ phiếu đã hủy), kèm máy trong từng đợt.
  Future<List<HandoverDetail>> getHandovers(String contractId) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/api/customer/contracts/$contractId/handovers',
    );

    return response.data!
        .map((e) => HandoverDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tổng quan chi phí, các đợt thanh toán, khoản phạt/bồi thường và giao dịch thanh toán.
  Future<ContractBillingSummary> getBilling(String contractId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/customer/contracts/$contractId/billing',
    );

    return ContractBillingSummary.fromJson(response.data!);
  }

  /// Hợp đồng PDF điền sẵn từ mẫu.
  Future<Uint8List> exportPdf(String id) async {
    final response = await _apiClient.get<List<int>>(
      '/api/customer/contracts/$id/pdf',
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }

  /// Tải file từ URL có chữ ký của Cloudinary (bản hợp đồng đã ký).
  /// Dùng Dio riêng vì URL không thuộc Backend, không gửi token.
  Future<Uint8List> downloadFile(String url) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }
}
