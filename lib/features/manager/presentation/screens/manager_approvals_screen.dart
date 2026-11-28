import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

class ManagerApprovalsScreen extends StatefulWidget {
  const ManagerApprovalsScreen({
    super.key,
    required this.managerApi,
    required this.contractApi,
  });

  final ManagerApi managerApi;
  final RentalContractApi contractApi;

  static Future<void> open(
    BuildContext context,
    ManagerApi managerApi,
    RentalContractApi contractApi,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManagerApprovalsScreen(
          managerApi: managerApi,
          contractApi: contractApi,
        ),
      ),
    );
  }

  @override
  State<ManagerApprovalsScreen> createState() => _ManagerApprovalsScreenState();
}

class _ManagerApprovalsScreenState extends State<ManagerApprovalsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _cashPayments = const [];
  List<Map<String, dynamic>> _incidentCharges = const [];
  List<Map<String, dynamic>> _replacements = const [];
  List<Map<String, dynamic>> _handovers = const [];
  List<RentalContract> _cancelRequests = const [];
  List<Map<String, dynamic>> _disposals = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.managerApi.getPendingCashPayments(),
        widget.managerApi.getPendingIncidentCharges(),
        widget.managerApi.getPendingReplacements(),
        widget.managerApi.getPendingHandovers(),
        widget.contractApi.getContracts(),
        widget.managerApi.getPendingDisposals(),
      ]);
      if (!mounted) return;
      setState(() {
        _cashPayments = results[0] as List<Map<String, dynamic>>;
        _incidentCharges = results[1] as List<Map<String, dynamic>>;
        _replacements = results[2] as List<Map<String, dynamic>>;
        _handovers = results[3] as List<Map<String, dynamic>>;
        _cancelRequests = (results[4] as List<RentalContract>)
            .where((c) => c.status == RentalContractStatus.cancellationRequested)
            .toList();
        _disposals = results[5] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _decide(Future<void> Function() action, String okMsg) async {
    try {
      await action();
      if (mounted) _msg(okMsg);
      await _loadAll();
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Duyệt yêu cầu & Tài chính',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Hóa đơn thu (${_cashPayments.length})'),
              Tab(text: 'Phạt sự cố (${_incidentCharges.length})'),
              Tab(text: 'Đổi model (${_replacements.length})'),
              Tab(text: 'Phiếu bàn giao (${_handovers.length})'),
              Tab(text: 'Hủy HĐ (${_cancelRequests.length})'),
              Tab(text: 'Thanh lý (${_disposals.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCashPaymentsTab(),
                  _buildIncidentChargesTab(),
                  _buildReplacementsTab(),
                  _buildHandoversTab(),
                  _buildCancelsTab(),
                  _buildDisposalsTab(),
                ],
              ),
      ),
    );
  }

  Future<String?> _askReason(String title) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập lý do từ chối...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Widget _buildCashPaymentsTab() {
    if (_cashPayments.isEmpty) {
      return const AppEmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'Không có hóa đơn thu tiền mặt chờ duyệt',
        message:
            'Hóa đơn thu cọc / thanh toán trực tiếp từ Sales hoặc KTV sẽ hiển thị tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _cashPayments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = _cashPayments[i];
          final id = t['id'] as String;
          final txnRef = t['txnRef'] as String? ?? '';
          final contractCode = t['contractCode'] as String? ?? '';
          final targetType = (t['targetType'] as String? ?? '').toUpperCase();
          final targetLabel = switch (targetType) {
            'DEPOSIT' => 'Tiền đặt cọc',
            'RENTAL_INSTALLMENT' => 'Tiền thuê theo đợt',
            'INCIDENT_CHARGE' => 'Phí sự cố',
            _ => 'Khoản thu khác',
          };
          final amount = (t['amount'] as num?)?.toDouble() ?? 0;
          final createdByName = t['createdByName'] as String? ?? 'Nhân viên';
          final receiptUrl = t['receiptUrl'] as String?;
          final note = t['note'] as String?;
          final createdAt = t['createdAt'] != null
              ? DateTime.parse(t['createdAt'] as String).toLocal()
              : null;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$contractCode • $targetLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Chờ duyệt',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.vnd(amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã hóa đơn: $txnRef',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Nhân viên xác nhận thu: $createdByName'
                  '${createdAt != null ? ' • ${DateFormatter.dateTime(createdAt)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (note != null && note.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ghi chú: $note',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  MediaViewerGallery(
                    thumbSize: 72,
                    items: [
                      GalleryMediaItem(
                        url: receiptUrl,
                        fileName: 'Biên lai $txnRef',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: () async {
                          final reason = await _askReason(
                            'Từ chối hóa đơn $txnRef',
                          );
                          if (reason != null) {
                            await _decide(
                              () => widget.managerApi.rejectCashPayment(
                                id,
                                reason,
                              ),
                              'Đã từ chối hóa đơn thu $txnRef.',
                            );
                          }
                        },
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        onPressed: () => _decide(
                          () => widget.managerApi.verifyCashPayment(id),
                          'Đã duyệt hóa đơn $txnRef & ghi nhận thanh toán!',
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Duyệt hóa đơn'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openIncidentChargeDecisionSheet(
    Map<String, dynamic> item,
  ) async {
    final chargeId = item['chargeId'] as String;
    final proposedAmount = (item['proposedAmount'] as num?)?.toDouble() ?? 0;
    final availableDeposit =
        (item['availableDeposit'] as num?)?.toDouble() ?? 0;
    final incidentCode = item['incidentCode'] as String? ?? '';
    final serialNumber = item['serialNumber'] as String? ?? '';

    final amountCtrl = TextEditingController(
      text: proposedAmount.round().toString(),
    );
    final noteCtrl = TextEditingController();
    var selectedDecision = 'APPROVE_OFFSET_DEPOSIT';

    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsedAmt =
              double.tryParse(
                amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              0;
          final offset = selectedDecision == 'APPROVE_OFFSET_DEPOSIT'
              ? (parsedAmt < availableDeposit ? parsedAmt : availableDeposit)
              : 0.0;
          final remaining = selectedDecision == 'WAIVE'
              ? 0.0
              : (parsedAmt - offset).clamp(0.0, double.infinity);
          final unlocksNow =
              selectedDecision == 'WAIVE' ||
              (selectedDecision == 'APPROVE_OFFSET_DEPOSIT' && remaining <= 0);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.viewInsetsOf(ctx).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Duyệt phạt sự cố $incidentCode',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Thiết bị: $serialNumber • Cọc khả dụng: ${CurrencyFormatter.vnd(availableDeposit)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'APPROVE_OFFSET_DEPOSIT',
                        label: Text('Cấn trừ cọc'),
                      ),
                      ButtonSegment(
                        value: 'APPROVE_DIRECT_BILLING',
                        label: Text('Thu riêng'),
                      ),
                      ButtonSegment(
                        value: 'WAIVE',
                        label: Text('Miễn phạt'),
                      ),
                    ],
                    selected: {selectedDecision},
                    onSelectionChanged: (s) =>
                        setModalState(() => selectedDecision = s.first),
                  ),
                  if (selectedDecision != 'WAIVE') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Số tiền phạt / bồi thường cuối cùng (VNĐ) *',
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú của Quản lý (tùy chọn)',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: unlocksNow
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedDecision == 'WAIVE')
                          const Text(
                            'Miễn phạt (0 đ) → Mở khóa ngay cho Kho soạn máy thay thế.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          )
                        else ...[
                          Text(
                            '• Cấn trừ tiền đặt cọc: ${CurrencyFormatter.vnd(offset)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '• Khách cần đóng thêm: ${CurrencyFormatter.vnd(remaining)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: remaining > 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unlocksNow
                                ? 'Cọc đủ bù 100% → Mở khóa giao máy thay thế ngay.'
                                : 'Trừ cọc không đủ / thu riêng → Tạm khóa giao máy thay thế cho tới khi khách thanh toán đủ ${CurrencyFormatter.vnd(remaining)}.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: unlocksNow
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: selectedDecision == 'WAIVE'
                          ? AppColors.info
                          : AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () {
                      if (selectedDecision != 'WAIVE' && parsedAmt <= 0) return;
                      Navigator.pop(ctx, {
                        'decision': selectedDecision,
                        'adjustedAmount':
                            selectedDecision == 'WAIVE' ? null : parsedAmt,
                        'managerNote': noteCtrl.text.trim(),
                      });
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      selectedDecision == 'WAIVE'
                          ? 'Xác nhận miễn phạt'
                          : selectedDecision == 'APPROVE_OFFSET_DEPOSIT'
                          ? 'Duyệt & Cấn trừ tiền cọc'
                          : 'Duyệt & Thu riêng khách hàng',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    amountCtrl.dispose();
    noteCtrl.dispose();

    if (res == null || !mounted) return;

    try {
      final out = await widget.managerApi.decideIncidentCharge(
        chargeId,
        decision: res['decision'] as String,
        adjustedAmount: res['adjustedAmount'] as double?,
        managerNote: res['managerNote'] as String?,
      );
      if (mounted) {
        _msg(out['message'] as String? ?? 'Đã xét duyệt khoản phạt sự cố.');
      }
      await _loadAll();
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    }
  }

  Widget _buildIncidentChargesTab() {
    if (_incidentCharges.isEmpty) {
      return const AppEmptyView(
        icon: Icons.gavel_outlined,
        title: 'Không có đề xuất phạt sự cố chờ duyệt',
        message:
            'Khi KTV kiểm tra thiết bị sự cố và xác định lỗi do khách hàng, đề xuất chi phí sửa chữa / bồi thường sẽ hiển thị tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _incidentCharges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = _incidentCharges[i];
          final incidentCode = item['incidentCode'] as String? ?? '';
          final contractCode = item['contractCode'] as String? ?? '';
          final companyName = item['companyName'] as String? ?? '';
          final serial = item['serialNumber'] as String? ?? '';
          final modelName = item['modelName'] as String? ?? '';
          final chargeType = (item['chargeType'] as String? ?? 'REPAIR')
              .toUpperCase();
          final typeLabel = switch (chargeType) {
            'REPLACEMENT' => 'Bồi thường thiết bị',
            'OTHER' => 'Chi phí khác',
            _ => 'Phí sửa chữa',
          };
          final proposed = (item['proposedAmount'] as num?)?.toDouble() ?? 0;
          final availDeposit =
              (item['availableDeposit'] as num?)?.toDouble() ?? 0;
          final proposer = item['proposedByName'] as String? ?? 'KTV';
          final desc = item['description'] as String?;
          final assessment = item['incidentAssessment'] as String?;
          final urls = (item['evidenceUrls'] as List<dynamic>? ?? const [])
              .cast<String>();

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$incidentCode • $contractCode',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$companyName • Máy: $serial ($modelName)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đề xuất: ${CurrencyFormatter.vnd(proposed)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    Text(
                      'Cọc còn: ${CurrencyFormatter.vnd(availDeposit)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: availDeposit >= proposed
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'KTV đề xuất: $proposer',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (assessment != null && assessment.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Đánh giá KTV: $assessment',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
                if (desc != null && desc.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nội dung: $desc',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (urls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  MediaViewerGallery(
                    thumbSize: 68,
                    items: [
                      for (var idx = 0; idx < urls.length; idx++)
                        GalleryMediaItem(
                          url: urls[idx],
                          fileName: 'Minh chứng $incidentCode #${idx + 1}',
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () => _openIncidentChargeDecisionSheet(item),
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Xét duyệt / Cấn trừ cọc'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplacementsTab() {
    if (_replacements.isEmpty) {
      return const AppEmptyView(
        icon: Icons.swap_horiz_rounded,
        title: 'Không có yêu cầu đổi thiết bị',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _replacements.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = _replacements[i];
          final items = (r['items'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
          return _approvalCard(
            title: '${r['requestCode']} • ${r['contractCode']}',
            subtitle: '${r['companyName']} • Đề xuất: ${r['requestedByName']}',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lý do: ${r['reason']}'),
                const SizedBox(height: 6),
                for (final it in items)
                  Text(
                    '• ${it['oldSerialNumber']} (${it['oldModelName']}) → ${it['replacementModelName'] ?? 'Cùng model'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            onReject: () => _decide(
              () => widget.managerApi.decideReplacement(
                r['id'] as String,
                approve: false,
              ),
              'Đã từ chối yêu cầu đổi model.',
            ),
            onApprove: () => _decide(
              () => widget.managerApi.decideReplacement(
                r['id'] as String,
                approve: true,
              ),
              'Đã duyệt yêu cầu đổi thiết bị.',
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandoversTab() {
    if (_handovers.isEmpty) {
      return const AppEmptyView(
        icon: Icons.inventory_outlined,
        title: 'Không có phiếu bàn giao chờ duyệt',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _handovers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final h = _handovers[i];
          return _HandoverApprovalCard(
            data: h,
            onReject: () => _decide(
              () => widget.managerApi.decideHandover(
                h['id'] as String,
                approve: false,
                reason: 'Yêu cầu kiểm tra và soạn lại đúng danh mục',
              ),
              'Đã trả phiếu bàn giao về cho Kho soạn lại.',
            ),
            onApprove: () => _decide(
              () => widget.managerApi.decideHandover(
                h['id'] as String,
                approve: true,
              ),
              'Đã duyệt phiếu bàn giao (cho phép xuất kho).',
            ),
          );
        },
      ),
    );
  }

  Widget _buildCancelsTab() {
    if (_cancelRequests.isEmpty) {
      return const AppEmptyView(
        icon: Icons.cancel_outlined,
        title: 'Không có yêu cầu hủy hợp đồng',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _cancelRequests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = _cancelRequests[i];
          return _approvalCard(
            title: '${c.contractCode} • ${c.companyName ?? ''}',
            subtitle:
                'Sales: ${c.createdByName ?? '---'} • ${CurrencyFormatter.vnd(c.contractTotalAmount)}',
            body: const Text(
              'Hợp đồng đang ở trạng thái Chờ duyệt hủy (từ bước Chuẩn bị trở đi).',
            ),
            onReject: () => _decide(
              () =>
                  widget.managerApi.decideCancelContract(c.id, approve: false),
              'Đã từ chối hủy và khôi phục hợp đồng.',
            ),
            onApprove: () => _decide(
              () => widget.managerApi.decideCancelContract(c.id, approve: true),
              'Đã duyệt hủy hợp đồng.',
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisposalsTab() {
    if (_disposals.isEmpty) {
      return const AppEmptyView(
        icon: Icons.delete_sweep_outlined,
        title: 'Không có đề xuất thanh lý',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _disposals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = _disposals[i];
          return _approvalCard(
            title: '${d['serialNumber']} • ${d['modelName']}',
            subtitle:
                'Hình thức: ${d['method']} • Giá trị: ${CurrencyFormatter.vnd((d['amount'] as num?) ?? 0)}',
            body: Text(
              'Lý do: ${d['reason']}\nNgười đề xuất: ${d['requestedByName'] ?? '---'}',
            ),
            onReject: () => _decide(
              () => widget.managerApi.decideDisposal(
                d['id'] as String,
                approve: false,
              ),
              'Đã từ chối đề xuất thanh lý.',
            ),
            onApprove: () => _decide(
              () => widget.managerApi.decideDisposal(
                d['id'] as String,
                approve: true,
              ),
              'Đã duyệt thanh lý (thiết bị chuyển DISPOSED).',
            ),
          );
        },
      ),
    );
  }

  Widget _approvalCard({
    required String title,
    required String subtitle,
    required Widget body,
    required VoidCallback onReject,
    required VoidCallback onApprove,
    Color? borderColor,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 16),
            body,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: onReject,
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: onApprove,
                    child: const Text('Phê duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _HandoverApprovalCard extends StatefulWidget {
  const _HandoverApprovalCard({
    required this.data,
    required this.onReject,
    required this.onApprove,
  });

  final Map<String, dynamic> data;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  State<_HandoverApprovalCard> createState() => _HandoverApprovalCardState();
}

class _HandoverApprovalCardState extends State<_HandoverApprovalCard> {
  bool _showSerials = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.data;
    final mismatch = h['hasModelMismatch'] == true;
    final requiredModels =
        (h['requiredContractModels'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>();
    final groups = (h['modelGroups'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final totalPrepared = (h['totalPreparedCount'] as num?)?.toInt() ?? 0;
    final totalRequired = (h['totalRequiredCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mismatch ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${h['handoverCode']} • ${h['contractCode']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Đã soạn $totalPrepared/$totalRequired máy',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${h['companyName']} • Ngày giao: ${h['handoverDate']}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 16),
          if (mismatch)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phiếu có thiết bị đề xuất thay thế model tương đương/cao hơn (giữ nguyên đơn giá gốc).',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Yêu cầu hợp đồng: ${requiredModels.join(' • ')}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final g in groups) ...[
            Builder(
              builder: (_) {
                final isSub = g['isSubstitutedModel'] == true;
                final serials =
                    (g['serialNumbers'] as List<dynamic>? ?? const <dynamic>[])
                        .cast<String>();
                final reqQty = (g['requiredQuantity'] as num?)?.toInt();
                final prepQty = (g['preparedCount'] as num?)?.toInt() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSub
                        ? AppColors.warningLight.withValues(alpha: 0.45)
                        : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${g['modelName']} (${g['modelCode']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            reqQty != null
                                ? '$prepQty/$reqQty máy'
                                : '$prepQty máy',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: isSub
                                  ? AppColors.warning
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (g['substitutedForLabel'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '↳ Thay thế cho: ${g['substitutedForLabel']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      if (_showSerials && serials.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final sn in serials)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  sn,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showSerials = !_showSerials),
              icon: Icon(
                _showSerials
                    ? Icons.expand_less_rounded
                    : Icons.qr_code_2_rounded,
                size: 18,
              ),
              label: Text(
                _showSerials
                    ? 'Ẩn danh sách mã vật lý'
                    : 'Xem $totalPrepared mã vật lý (Serial)',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: widget.onReject,
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: widget.onApprove,
                  child: const Text('Phê duyệt'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
