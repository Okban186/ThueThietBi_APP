import 'package:flutter/foundation.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';

import '../../data/datasources/company_api.dart';
import '../../data/models/company.dart';
import '../../data/models/company_account.dart';

/// Trạng thái tab "Khách hàng" của nhân viên kinh doanh.
///
/// Tải danh sách một lần rồi lọc tại client; chi tiết công ty (kèm tài khoản)
/// được tải khi mở và giữ lại để các màn hình dùng chung.
class CompanyProvider extends ChangeNotifier {
  CompanyProvider(this._api, {required this.currentUserId});

  final CompanyApi _api;

  /// Người đang đăng nhập, dùng cho bộ lọc "Của tôi".
  final String currentUserId;

  List<Company> _companies = [];
  final Map<String, CompanyDetail> _details = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  String _keyword = '';
  CompanyStatus? _statusFilter;
  bool _onlyMine = false;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get keyword => _keyword;
  CompanyStatus? get statusFilter => _statusFilter;
  bool get onlyMine => _onlyMine;

  List<Company> get companies => List.unmodifiable(_companies);

  /// Số công ty do người đang đăng nhập tạo (thẻ "Công ty" ở Tổng quan).
  int get myCompanyCount =>
      _companies.where((c) => c.createdById == currentUserId).length;

  List<Company> get filteredCompanies {
    final keyword = _keyword.trim().toLowerCase();

    return _companies.where((company) {
      if (_onlyMine && company.createdById != currentUserId) return false;
      if (_statusFilter != null && company.companyStatus != _statusFilter) {
        return false;
      }
      if (keyword.isEmpty) return true;

      return [
        company.companyCode,
        company.name,
        company.taxCode,
        company.address,
      ].any((v) => v != null && v.toLowerCase().contains(keyword));
    }).toList();
  }

  CompanyDetail? detailOf(String id) => _details[id];

  Company? findById(String id) {
    for (final company in _companies) {
      if (company.id == id) return company;
    }

    return _details[id]?.company;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _companies = await _api.getCompanies();
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = apiErrorMessage(
        error,
        fallback: 'Không tải được danh sách khách hàng.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tải chi tiết công ty. Ném lỗi gốc để màn hình hiển thị.
  Future<CompanyDetail> loadDetail(String id) async {
    return _store(await _api.getDetail(id));
  }

  void setKeyword(String value) {
    _keyword = value;
    notifyListeners();
  }

  void setStatusFilter(CompanyStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setOnlyMine(bool value) {
    _onlyMine = value;
    notifyListeners();
  }

  // Các thao tác ném lỗi gốc để màn hình hiển thị bằng apiErrorMessage().

  Future<CompanyDetail> createCompany({
    required String name,
    required String taxCode,
    String? address,
  }) async {
    return _store(
      await _api.createCompany(name: name, taxCode: taxCode, address: address),
    );
  }

  Future<CompanyDetail> updateCompany({
    required String id,
    required String name,
    required String taxCode,
    String? address,
  }) async {
    return _store(
      await _api.updateCompany(
        id: id,
        name: name,
        taxCode: taxCode,
        address: address,
      ),
    );
  }

  Future<CompanyDetail> updateStatus(String id, CompanyStatus status) async {
    return _store(await _api.updateStatus(id: id, status: status));
  }

  Future<CompanyDetail> createAccount({
    required String companyId,
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
  }) async {
    return _store(
      await _api.createAccount(
        companyId: companyId,
        username: username,
        password: password,
        fullName: fullName,
        email: email,
        phone: phone,
      ),
    );
  }

  /// Lưu chi tiết và cập nhật (hoặc thêm) công ty trong danh sách.
  CompanyDetail _store(CompanyDetail detail) {
    final company = detail.company;
    _details[company.id] = detail;

    final index = _companies.indexWhere((c) => c.id == company.id);

    _companies = index == -1
        ? [company, ..._companies]
        : [for (final c in _companies) c.id == company.id ? company : c];

    notifyListeners();

    return detail;
  }
}
