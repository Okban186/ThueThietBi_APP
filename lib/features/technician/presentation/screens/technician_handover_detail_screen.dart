import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/payment_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/contract_billing.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/vnpay_qr_sheet.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/utils/maps_launcher.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import '../widgets/cash_payment_sheet.dart';

/// Màn hình xem chi tiết đầy đủ một phiếu bàn giao (đặc biệt sau khi giao xong):
/// - Ảnh & Video hiện trường (phóng to / mở phát video).
/// - Chi tiết máy đạt (gom nhóm theo Model) & từng máy lỗi (serial, loại lỗi, mô tả hư chỗ nào, ảnh riêng).
/// - Ảnh / Video chung đợt lỗi & trạng thái phiếu thu hồi tự động (TH-...).
/// - Khối Thanh toán đợt 1 (hiện QR VNPay / Thu tiền mặt cho KTV trưởng nếu chưa thanh toán).
class TechnicianHandoverDetailScreen extends StatefulWidget {
  const TechnicianHandoverDetailScreen({
    super.key,
    required this.api,
    required this.paymentApi,
    required this.handoverNoteId,
    required this.isLeader,
  });

  final TechnicianApi api;
  final PaymentApi paymentApi;
  final String handoverNoteId;
  final bool isLeader;

  static Future<bool?> open(
    BuildContext context, {
    required TechnicianApi api,
    required PaymentApi paymentApi,
    required String handoverNoteId,
    required bool isLeader,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TechnicianHandoverDetailScreen(
          api: api,
          paymentApi: paymentApi,
          handoverNoteId: handoverNoteId,
          isLeader: isLeader,
        ),
      ),
    );
  }

  @override
  State<TechnicianHandoverDetailScreen> createState() =>
      _TechnicianHandoverDetailScreenState();
}

class _TechnicianHandoverDetailScreenState
    extends State<TechnicianHandoverDetailScreen> {
  TechnicianHandoverStopDetail? _stop;
  bool _loading = true;
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
      final data = await widget.api.getHandoverDetail(widget.handoverNoteId);
      if (mounted) setState(() => _stop = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được chi tiết biên bản bàn giao.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final s = _stop;
    final res = s?.deliveryResult;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            s != null ? 'Biên bản ${s.handoverCode}' : 'Chi tiết bàn giao',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading && s == null
            ? const Center(child: CircularProgressIndicator())
            : s == null
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    _buildSummaryCard(s, res),
                    if (s.firstPayment != null) ...[
                      const SizedBox(height: 12),
                      _buildPaymentCard(s, s.firstPayment!),
                    ],
                    const SizedBox(height: 12),
                    _buildSceneMediaCard(s, res),
                    if (res != null && res.defectiveCount > 0) ...[
                      const SizedBox(height: 12),
                      _buildDefectiveDetailCard(res),
                    ],
                    const SizedBox(height: 12),
                    _buildDeliveredGoodCard(s, res),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
    TechnicianHandoverStopDetail s,
    TechnicianHandoverResultDetail? res,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.handoverCode} • ${s.contractCode}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill(
                s.isCompleted ? 'Đã giao' : s.status,
                s.isCompleted ? AppColors.success : AppColors.info,
                s.isCompleted ? AppColors.successLight : AppColors.infoLight,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.companyName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (s.deliveryAddress != null &&
              s.deliveryAddress!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.deliveryAddress!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Người nhận: ${s.receivedByName}'
                  '${s.receivedByPhone != null ? ' • ${s.receivedByPhone}' : ''}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              if (s.receivedByPhone != null &&
                  s.receivedByPhone!.trim().isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.call_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  onPressed: () =>
                      MapsLauncher.callPhone(context, s.receivedByPhone),
                ),
            ],
          ),
          if (res != null) ...[
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(
                  'Giao đạt: ${res.deliveredGoodCount} máy',
                  AppColors.success,
                  AppColors.successLight,
                ),
                if (res.defectiveCount > 0)
                  _pill(
                    'Máy lỗi thu hồi: ${res.defectiveCount} máy',
                    AppColors.error,
                    AppColors.errorLight,
                  ),
                if (res.autoReturnCode != null)
                  _pill(
                    'Phiếu thu hồi: ${res.autoReturnCode} (${res.autoReturnStatus == 'COMPLETED' ? 'Đã thu hồi xong' : 'Chờ Kho kiểm nhận'})',
                    res.autoReturnStatus == 'COMPLETED'
                        ? AppColors.success
                        : AppColors.warning,
                    res.autoReturnStatus == 'COMPLETED'
                        ? AppColors.successLight
                        : AppColors.warningLight,
                  ),
              ],
            ),
          ],
          if (s.note != null && s.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ghi chú: ${s.note!}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    TechnicianHandoverStopDetail s,
    TechnicianFirstPaymentInfo pay,
  ) {
    final badge = pay.isPaid
        ? _pill('Đã thanh toán', AppColors.success, AppColors.successLight)
        : pay.hasPendingCash
        ? _pill('Chờ duyệt tiền mặt', AppColors.warning, AppColors.warningLight)
        : _pill('Chưa thanh toán', AppColors.error, AppColors.errorLight);

    return _card(
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
                      ? 'Thanh toán tháng đầu (+ ship)'
                      : 'Thanh toán 100% đơn ngắn hạn (+ ship)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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
            'Tổng đợt 1: ${CurrencyFormatter.vnd(pay.amount)}'
            '${pay.remainingAmount > 0 ? ' • Còn lại: ${CurrencyFormatter.vnd(pay.remainingAmount)}' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          if (widget.isLeader &&
              (s.isShipping || s.isCompleted) &&
              !pay.isPaid &&
              !pay.hasPendingCash) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openVnpayQr(s, pay),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Hiện QR VNPay'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openCashPayment(s, pay),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Thu tiền mặt'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSceneMediaCard(
    TechnicianHandoverStopDetail s,
    TechnicianHandoverResultDetail? res,
  ) {
    final media = res != null && res.sceneMedia.isNotEmpty
        ? res.sceneMedia
        : s.evidenceMedia;
    final galleryItems = media.isNotEmpty
        ? [
            for (final m in media)
              GalleryMediaItem(
                url: m.url,
                isVideo: m.isVideo,
                fileName: m.fileName,
                sizeBytes: m.sizeBytes,
              ),
          ]
        : [for (final u in s.evidenceUrls) GalleryMediaItem(url: u)];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ảnh / Video minh chứng hiện trường (${galleryItems.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          if (galleryItems.isEmpty)
            const Text(
              'Chưa có ảnh/video hiện trường nào.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            MediaViewerGallery(items: galleryItems),
        ],
      ),
    );
  }

  Widget _buildDefectiveDetailCard(TechnicianHandoverResultDetail res) {
    final sharedGallery = [
      for (final m in res.sharedIssueMedia)
        GalleryMediaItem(
          url: m.url,
          isVideo: m.isVideo,
          fileName: m.fileName,
          sizeBytes: m.sizeBytes,
        ),
    ];

    return _card(
      borderColor: AppColors.error.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chi tiết thiết bị lỗi lúc giao (${res.defectiveCount} máy)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (res.issueDescription != null &&
              res.issueDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              res.issueDescription!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (sharedGallery.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Ảnh / Video chụp chung đợt lỗi:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            MediaViewerGallery(items: sharedGallery),
          ],
          const SizedBox(height: 10),
          for (final item in res.defectiveItems)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.serialNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _pill(
                        item.issueTypeLabel,
                        AppColors.error,
                        AppColors.errorLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.modelName} (${item.modelCode})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Mô tả hư hỏng: ${item.description!}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (item.itemPhotos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Ảnh riêng của thiết bị này:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MediaViewerGallery(
                      thumbSize: 74,
                      items: [
                        for (final p in item.itemPhotos)
                          GalleryMediaItem(
                            url: p.url,
                            isVideo: p.isVideo,
                            fileName: p.fileName,
                            sizeBytes: p.sizeBytes,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveredGoodCard(
    TechnicianHandoverStopDetail s,
    TechnicianHandoverResultDetail? res,
  ) {
    final goodItems = res?.deliveredGoodItems ??
        s.equipmentGroups.expand((g) => g.items).toList();

    // Gom nhóm theo Model (thu gọn mặc định)
    final byModel = <String, List<TechnicianEquipmentItem>>{};
    for (final it in goodItems) {
      byModel.putIfAbsent(it.equipmentModelId, () => []).add(it);
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thiết bị giao đạt (${goodItems.length} máy)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          if (goodItems.isEmpty)
            const Text(
              'Không có máy giao đạt trong đợt này.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (final entry in byModel.entries)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
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
                      '${entry.value.first.modelName} (${entry.value.length} máy)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Mã: ${entry.value.first.modelCode} • Chạm để xem serial',
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
                            for (final it in entry.value)
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
        ],
      ),
    );
  }

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
}
