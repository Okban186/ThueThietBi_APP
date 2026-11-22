import 'package:flutter/foundation.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/equipment_model_api.dart';

import '../../data/datasources/reservation_api.dart';
import '../../data/models/reservation.dart';

/// Trạng thái tab "Đặt thuê" của nhân viên kinh doanh.
///
/// Tải danh sách một lần rồi lọc tại client; chi tiết phiếu (kèm thiết bị) tải khi mở.
/// Cũng cung cấp số liệu "Đặt thuê" cho trang Tổng quan.
class ReservationProvider extends ChangeNotifier {
  ReservationProvider(
    this._api,
    this.equipmentModelApi, {
    required this.currentUserId,
  });

  final ReservationApi _api;

  /// Dùng cho màn chọn model thiết bị và kiểm tra số lượng khả dụng.
  final EquipmentModelApi equipmentModelApi;

  final String currentUserId;

  List<Reservation> _reservations = [];
  final Map<String, Reservation> _details = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  String _keyword = '';
  ReservationStatus? _statusFilter;
  bool _onlyMine = false;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get keyword => _keyword;
  ReservationStatus? get statusFilter => _statusFilter;
  bool get onlyMine => _onlyMine;

  List<Reservation> get reservations => List.unmodifiable(_reservations);

  Iterable<Reservation> get _mine =>
      _reservations.where((r) => r.createdBy == currentUserId);

  /// Tổng số phiếu do mình lập.
  int get myTotalCount => _mine.length;

  /// Phiếu đang xử lý: PENDING hoặc APPROVED (chưa tạo hợp đồng).
  int get myOpenCount => _mine.where((r) => r.isOpen).length;

  /// Phiếu PENDING chưa có thiết bị, cần hoàn thiện.
  int get myToCompleteCount =>
      _mine.where((r) => r.isPending && r.itemCount == 0).length;

  List<Reservation> get filteredReservations {
    final keyword = _keyword.trim().toLowerCase();

    return _reservations.where((r) {
      if (_onlyMine && r.createdBy != currentUserId) return false;
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

  void setOnlyMine(bool value) {
    _onlyMine = value;
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
