import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/payment_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/contract_billing.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/vnpay_qr_sheet.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/utils/maps_launcher.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import '../widgets/cash_payment_sheet.dart';
import '../widgets/technician_fail_handover_sheet.dart';
import 'technician_complete_handover_screen.dart';
import 'technician_complete_retrieval_screen.dart';
import 'technician_handover_detail_screen.dart';

/// Màn chi tiết chuyến giao hàng của Kỹ thuật viên:
/// - Phân quyền rõ KTV trưởng vs thành viên đi cùng.
/// - Mở Google Maps chỉ đường theo từng chặng & chặng về Kho chính.
/// - Thanh toán đợt 1 (QR VNPay / Tiền mặt) hiển thị rõ ngay trên chặng.
/// - Sau khi giao xong, bấm "Xem chi tiết biên bản & minh chứng" để xem đầy đủ ảnh/video, máy đạt, chi tiết máy lỗi & phiếu thu hồi.
class TechnicianTripDetailScreen extends StatefulWidget {
  const TechnicianTripDetailScreen({
    super.key,
    required this.api,
    required this.paymentApi,
    required this.assignmentId,
  });

  final TechnicianApi api;
  final PaymentApi paymentApi;
  final String assignmentId;

  static Future<bool?> open(
    BuildContext context, {
    required TechnicianApi api,
    required PaymentApi paymentApi,
    required String assignmentId,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TechnicianTripDetailScreen(
          api: api,
          paymentApi: paymentApi,
          assignmentId: assignmentId,
        ),
      ),
    );
  }

  @override
  State<TechnicianTripDetailScreen> createState() =>
      _TechnicianTripDetailScreenState();
}

class _TechnicianTripDetailScreenState
    extends State<TechnicianTripDetailScreen> {
  TechnicianAssignmentDetail? _detail;
  bool _loading = true;
  bool _acting = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getAssignmentDetail(widget.assignmentId);
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được chi tiết chuyến giao.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startTrip() async {
    setState(() => _acting = true);
    try {
      final updated = await widget.api.startAssignment(widget.assignmentId);
      if (mounted) {
        setState(() {
          _detail = updated;
          _changed = true;
        });
        _msg('Đã bắt đầu xuất phát! Chúc đội đi giao an toàn.');
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể bắt đầu chuyến giao.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openCompleteStop(TechnicianHandoverStopDetail stop) async {
    final result = await TechnicianCompleteHandoverScreen.open(
      context,
      api: widget.api,
      stop: stop,
    );
    if (result != null && mounted) {
      _changed = true;
      _msg(result.message);
      await _load();
    }
  }

  Future<void> _openFailStop(TechnicianHandoverStopDetail stop) async {
    final result = await TechnicianFailHandoverSheet.open(
      context,
      api: widget.api,
      stop: stop,
    );
    if (result != null && mounted) {
      _changed = true;
      _msg(result.message);
      await _load();
    }
  }

  Future<void> _openHandoverFullDetail(
    TechnicianAssignmentDetail trip,
    TechnicianHandoverStopDetail stop,
  ) async {
    final updated = await TechnicianHandoverDetailScreen.open(
      context,
      api: widget.api,
      paymentApi: widget.paymentApi,
      handoverNoteId: stop.handoverNoteId,
      isLeader: trip.isLeader,
    );
    if (updated == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _openVnpayQr(
    TechnicianHandoverStopDetail stop,
    TechnicianFirstPaymentInfo pay,
  ) async {
    final paid = await VnpayQrSheet.open(
      context,
      api: widget.paymentApi,
      contractId: stop.rentalContractId,
      title: '${stop.contractCode} • ${pay.description}',
      targetType: PaymentTargetType.rentalInstallment,
      rentalChargeId: pay.firstInstallmentChargeId,
    );
    if (paid && mounted) {
      _changed = true;
      _msg('Đã nhận thanh toán VNPAY thành công!');
      await _load();
    }
  }

  Future<void> _openCashPayment(
    TechnicianHandoverStopDetail stop,
    TechnicianFirstPaymentInfo pay,
  ) async {
    final ok = await CashPaymentSheet.open(
      context,
      paymentApi: widget.paymentApi,
      rentalContractId: stop.rentalContractId,
      title: '${stop.contractCode} • ${pay.description}',
      suggestedAmount: pay.remainingAmount,
      targetType: PaymentTargetType.rentalInstallment,
      rentalChargeId: pay.firstInstallmentChargeId,
    );
    if (ok && mounted) {
      _changed = true;
      await _load();
    }
  }

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Chi tiết chuyến giao',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
            ? AppEmptyView(
                icon: Icons.cloud_off_rounded,
                title: 'Không tải được dữ liệu',
                message: _error,
                action: FilledButton(
                  onPressed: _load,
                  child: const Text('Thử lại'),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    _buildHeaderCard(d),
                    const SizedBox(height: 12),
                    _buildRoleNotice(d),
                    const SizedBox(height: 12),
                    _buildMembersCard(d),
                    const SizedBox(height: 14),
                    if (d.isRetrieval) ...[
                      Text(
                        'Các điểm thu hồi thiết bị (${d.retrievalStops.length} điểm)',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (d.retrievalStops.isEmpty)
                        _card(
                          child: const Text(
                            'Chuyến thu hồi này hiện chưa có điểm dừng nào.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        for (final rStop in d.retrievalStops) ...[
                          _buildRetrievalStopCard(d, rStop),
                          const SizedBox(height: 12),
                        ],
                      if (d.assignmentMedia.isNotEmpty) ...[
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ảnh / Video minh chứng thu hồi (${d.assignmentMedia.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              MediaViewerGallery(
                                thumbSize: 76,
                                items: [
                                  for (final m in d.assignmentMedia)
                                    GalleryMediaItem(
                                      url: m.url,
                                      isVideo: m.isVideo,
                                      fileName: m.fileName,
                                      sizeBytes: m.sizeBytes,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ] else ...[
                      Text(
                        'Các chặng giao hàng (${d.stops.length} điểm)',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (d.stops.isEmpty)
                        _card(
                          child: const Text(
                            'Chuyến này hiện không còn điểm bàn giao nào.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        for (final stop in d.stops) ...[
                          _buildStopCard(d, stop),
                          const SizedBox(height: 12),
                        ],
                    ],
                    if (d.depot != null) _buildReturnDepotCard(d.depot!),
                  ],
                ),
              ),
        bottomNavigationBar: d != null && d.isLeader && d.isPending
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _acting ? null : _startTrip,
                    icon: _acting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Bắt đầu xuất phát (KTV trưởng)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeaderCard(TechnicianAssignmentDetail d) {
    final (stLabel, stFg, stBg) = _assignmentStatusStyle(d.status);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pill(stLabel, stFg, stBg),
            ],
          ),
          if (d.description != null && d.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Divider(height: 20),
          if (d.scheduledStartAt != null)
            _infoRow(
              Icons.schedule_rounded,
              'Dự kiến xuất phát: ${DateFormatter.dateTime(d.scheduledStartAt!)}'
              '${d.estimatedDurationMinutes != null ? ' (~${d.estimatedDurationMinutes} phút)' : ''}',
            ),
          if (d.startedAt != null)
            _infoRow(
              Icons.play_circle_outline_rounded,
              'Đã xuất phát: ${DateFormatter.dateTime(d.startedAt!)}',
            ),
          if (d.completedAt != null)
            _infoRow(
              Icons.task_alt_rounded,
              'Hoàn tất chuyến: ${DateFormatter.dateTime(d.completedAt!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildRoleNotice(TechnicianAssignmentDetail d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: d.isLeader ? AppColors.primaryLight : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d.isLeader
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            d.isLeader ? Icons.star_rounded : Icons.visibility_outlined,
            size: 20,
            color: d.isLeader ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d.isLeader
                  ? 'Bạn là KTV trưởng của chuyến này — có quyền Bắt đầu đi, Xác nhận bàn giao, Báo thất bại và Thu tiền.'
                  : 'Bạn là Thành viên đi cùng — bạn có thể xem chi tiết thiết bị, biên bản và mở Google Maps chỉ đường từng chặng.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: d.isLeader
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCard(TechnicianAssignmentDetail d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đội kỹ thuật (${d.members.length} người)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final m in d.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    m.isLeader ? Icons.star_rounded : Icons.person_outline,
                    size: 18,
                    color: m.isLeader
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${m.fullName} (${m.employeeCode})${m.isLeader ? ' • KTV trưởng' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: m.isLeader
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (m.phone != null && m.phone!.trim().isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Gọi ${m.fullName}',
                      icon: const Icon(
                        Icons.call_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: () => MapsLauncher.callPhone(context, m.phone),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStopCard(
    TechnicianAssignmentDetail trip,
    TechnicianHandoverStopDetail stop,
  ) {
    final (stLabel, stFg, stBg) = _handoverStatusStyle(stop.status);
    final res = stop.deliveryResult;

    final previewGallery = stop.evidenceMedia.isNotEmpty
        ? [
            for (final m in stop.evidenceMedia)
              GalleryMediaItem(
                url: m.url,
                isVideo: m.isVideo,
                fileName: m.fileName,
                sizeBytes: m.sizeBytes,
              ),
          ]
        : [for (final u in stop.evidenceUrls) GalleryMediaItem(url: u)];

    return _card(
      borderColor: stop.isShipping && trip.isInProgress
          ? AppColors.primary.withValues(alpha: 0.45)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Chặng #${stop.stopOrder}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stop.handoverCode} • ${stop.contractCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _pill(stLabel, stFg, stBg),
            ],
          ),
          if (stop.isSupplementary) ...[
            const SizedBox(height: 6),
            _pill(
              'Phiếu giao bù máy lỗi (miễn phí ship)',
              AppColors.warning,
              AppColors.warningLight,
            ),
          ],
          if (stop.isIncidentReplacement) ...[
            const SizedBox(height: 6),
            _pill(
              'Phiếu giao máy thay thế sự cố (xong sẽ tự đóng sự cố)',
              AppColors.info,
              AppColors.infoLight,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            stop.companyName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stop.deliveryAddress?.trim().isNotEmpty == true
                      ? stop.deliveryAddress!
                      : 'Chưa có địa chỉ giao hàng',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _infoRow(
            Icons.timer_outlined,
            'Di chuyển ~${stop.estimatedTravelMinutes}p • Lắp đặt ~${stop.estimatedInstallMinutes}p',
          ),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  Icons.person_outline_rounded,
                  'Người nhận: ${stop.receivedByName}'
                  '${stop.receivedByPhone != null ? ' (${stop.receivedByPhone})' : ''}',
                ),
              ),
              if (stop.receivedByPhone != null &&
                  stop.receivedByPhone!.trim().isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Gọi người nhận',
                  icon: const Icon(
                    Icons.call_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  onPressed: () =>
                      MapsLauncher.callPhone(context, stop.receivedByPhone),
                ),
            ],
          ),
          if (stop.deliveryNote != null &&
              stop.deliveryNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú giao: ${stop.deliveryNote!}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text('Mở Google Maps chỉ đường Chặng #${stop.stopOrder}'),
              onPressed: () => MapsLauncher.openDirections(
                context,
                latitude: stop.deliveryLatitude,
                longitude: stop.deliveryLongitude,
                address: stop.deliveryAddress,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tóm tắt thiết bị gọn gàng theo Model (thu gọn mặc định, không trải dài serial)
          Text(
            'Thiết bị cần giao (${stop.totalEquipmentCount} máy)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          for (final g in stop.equipmentGroups)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ExpansionTile(
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                  title: Text(
                    '${g.modelName} (${g.quantity} máy)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Mã: ${g.modelCode} • Chạm để xem serial',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final it in g.items)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                it.serialNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Khối thanh toán đợt 1 (ngắn hạn 100% + ship; dài hạn tháng đầu + ship)
          if (stop.firstPayment != null) ...[
            const SizedBox(height: 8),
            _buildFirstPaymentBox(trip, stop, stop.firstPayment!),
          ],
          // Tóm tắt kết quả sau khi đã bàn giao + Nút XEM CHI TIẾT ĐẦY ĐỦ
          if (stop.isCompleted) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (res?.defectiveCount ?? 0) > 0
                    ? AppColors.warningLight
                    : AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res != null && res.defectiveCount > 0
                        ? 'Đã bàn giao ${res.deliveredGoodCount} máy đạt • ${res.defectiveCount} máy lỗi thu hồi (${res.autoReturnCode ?? ''})'
                        : 'Đã bàn giao đạt đủ ${res?.deliveredGoodCount ?? stop.totalEquipmentCount} máy',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: (res?.defectiveCount ?? 0) > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openHandoverFullDetail(trip, stop),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text(
                        'Xem chi tiết biên bản, máy lỗi & ảnh/video',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (previewGallery.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Minh chứng hiện trường (${previewGallery.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            MediaViewerGallery(items: previewGallery, thumbSize: 72),
          ],
          // Nút thao tác của KTV trưởng khi chuyến đang IN_PROGRESS & phiếu đang SHIPPING
          if (trip.isLeader && trip.isInProgress && stop.isShipping) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => _openFailStop(stop),
                    icon: const Icon(Icons.report_problem_outlined, size: 18),
                    label: const Text('Giao thất bại'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    onPressed: () => _openCompleteStop(stop),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Hoàn tất bàn giao'),
                  ),
                ),
              ],
            ),
          ] else if (trip.isLeader && trip.isPending && !stop.isShipping) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Phiếu này chưa được Kho soạn xong & Manager duyệt xuất kho (SHIPPING).',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFirstPaymentBox(
    TechnicianAssignmentDetail trip,
    TechnicianHandoverStopDetail stop,
    TechnicianFirstPaymentInfo pay,
  ) {
    final badge = pay.isPaid
        ? _pill('Đã thanh toán', AppColors.success, AppColors.successLight)
        : pay.hasPendingCash
        ? _pill('Chờ duyệt tiền mặt', AppColors.warning, AppColors.warningLight)
        : _pill('Chưa thanh toán', AppColors.error, AppColors.errorLight);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pay.isLongTerm
                      ? 'Thanh toán tháng đầu (+ ship nếu có)'
                      : 'Thanh toán 100% đơn ngắn hạn (+ ship)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pay.description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Số tiền đợt 1: ${CurrencyFormatter.vnd(pay.amount)}'
            '${pay.remainingAmount > 0 ? ' • Còn lại: ${CurrencyFormatter.vnd(pay.remainingAmount)}' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          if (!pay.isPaid) ...[
            const SizedBox(height: 4),
            Text(
              stop.isSupplementary
                  ? 'Hợp đồng giao bù: có thể thu đợt 1 ngay tại chỗ nếu khách chưa thanh toán.'
                  : 'Linh hoạt cho doanh nghiệp: có thể hiện mã QR VNPay / thu tiền mặt ngay hoặc vẫn hoàn tất giao nếu kế toán khách chuyển sau.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (trip.isLeader && !pay.isPaid && !pay.hasPendingCash) ...[
            const SizedBox(height: 10),
            if ((trip.isInProgress && stop.isShipping) || stop.isCompleted)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => _openVnpayQr(stop, pay),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Hiện QR VNPay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openCashPayment(stop, pay),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Thu tiền mặt'),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Chỉ mở tạo mã QR / thu tiền sau khi phiếu bàn giao được Quản lý duyệt xuất kho và bạn đã bấm "Bắt đầu xuất phát".',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnDepotCard(TechnicianDepot depot) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warehouse_rounded,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chặng về: ${depot.warehouseName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (depot.address != null && depot.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              depot.address!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.home_work_outlined, size: 18),
              label: const Text('Mở Google Maps chỉ đường về Kho'),
              onPressed: () => MapsLauncher.openDirections(
                context,
                latitude: depot.latitude,
                longitude: depot.longitude,
                address: depot.address,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card({required Widget child, Color? borderColor}) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? AppColors.border),
    ),
    child: child,
  );

  Widget _pill(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  (String, Color, Color) _assignmentStatusStyle(String status) =>
      switch (status.toUpperCase()) {
        'IN_PROGRESS' => ('Đang đi giao', AppColors.info, AppColors.infoLight),
        'COMPLETED' => ('Hoàn tất', AppColors.success, AppColors.successLight),
        'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
        _ => ('Chờ xuất phát', AppColors.warning, AppColors.warningLight),
      };

  (String, Color, Color) _handoverStatusStyle(String status) => switch (status
      .toUpperCase()) {
    'SHIPPING' => ('Sẵn sàng / Đang giao', AppColors.info, AppColors.infoLight),
    'COMPLETED' => ('Đã giao', AppColors.success, AppColors.successLight),
    'PENDING_APPROVAL' => (
      'Chờ duyệt kho',
      AppColors.warning,
      AppColors.warningLight,
    ),
    'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
    _ => ('Kho đang soạn', AppColors.textSecondary, AppColors.surfaceSecondary),
  };

  Future<void> _openCompleteRetrieval(
    TechnicianRetrievalStopDetail stop,
  ) async {
    final res = await TechnicianCompleteRetrievalScreen.open(
      context,
      api: widget.api,
      stop: stop,
    );
    if (res != null && mounted) {
      _changed = true;
      _msg(res.message);
      await _load();
    }
  }

  Widget _buildRetrievalStopCard(
    TechnicianAssignmentDetail trip,
    TechnicianRetrievalStopDetail stop,
  ) {
    final (stLabel, stFg, stBg) = switch (stop.status.toUpperCase()) {
      'COMPLETED' => (
        'Kho đã kiểm nhận',
        AppColors.success,
        AppColors.successLight,
      ),
      'PROCESSING' => (
        'Đã thu — Chờ về kho',
        AppColors.info,
        AppColors.infoLight,
      ),
      _ => ('Chờ thu hồi', AppColors.warning, AppColors.warningLight),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.warning,
                child: Text(
                  '${stop.stopOrder}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.returnCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      '${stop.contractCode} • Hết hạn: ${DateFormatter.date(stop.contractEndDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(stLabel, stFg, stBg),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stop.companyName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stop.pickupAddress?.trim().isNotEmpty == true
                      ? stop.pickupAddress!
                      : 'Chưa có địa chỉ thu hồi',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _infoRow(
            Icons.timer_outlined,
            'Di chuyển ~${stop.estimatedTravelMinutes}p • Tháo dỡ ~${stop.estimatedUninstallMinutes}p',
          ),
          if (stop.contactName != null || stop.contactPhone != null)
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.person_outline_rounded,
                    'Liên hệ: ${stop.contactName ?? '---'}'
                    '${stop.contactPhone != null ? ' (${stop.contactPhone})' : ''}',
                  ),
                ),
                if (stop.contactPhone != null &&
                    stop.contactPhone!.trim().isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Gọi khách hàng',
                    icon: const Icon(
                      Icons.call_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    onPressed: () =>
                        MapsLauncher.callPhone(context, stop.contactPhone),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => MapsLauncher.openDirections(
                context,
                latitude: stop.pickupLatitude,
                longitude: stop.pickupLongitude,
                address: stop.pickupAddress,
              ),
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text('Mở Google Maps chỉ đường thu hồi'),
            ),
          ),
          const Divider(height: 20),
          Text(
            'Thiết bị cần thu hồi (${stop.items.length} máy):',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final item in stop.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    item.itemStatus == 'MISSING'
                        ? Icons.warning_amber_rounded
                        : Icons.qr_code_2_rounded,
                    size: 16,
                    color: item.itemStatus == 'MISSING'
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.serialNumber} • ${item.modelName} (${item.condition})',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (stop.isProcessing || stop.isCompleted)
                    _pill(
                      item.itemStatus == 'MISSING' ? 'Thiếu' : 'Đã thu',
                      item.itemStatus == 'MISSING'
                          ? AppColors.error
                          : AppColors.success,
                      item.itemStatus == 'MISSING'
                          ? AppColors.errorLight
                          : AppColors.successLight,
                    ),
                ],
              ),
            ),
          if (trip.isLeader && trip.isInProgress && stop.isDraft) ...[
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => _openCompleteRetrieval(stop),
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                label: const Text(
                  'Kiểm đếm & Xác nhận thu hồi tại điểm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
