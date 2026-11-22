import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/company.dart';
import '../models/company_account.dart';

/// Gọi API công ty khách hàng (`/api/companies`).
class CompanyApi {
  CompanyApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Company>> getCompanies() async {
    final response = await _apiClient.get<List<dynamic>>('/api/companies');

    return response.data!
        .map((json) => Company.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CompanyDetail> getDetail(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/companies/$id',
    );

    return CompanyDetail.fromJson(response.data!);
  }

  Future<CompanyDetail> createCompany({
    required String name,
    required String taxCode,
    String? address,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/companies',
      data: {'name': name, 'taxCode': taxCode, 'address': address},
    );

    return CompanyDetail.fromJson(response.data!);
  }

  Future<CompanyDetail> updateCompany({
    required String id,
    required String name,
    required String taxCode,
    String? address,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/companies/$id',
      data: {'name': name, 'taxCode': taxCode, 'address': address},
    );

    return CompanyDetail.fromJson(response.data!);
  }

  Future<CompanyDetail> updateStatus({
    required String id,
    required CompanyStatus status,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/companies/$id/status',
      data: {'status': status.code},
    );

    return CompanyDetail.fromJson(response.data!);
  }

  Future<CompanyDetail> createAccount({
    required String companyId,
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/companies/$companyId/accounts',
      data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'email': email,
        'phone': phone,
      },
    );

    return CompanyDetail.fromJson(response.data!);
  }
}
