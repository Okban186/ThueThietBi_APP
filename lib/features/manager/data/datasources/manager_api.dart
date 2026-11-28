import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

class ManagerApi {
  ManagerApi(this._api);

  final ApiClient _api;

  // --- DASHBOARD ---
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await _api.get<Map<String, dynamic>>('/api/dashboard/manager');
    return res.data ?? <String, dynamic>{};
  }

  // --- HỢP ĐỒNG ---
  Future<void> approveContract(String id) async {
    await _api.post<dynamic>('/api/rental-contracts/$id/approve');
  }

  Future<void> rejectContract(String id, String reason) async {
    await _api.post<dynamic>(
      '/api/rental-contracts/$id/reject',
      data: {'reason': reason},
    );
  }

  Future<void> confirmSignedContract(String id) async {
    await _api.post<dynamic>('/api/rental-contracts/$id/confirm-signed');
  }

  Future<void> rejectSignedContract(String id, String reason) async {
    await _api.post<dynamic>(
      '/api/rental-contracts/$id/reject-signed',
      data: {'reason': reason},
    );
  }

  Future<void> decideCancelContract(
    String id, {
    required bool approve,
    String? reason,
    double? penaltyAmount,
    double? transportFeeAmount,
  }) async {
    await _api.post<dynamic>(
      '/api/rental-contracts/$id/manager-cancel',
      queryParameters: {'approve': approve},
      data: {
        'reason': reason,
        if (penaltyAmount != null) 'penaltyAmount': penaltyAmount,
        if (transportFeeAmount != null) 'transportFeeAmount': transportFeeAmount,
      },
    );
  }

  // --- KỸ THUẬT VIÊN & LẬP / GHÉP CHUYẾN GIAO ---
  Future<List<Map<String, dynamic>>> getTechniciansAvailability({
    DateTime? startAt,
    int? durationMinutes,
    String? excludeAssignmentId,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/technicians/availability',
      queryParameters: {
        if (startAt != null) 'startAt': startAt.toUtc().toIso8601String(),
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (excludeAssignmentId != null)
          'excludeAssignmentId': excludeAssignmentId,
      },
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getUnscheduledContracts() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/delivery-trips/unscheduled-contracts',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMergeableTrips(DateTime date) async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/delivery-trips/mergeable',
      queryParameters: {'date': DateFormatter.isoDate(date)},
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> previewDeliveryTrip({
    required List<String> contractIds,
    required DateTime scheduledStartAt,
    String? existingAssignmentId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/manager/delivery-trips/preview',
      data: {
        'contractIds': contractIds,
        'scheduledStartAt': scheduledStartAt.toUtc().toIso8601String(),
        if (existingAssignmentId != null)
          'existingAssignmentId': existingAssignmentId,
      },
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<void> createDeliveryTrip({
    required List<String> contractIds,
    required DateTime scheduledStartAt,
    required String leaderStaffId,
    required List<String> memberStaffIds,
    String? title,
    String? note,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/delivery-trips',
      data: {
        'contractIds': contractIds,
        'scheduledStartAt': scheduledStartAt.toUtc().toIso8601String(),
        'leaderStaffId': leaderStaffId,
        'memberStaffIds': memberStaffIds,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> mergeIntoDeliveryTrip({
    required String assignmentId,
    required List<String> contractIds,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/delivery-trips/$assignmentId/merge',
      data: {'contractIds': contractIds},
    );
  }

  // --- LỊCH TRÌNH NGÀY ---
  Future<List<Map<String, dynamic>>> getDailySchedule(
    DateTime date, {
    String? staffId,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/schedule',
      queryParameters: {
        'date': DateFormatter.isoDate(date),
        if (staffId != null) 'staffId': staffId,
      },
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  // --- SỰ CỐ TỪ COMPANY ---
  Future<List<Map<String, dynamic>>> getIncidents({String? status}) async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/incidents',
      queryParameters: {if (status != null) 'status': status},
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<void> assignRemoteIncident(
    String incidentId,
    String technicianStaffId, {
    String? note,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/incidents/$incidentId/assign-remote',
      data: {
        'technicianStaffId': technicianStaffId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> dispatchIncidentTeam({
    required String incidentId,
    required DateTime scheduledStartAt,
    required int durationMinutes,
    required String leaderStaffId,
    required List<String> memberStaffIds,
    String? note,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/incidents/$incidentId/dispatch',
      data: {
        'scheduledStartAt': scheduledStartAt.toUtc().toIso8601String(),
        'estimatedDurationMinutes': durationMinutes,
        'leaderStaffId': leaderStaffId,
        'memberStaffIds': memberStaffIds,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  // --- DUYỆT YÊU CẦU NHÂN VIÊN ---
  Future<List<Map<String, dynamic>>> getPendingReplacements() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/approvals/replacements',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<void> decideReplacement(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/approvals/replacements/$id/decide',
      data: {'approve': approve, 'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> getPendingHandovers() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/approvals/handovers',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<void> decideHandover(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/approvals/handovers/$id/decide',
      data: {'approve': approve, 'reason': reason},
    );
  }

  Future<void> recordHandoverFailure(
    String id, {
    required String reason,
    double? penaltyAmount,
    bool reschedule = true,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/handovers/$id/record-failure',
      data: {
        'reason': reason,
        if (penaltyAmount != null) 'penaltyAmount': penaltyAmount,
        'reschedule': reschedule,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPendingDisposals() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/approvals/disposals',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<void> decideDisposal(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _api.post<dynamic>(
      '/api/manager/approvals/disposals/$id/decide',
      data: {'approve': approve, 'reason': reason},
    );
  }

  // --- GIAO BÙ & HÓA ĐƠN THU TRỰC TIẾP CHỜ DUYỆT ---
  Future<List<Map<String, dynamic>>> getSupplementaryOverview() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/delivery-trips/supplementary-overview',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPendingCashPayments() async {
    final res = await _api.get<List<dynamic>>('/api/payments/pending-cash');
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<void> verifyCashPayment(String transactionId) async {
    await _api.post<dynamic>('/api/payments/$transactionId/verify-cash');
  }

  Future<void> rejectCashPayment(String transactionId, String reason) async {
    await _api.post<dynamic>(
      '/api/payments/$transactionId/reject-cash',
      data: {'reason': reason.trim()},
    );
  }

  // --- DUYỆT ĐỀ XUẤT PHẠT / BỒI THƯỜNG SỰ CỐ ---
  Future<List<Map<String, dynamic>>> getPendingIncidentCharges() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/approvals/incident-charges',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> decideIncidentCharge(
    String chargeId, {
    required String decision,
    double? adjustedAmount,
    String? managerNote,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/manager/approvals/incident-charges/$chargeId/decide',
      data: {
        'decision': decision,
        if (adjustedAmount != null) 'adjustedAmount': adjustedAmount,
        if (managerNote != null && managerNote.trim().isNotEmpty)
          'managerNote': managerNote.trim(),
      },
    );
    return res.data ?? const {};
  }

  // --- CHUYẾN THU HỒI CUỐI KỲ / HẾT HẠN / HỦY HĐ (RETRIEVAL) ---
  Future<List<Map<String, dynamic>>> getPendingRetrievalContracts() async {
    final res = await _api.get<List<dynamic>>(
      '/api/manager/retrieval-trips/pending-contracts',
    );
    return (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> previewRetrievalTrip({
    required List<String> contractIds,
    required DateTime scheduledStartAt,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/manager/retrieval-trips/preview',
      data: {
        'contractIds': contractIds,
        'scheduledStartAt': scheduledStartAt.toUtc().toIso8601String(),
      },
    );
    return res.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createRetrievalTrip({
    required List<String> contractIds,
    required DateTime scheduledStartAt,
    required String leaderStaffId,
    List<String> memberStaffIds = const [],
    String? title,
    String? note,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/manager/retrieval-trips',
      data: {
        'contractIds': contractIds,
        'scheduledStartAt': scheduledStartAt.toUtc().toIso8601String(),
        'leaderStaffId': leaderStaffId,
        'memberStaffIds': memberStaffIds,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return res.data ?? const <String, dynamic>{};
  }

  // --- QUYẾT TOÁN CUỐI HỢP ĐỒNG & HOÀN CỌC ---
  Future<Map<String, dynamic>> getSettlementPreview(String contractId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/rental-contracts/$contractId/settlement-preview',
    );
    return res.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> settleContract(
    String contractId, {
    bool applyDepositToUnpaidCharges = true,
    bool refundRemainingDeposit = true,
    double? customRefundAmount,
    String? note,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/rental-contracts/$contractId/settle',
      data: {
        'applyDepositToUnpaidCharges': applyDepositToUnpaidCharges,
        'refundRemainingDeposit': refundRemainingDeposit,
        if (customRefundAmount != null)
          'customRefundAmount': customRefundAmount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return res.data ?? const <String, dynamic>{};
  }

}
