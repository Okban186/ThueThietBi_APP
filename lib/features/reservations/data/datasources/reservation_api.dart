import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../models/reservation.dart';

/// Gọi API phiếu giữ chỗ (`/api/reservations`).
/// Các thao tác trả về chi tiết phiếu (kèm thiết bị) sau khi lưu.
class ReservationApi {
  ReservationApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Reservation>> getReservations() async {
    final response = await _apiClient.get<List<dynamic>>('/api/reservations');

    return response.data!
        .map((json) => Reservation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Reservation> getDetail(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/reservations/$id',
    );

    return Reservation.fromDetailJson(response.data!);
  }

  Future<Reservation> create(ReservationInput input) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/reservations',
      data: input.toJson(),
    );

    return Reservation.fromDetailJson(response.data!);
  }

  Future<Reservation> update(String id, ReservationInput input) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/reservations/$id',
      data: input.toJson(),
    );

    return Reservation.fromDetailJson(response.data!);
  }

  /// Thay toàn bộ danh sách thiết bị: `{ modelId: quantity }`.
  Future<Reservation> updateItems(
    String id,
    Map<String, int> quantities,
  ) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/reservations/$id/items',
      data: {
        'items': [
          for (final entry in quantities.entries)
            {'equipmentModelId': entry.key, 'quantity': entry.value},
        ],
      },
    );

    return Reservation.fromDetailJson(response.data!);
  }

  Future<Reservation> approve(String id) => _action(id, 'approve');

  Future<Reservation> reopen(String id) => _action(id, 'reopen');

  Future<Reservation> cancel(String id, {String? reason}) =>
      _action(id, 'cancel', data: {'reason': reason});

  Future<Reservation> _action(String id, String action, {Object? data}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/reservations/$id/$action',
      data: data,
    );

    return Reservation.fromDetailJson(response.data!);
  }
}

/// Dữ liệu lập/sửa phiếu (thông tin chung, không gồm thiết bị).
class ReservationInput {
  const ReservationInput({
    required this.companyId,
    required this.requestedFrom,
    required this.requestedTo,
    required this.contactName,
    required this.contactPhone,
    this.note,
  });

  final String companyId;
  final DateTime requestedFrom, requestedTo;
  final String contactName, contactPhone;
  final String? note;

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'requestedFrom': DateFormatter.isoDate(requestedFrom),
    'requestedTo': DateFormatter.isoDate(requestedTo),
    'contactName': contactName,
    'contactPhone': contactPhone,
    'note': note,
  };
}
