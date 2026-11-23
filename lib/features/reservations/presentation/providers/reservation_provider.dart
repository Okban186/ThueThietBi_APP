import 'package:flutter/foundation.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';

import '../../data/datasources/reservation_api.dart';
import '../../data/models/reservation.dart';

/// Trạng thái tab "Đặt thuê" của nhân viên kinh doanh.
///
/// Tải danh sách một lần rồi lọc tại client; chi tiết phiếu (kèm thiết bị) tải khi mở.
class ReservationProvider extends ChangeNotifier {
  ReservationProvider(this._api, this.equipmentModelApi);

  final ReservationApi _api;

  /// Dùng cho màn chọn model thiết bị và kiểm tra số lượng khả dụng.
  final EquipmentModelApi equipmentModelApi;

  List<Reservation> _reservations = [];
  final Map<String, Reservation> _details = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  String _keyword = '';
  ReservationStatus? _statusFilter;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get keyword => _keyword;
  ReservationStatus? get statusFilter => _statusFilter;

  List<Reservation> get reservations => List.unmodifiable(_reservations);

  List<Reservation> get filteredReservations {
    final keyword = _keyword.trim().toLowerCase();

    return _reservations.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (keyword.isEmpty) return true;

      return [
        r.reservationCode,
        r.companyName,
        r.companyCode,
        r.contactName,
        r.contactPhone,
      ].any((v) => v != null && v.toLowerCase().contains(keyword));
    }).toList();
  }

  Reservation? detailOf(String id) => _details[id];

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reservations = await _api.getReservations();
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = apiErrorMessage(
        error,
        fallback: 'Không tải được danh sách phiếu đặt thuê.',
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

  void setStatusFilter(ReservationStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  // Các thao tác ném lỗi gốc để màn hình hiển thị bằng apiErrorMessage().

  Future<Reservation> loadDetail(String id) async =>
      _store(await _api.getDetail(id));

  Future<Reservation> create(ReservationInput input) async =>
      _store(await _api.create(input));

  Future<Reservation> update(String id, ReservationInput input) async =>
      _store(await _api.update(id, input));

  Future<Reservation> updateItems(
    String id,
    Map<String, int> quantities,
  ) async => _store(await _api.updateItems(id, quantities));

  Future<Reservation> approve(String id) async =>
      _store(await _api.approve(id));

  Future<Reservation> reopen(String id) async => _store(await _api.reopen(id));

  Future<Reservation> cancel(String id, {String? reason}) async =>
      _store(await _api.cancel(id, reason: reason));

  /// Lưu chi tiết và cập nhật (hoặc thêm) phiếu trong danh sách.
  Reservation _store(Reservation detail) {
    _details[detail.id] = detail;

    final index = _reservations.indexWhere((r) => r.id == detail.id);

    _reservations = index == -1
        ? [detail, ..._reservations]
        : [for (final r in _reservations) r.id == detail.id ? detail : r];

    notifyListeners();

    return detail;
  }
}
