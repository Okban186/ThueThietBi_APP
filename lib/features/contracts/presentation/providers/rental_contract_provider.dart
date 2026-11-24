import 'package:flutter/foundation.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';

import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';

import '../../data/datasources/rental_contract_api.dart';
import '../../data/models/rental_contract.dart';
import '../../data/models/rental_contract_item.dart';
import '../../data/models/rental_pricing.dart';
import '../../data/models/rental_contract_suggestion.dart';

/// Trạng thái tab "Hợp đồng" của nhân viên kinh doanh.
/// Tải danh sách một lần rồi lọc tại client; chi tiết tải khi mở.
class RentalContractProvider extends ChangeNotifier {
  RentalContractProvider(this.api, this.equipmentModelApi);

  /// Dùng trực tiếp cho upload ảnh và lấy gợi ý ở màn hình form.
  final RentalContractApi api;

  /// Lấy giá niêm yết hiện tại khi sửa hợp đồng.
  final EquipmentModelApi equipmentModelApi;

  List<RentalContract> _contracts = [];
  final Map<String, RentalContract> _details = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  String _keyword = '';
  RentalContractStatus? _statusFilter;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get keyword => _keyword;
  RentalContractStatus? get statusFilter => _statusFilter;

  List<RentalContract> get contracts => List.unmodifiable(_contracts);

  List<RentalContract> get filteredContracts {
    final keyword = _keyword.trim().toLowerCase();

    return _contracts.where((c) {
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (keyword.isEmpty) return true;

      return [
        c.contractCode,
        c.companyName,
        c.companyCode,
        c.reservationCode,
      ].any((v) => v != null && v.toLowerCase().contains(keyword));
    }).toList();
  }

  RentalContract? detailOf(String id) => _details[id];

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contracts = await api.getContracts();
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = apiErrorMessage(
        error,
        fallback: 'Không tải được danh sách hợp đồng.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setKeyword(String value) {
    _keyword = value;
    notifyListeners();
  }

  void setStatusFilter(RentalContractStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  // Các thao tác ném lỗi gốc để màn hình hiển thị.

  Future<RentalContractSuggestion> getSuggestion(String reservationId) =>
      api.getSuggestion(reservationId);

  /// Dòng thiết bị tính lại theo giá niêm yết hiện tại của model, giống cách
  /// Backend tính khi lưu (dùng cho form sửa hợp đồng).
  Future<List<RentalContractItem>> repriceItems(
    List<RentalContractItem> items,
    int rentalDays,
  ) async {
    final models = await Future.wait(
      items.map((i) => equipmentModelApi.getModel(i.equipmentModelId)),
    );

    return [
      for (var i = 0; i < items.length; i++)
        items[i].copyWith(
          billingUnit: BillingUnit.forDays(rentalDays),
          agreedUnitPrice: RentalPricing.unitPriceFor(
            rentalDays,
            models[i].rentalPriceDaily,
            models[i].rentalPriceMonthly,
          ),
        ),
    ];
  }

  Future<RentalContract> loadDetail(String id) async =>
      _store(await api.getDetail(id));

  Future<RentalContract> create(
    String reservationId,
    RentalContractInput input,
  ) async => _store(await api.create(reservationId, input));

  Future<RentalContract> update(String id, RentalContractInput input) async =>
      _store(await api.update(id, input));

  Future<RentalContract> submit(String id) async =>
      _store(await api.submit(id));

  Future<RentalContract> cancel(String id, {String? reason}) async =>
      _store(await api.cancel(id, reason: reason));

  /// Upload file PDF bản hợp đồng đã ký rồi chuyển hợp đồng sang "Đã ký".
  Future<RentalContract> markSigned(String id, String pdfPath) async {
    final fileId = await api.uploadSignedPdf(pdfPath);
    return _store(await api.markSigned(id, fileId));
  }

  RentalContract _store(RentalContract contract) {
    _details[contract.id] = contract;

    final index = _contracts.indexWhere((c) => c.id == contract.id);

    _contracts = index == -1
        ? [contract, ..._contracts]
        : [for (final c in _contracts) c.id == contract.id ? contract : c];

    notifyListeners();

    return contract;
  }
}
