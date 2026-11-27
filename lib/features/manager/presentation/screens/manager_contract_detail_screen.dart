import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/contract_billing.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_timeline.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import 'create_delivery_trip_screen.dart';
import 'create_retrieval_trip_screen.dart';

class ManagerContractDetailScreen extends StatefulWidget {
  const ManagerContractDetailScreen({
    super.key,
    required this.contractId,
    required this.contractApi,
    required this.managerApi,
  });

  final String contractId;
  final RentalContractApi contractApi;
  final ManagerApi managerApi;

  static Future<bool?> open(
    BuildContext context, {
    required String contractId,
    required RentalContractApi contractApi,
    required ManagerApi managerApi,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManagerContractDetailScreen(
          contractId: contractId,
          contractApi: contractApi,
          managerApi: managerApi,
        ),
      ),
    );
  }

  @override
  State<ManagerContractDetailScreen> createState() =>
      _ManagerContractDetailScreenState();
}

class _ManagerContractDetailScreenState
    extends State<ManagerContractDetailScreen> {
  RentalContract? _contract;
  ContractBillingSummary? _billing;
  bool _loading = true;
  bool _submitting = false;
  bool _mutated = false;
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
      final data = await widget.contractApi.getDetail(widget.contractId);
      ContractBillingSummary? billing;
      if (data.status != RentalContractStatus.draft &&
          data.status != RentalContractStatus.pendingApproval &&
          data.status != RentalContractStatus.rejected) {
        try {
          billing = await widget.contractApi.getBilling(widget.contractId);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _contract = data;
          _billing = billing;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
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
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _runAction(
    Future<void> Function() fn,
    String successMsg, {
    bool popAfterSuccess = false,
  }) async {
    setState(() => _submitting = true);
    try {
      await fn();
      _mutated = true;
      if (popAfterSuccess) {
        if (mounted) {
          _msg(successMsg);
          Navigator.pop(context, true);
        }
        return;
      }
      await _load();
      if (mounted) _msg(successMsg);
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleApproveCancelWithSettlement(RentalContract c) async {
    final result = await showDialog<({String reason, double penalty, double transport})>(
      context: context,
      builder: (_) => _CancelSettlementDialog(contract: c),
    );
    if (result == null) return;

    await _runAction(
      () => widget.managerApi.decideCancelContract(
        c.id,
        approve: true,
        reason: result.reason,
        penaltyAmount: result.penalty,
        transportFeeAmount: result.transport,
      ),
      'Đã hủy hợp đồng, cập nhật vận hành & gửi quyết toán phí cho khách.',
    );
  }

  Future<String?> _askReason({
    required String title,
    required String hint,
    bool requiredReason = true,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: title,
        hint: hint,
        requiredReason: requiredReason,
      ),
    );
  }

  Future<void> _openPdf({required bool signedPdf}) async {
    final c = _contract;
    if (c == null) return;
    setState(() => _submitting = true);
    try {
      final bytes = signedPdf
          ? await widget.contractApi.downloadFile(c.detail!.signedContractUrl!)
          : await widget.contractApi.exportPdf(c.id);
      final dir = await getTemporaryDirectory();
      final suffix = signedPdf ? 'signed' : 'draft';
      final file = File('${dir.path}/${c.contractCode}_$suffix.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không mở được file PDF.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _contract;
    final detail = c?.detail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _mutated);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _mutated),
          ),
          title: Text(
            c?.contractCode ?? 'Chi tiết hợp đồng',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (c != null && c.status != RentalContractStatus.cancelled)
              IconButton(
                tooltip: 'Xuất PDF mẫu',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed:
                    _submitting ? null : () => _openPdf(signedPdf: false),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || c == null || detail == null
                ? Center(child: Text(_error ?? 'Không tìm thấy hợp đồng'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.companyName ?? '',
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  ContractStatusBadge(status: c.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _kv(
                                'Thời gian thuê',
                                '${DateFormatter.dateRange(c.startDate, c.endDate)} (${c.rentalDays} ngày)',
                              ),
                              _kv('Loại thuê', c.rentalType.label),
                              _kv(
                                'Địa chỉ giao',
                                detail.deliveryAddress ?? 'Chưa cập nhật',
                              ),
                              _kv(
                                'Tổng giá trị',
                                CurrencyFormatter.vnd(c.contractTotalAmount),
                                boldValue: true,
                              ),
                              _kv(
                                'Tiền cọc yêu cầu',
                                CurrencyFormatter.vnd(c.depositRequiredAmount),
                              ),
                              _kv(
                                'Tiền cọc đã duyệt',
                                CurrencyFormatter.vnd(c.depositPaidAmount),
                              ),
                              if (c.status == RentalContractStatus.signed) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c.depositRequiredAmount > 0
                                        ? 'Vui lòng kiểm tra bản PDF đã ký bên dưới rồi bấm "Duyệt bản ký → Mở đặt cọc". Sau khi duyệt bản ký, khách hàng mới được phép đặt cọc (hạn chót trước ${DateFormatter.date(c.depositDeadline)}).'
                                        : 'Vui lòng kiểm tra bản PDF đã ký bên dưới rồi bấm "Duyệt bản ký → Chuẩn bị" để chuyển kho soạn máy.',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                              if (c.status ==
                                      RentalContractStatus.pendingDeposit &&
                                  c.depositRequiredAmount > 0) ...[
                                const SizedBox(height: 10),
                                _buildSignedDepositCard(c),
                              ],
                              if (detail.approvedByName != null)
                                _kv('Quản lý phụ trách', detail.approvedByName!),
                              if (c.rejectionReason != null &&
                                  c.rejectionReason!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Lý do từ chối gần nhất: ${c.rejectionReason}',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (detail.signedContractUrl != null) ...[
                          const SizedBox(height: 12),
                          _card(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.successLight,
                                child: Icon(
                                  Icons.verified_outlined,
                                  color: AppColors.success,
                                ),
                              ),
                              title: const Text(
                                'Bản hợp đồng PDF đã ký',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                detail.signedAt != null
                                    ? 'Nộp lúc ${DateFormatter.dateTime(detail.signedAt!)}'
                                    : 'Chạm để mở kiểm tra PDF',
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: _submitting
                                    ? null
                                    : () => _openPdf(signedPdf: true),
                                child: const Text('Mở PDF'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Danh mục thiết bị thuê',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Divider(height: 18),
                              for (final item in detail.items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.equipmentModelName ??
                                                  item.equipmentModelCode ??
                                                  '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'SL: ${item.quantity} • ${CurrencyFormatter.vnd(item.agreedUnitPrice)}/${item.billingUnit.unitLabel}',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.vnd(item.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (detail.documents.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Giấy tờ pháp lý đính kèm',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 92,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: detail.documents.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, i) {
                                      final doc = detail.documents[i];
                                      if (doc.url == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return GestureDetector(
                                        onTap: () => _showImageViewer(
                                          doc.url!,
                                          doc.kind.label,
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: doc.url!,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lịch sử trạng thái',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ContractStatusTimeline(
                                history: detail.statusHistory,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: c == null ? null : _buildActionBar(c),
      ),
    );
  }

  Widget? _buildActionBar(RentalContract c) {
    if (c.status == RentalContractStatus.completed ||
        c.status == RentalContractStatus.cancelled) {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: _submitting
            ? const SizedBox(
                height: 44,
                child: Center(child: CircularProgressIndicator()),
              )
            : switch (c.status) {
                RentalContractStatus.pendingApproval => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          onPressed: () async {
                            final reason = await _askReason(
                              title: 'Từ chối hợp đồng',
                              hint: 'Nhập lý do yêu cầu Sales chỉnh sửa...',
                            );
                            if (reason != null) {
                              await _runAction(
                                () => widget.managerApi
                                    .rejectContract(c.id, reason),
                                'Đã từ chối và gửi lý do cho Sales.',
                                popAfterSuccess: true,
                              );
                            }
                          },
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: () => _runAction(
                            () => widget.managerApi.approveContract(c.id),
                            'Đã duyệt hợp đồng (chuyển Chờ ký).',
                          ),
                          child: const Text('Duyệt hợp đồng'),
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.signed => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          onPressed: () async {
                            final reason = await _askReason(
                              title: 'Yêu cầu nộp lại bản ký',
                              hint: 'VD: Thiếu chữ ký trang 3, ảnh mờ...',
                            );
                            if (reason != null) {
                              await _runAction(
                                () => widget.managerApi
                                    .rejectSignedContract(c.id, reason),
                                'Đã trả về Chờ ký để Sales nộp lại PDF.',
                              );
                            }
                          },
                          child: const Text('Yêu cầu sửa'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          onPressed: () => _runAction(
                            () => widget.managerApi.confirmSignedContract(c.id),
                            c.depositRequiredAmount > c.depositPaidAmount
                                ? 'Đã duyệt bản ký — Hợp đồng chuyển sang Chờ đặt cọc.'
                                : 'Đã duyệt bản ký → Chuẩn bị giao hàng.',
                          ),
                          child: Text(
                            c.depositRequiredAmount > c.depositPaidAmount
                                ? 'Duyệt bản ký → Mở cọc'
                                : 'Duyệt → Chuẩn bị',
                          ),
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.pendingDeposit => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          onPressed: () =>
                              _handleApproveCancelWithSettlement(c),
                          child: const Text('Hủy hợp đồng'),
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.preparing => Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: () => _handleApproveCancelWithSettlement(c),
                        child: const Text('Hủy HĐ'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.route_rounded, size: 18),
                          label: const Text('Lập / Ghép lịch giao'),
                          onPressed: () async {
                            final ok = await CreateDeliveryTripScreen.open(
                              context,
                              managerApi: widget.managerApi,
                              contractApi: widget.contractApi,
                              preselectedContractId: c.id,
                            );
                            if (ok == true && mounted) {
                              _mutated = true;
                              _load();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.partiallyDelivered => Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: () => _handleApproveCancelWithSettlement(c),
                        child: const Text('Hủy HĐ'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.add_road_rounded, size: 18),
                          label: const Text('Tạo / Ghép lịch giao bù'),
                          onPressed: () async {
                            final ok = await CreateDeliveryTripScreen.open(
                              context,
                              managerApi: widget.managerApi,
                              contractApi: widget.contractApi,
                              preselectedContractId: c.id,
                            );
                            if (ok == true && mounted) {
                              _mutated = true;
                              _load();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.cancellationRequested => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final reason = await _askReason(
                              title: 'Từ chối yêu cầu hủy',
                              hint: 'Lý do tiếp tục thực hiện hợp đồng...',
                              requiredReason: false,
                            );
                            if (reason != null) {
                              await _runAction(
                                () => widget.managerApi.decideCancelContract(
                                  c.id,
                                  approve: false,
                                  reason: reason,
                                ),
                                'Đã từ chối hủy và khôi phục trạng thái cũ.',
                              );
                            }
                          },
                          child: const Text('Từ chối hủy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: () => _handleApproveCancelWithSettlement(c),
                          child: const Text('Duyệt hủy HĐ'),
                        ),
                      ),
                    ],
                  ),
                RentalContractStatus.delivered ||
                RentalContractStatus.expired => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await CreateRetrievalTripScreen.open(
                              context,
                              managerApi: widget.managerApi,
                              preselectedContractId: c.id,
                            );
                            if (ok == true && mounted) {
                              _mutated = true;
                              _load();
                            }
                          },
                          icon: const Icon(
                            Icons.assignment_return_outlined,
                            size: 18,
                          ),
                          label: const Text('Lịch thu hồi'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          onPressed: () => _openSettlementSheet(c),
                          icon: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18,
                          ),
                          label: const Text('Quyết toán'),
                        ),
                      ),
                    ],
                  ),
                _ => SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: () => _handleApproveCancelWithSettlement(c),
                      child: const Text('Hủy hợp đồng'),
                    ),
                  ),
              },
      ),
    );
  }


  Future<void> _openSettlementSheet(RentalContract c) async {
    Map<String, dynamic> preview;
    try {
      setState(() => _submitting = true);
      preview = await widget.managerApi.getSettlementPreview(c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;

    final outCount = (preview['outstandingEquipmentCount'] as num?)?.toInt() ?? 0;
    final pendRet = (preview['pendingReturnReceiptCount'] as num?)?.toInt() ?? 0;
    final availDep = (preview['availableDepositAmount'] as num?)?.toDouble() ?? 0;
    final totalUnpaid = (preview['totalUnpaidChargesAmount'] as num?)?.toDouble() ?? 0;
    final projOffset = (preview['projectedDepositOffsetAmount'] as num?)?.toDouble() ?? 0;
    final projRefund = (preview['projectedDepositRefundAmount'] as num?)?.toDouble() ?? 0;
    final projShortfall = (preview['projectedCustomerShortfallAmount'] as num?)?.toDouble() ?? 0;
    final blocking = preview['blockingReason'] as String?;
    final unpaidItems = (preview['unpaidItems'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var applyDeposit = true;
    var refundRemaining = true;
    final noteCtrl = TextEditingController();
    final canExecute = outCount == 0 && pendRet == 0;

    final submitted = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                        'Quyết toán & Hoàn cọc • ${c.contractCode}',
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
                if (blocking != null && blocking.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      blocking,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _settleRow('Máy chưa thu hồi', '$outCount máy'),
                      _settleRow('Phiếu thu hồi chờ kho', '$pendRet phiếu'),
                      const Divider(height: 14),
                      _settleRow(
                        'Tiền cọc khả dụng',
                        CurrencyFormatter.vnd(availDep),
                        bold: true,
                      ),
                      _settleRow(
                        'Tổng nợ / phạt chưa trả',
                        CurrencyFormatter.vnd(totalUnpaid),
                        valueColor: totalUnpaid > 0
                            ? AppColors.error
                            : AppColors.success,
                        bold: true,
                      ),
                      _settleRow(
                        'Dự kiến cấn trừ cọc',
                        CurrencyFormatter.vnd(projOffset),
                        valueColor: AppColors.primary,
                      ),
                      _settleRow(
                        'Dự kiến hoàn cọc cho khách',
                        CurrencyFormatter.vnd(projRefund),
                        valueColor: AppColors.success,
                        bold: true,
                      ),
                      if (projShortfall > 0)
                        _settleRow(
                          'Khách còn phải đóng thêm',
                          CurrencyFormatter.vnd(projShortfall),
                          valueColor: AppColors.error,
                          bold: true,
                        ),
                    ],
                  ),
                ),
                if (unpaidItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Chi tiết khoản chưa thanh toán:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  for (final it in unpaidItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '• ${it['description'] ?? it['chargeType']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.vnd(
                              (it['remainingAmount'] as num?)?.toDouble() ?? 0,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (canExecute) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Cấn trừ nợ/phạt vào tiền đặt cọc',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    value: applyDeposit,
                    onChanged: (v) => setModalState(() => applyDeposit = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ghi nhận hoàn cọc dư cho khách hàng',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    value: refundRemaining,
                    onChanged: (v) => setModalState(() => refundRemaining = v),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú biên bản quyết toán (tùy chọn)',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(ctx, {
                      'applyDeposit': applyDeposit,
                      'refundRemaining': refundRemaining,
                      'note': noteCtrl.text.trim(),
                    }),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: Text(
                      projShortfall == 0
                          ? 'Xác nhận quyết toán & Hoàn tất HĐ'
                          : 'Ghi nhận cấn trừ cọc (giữ công nợ thiếu)',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    noteCtrl.dispose();
    if (submitted == null || !mounted) return;

    await _runAction(
      () async {
        final res = await widget.managerApi.settleContract(
          c.id,
          applyDepositToUnpaidCharges: submitted['applyDeposit'] == true,
          refundRemainingDeposit: submitted['refundRemaining'] == true,
          note: submitted['note'] as String?,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message'] as String? ?? 'Đã quyết toán hợp đồng.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      'Đã cập nhật quyết toán hợp đồng.',
    );
  }

  Widget _settleRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  void _showImageViewer(String url, String title) {
    MediaViewerGallery.openImageViewer(context, url, title: title);
  }

  Widget _card({required Widget child}) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      );

  Widget _buildSignedDepositCard(RentalContract c) {
    final isPaid = c.depositPaidAmount >= c.depositRequiredAmount;
    final missing = (c.depositRequiredAmount - c.depositPaidAmount)
        .clamp(0.0, double.infinity);

    final pendingCashDeposits = (_billing?.transactions ?? const [])
        .where(
          (t) =>
              t.targetType == PaymentTargetType.deposit &&
              t.paymentMethod == PaymentMethod.cash &&
              t.status == PaymentTransactionStatus.pending,
        )
        .toList();

    if (isPaid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Khách đã đóng đủ tiền đặt cọc. Bạn có thể bấm "Duyệt → Chuẩn bị" để chuyển kho soạn máy.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pendingCashDeposits.isNotEmpty
            ? AppColors.warningLight
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (pendingCashDeposits.isNotEmpty
                  ? AppColors.warning
                  : AppColors.error)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pendingCashDeposits.isNotEmpty
                ? 'Có hóa đơn thu cọc trực tiếp từ Sales chờ duyệt!'
                : 'Chưa nhận đủ tiền đặt cọc (còn thiếu ${CurrencyFormatter.vnd(missing)})',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: pendingCashDeposits.isNotEmpty
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pendingCashDeposits.isNotEmpty
                ? 'Duyệt hóa đơn thu cọc bên dưới để tự động chuyển hợp đồng sang Chuẩn bị giao hàng (hạn cọc: trước ${DateFormatter.date(c.depositDeadline)}).'
                : 'Hợp đồng đang chờ khách đặt cọc qua VNPAY hoặc Sales thu trực tiếp (hạn chót trước ${DateFormatter.date(c.depositDeadline)}, quá hạn hệ thống tự hủy). Khi nhận đủ cọc sẽ tự động chuyển sang Chuẩn bị.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          for (final txn in pendingCashDeposits) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hóa đơn ${txn.txnRef} • ${CurrencyFormatter.vnd(txn.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Sales xác nhận thu: ${txn.createdByName ?? 'Nhân viên kinh doanh'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (txn.note != null && txn.note!.trim().isNotEmpty)
                    Text(
                      'Ghi chú: ${txn.note!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _submitting
                              ? null
                              : () async {
                                  final reason = await _askReason(
                                    title: 'Từ chối hóa đơn ${txn.txnRef}',
                                    hint: 'VD: Chưa nhận đủ tiền mặt tại quỹ...',
                                  );
                                  if (reason != null) {
                                    await _runAction(
                                      () => widget.managerApi.rejectCashPayment(
                                        txn.id,
                                        reason,
                                      ),
                                      'Đã từ chối hóa đơn thu cọc ${txn.txnRef}.',
                                    );
                                  }
                                },
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _submitting
                              ? null
                              : () => _runAction(
                                  () => widget.managerApi.verifyCashPayment(
                                    txn.id,
                                  ),
                                  'Đã duyệt hóa đơn cọc ${txn.txnRef}! Hợp đồng tự động chuyển sang Chuẩn bị nếu đã đủ cọc.',
                                ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Duyệt hóa đơn cọc'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool boldValue = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: boldValue ? FontWeight.w800 : FontWeight.w600,
                  color: boldValue ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.requiredReason,
  });

  final String title;
  final String hint;
  final bool requiredReason;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (widget.requiredReason && text.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập lý do.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 17)),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        autofocus: true,
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _errorText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}


class _CancelSettlementDialog extends StatefulWidget {
  const _CancelSettlementDialog({required this.contract});

  final RentalContract contract;

  @override
  State<_CancelSettlementDialog> createState() =>
      _CancelSettlementDialogState();
}

class _CancelSettlementDialogState extends State<_CancelSettlementDialog> {
  final _reasonCtrl = TextEditingController();
  final _transportCtrl = TextEditingController(text: '0');
  final _penaltyCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _transportCtrl.dispose();
    _penaltyCtrl.dispose();
    super.dispose();
  }

  double get _transport =>
      double.tryParse(_transportCtrl.text.replaceAll(',', '').trim()) ?? 0;
  double get _penalty =>
      double.tryParse(_penaltyCtrl.text.replaceAll(',', '').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final depositPaid = widget.contract.depositPaidAmount;
    final totalFees = _transport + _penalty;
    final shortfall = (totalFees - depositPaid).clamp(0, double.infinity);

    return AlertDialog(
      title: const Text(
        'Xác nhận hủy & Quyết toán phí',
        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống sẽ giữ lại toàn bộ tiền cọc đã đóng, tự động hủy/thu hồi phiếu giao hàng và gửi thông báo App + Email cho khách.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Lý do hủy hợp đồng',
                hintText: 'VD: Khách đơn phương hủy khi đang vận chuyển...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _transportCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Phí vận chuyển thực tế (VNĐ)',
                helperText: 'Thu hồi ưu đãi miễn phí ship (nếu có)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _penaltyCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Phí phạt hủy hợp đồng (VNĐ)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiền cọc đã đóng (giữ lại): ${CurrencyFormatter.vnd(depositPaid)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Text(
                    'Tổng phí vận chuyển + phạt: ${CurrencyFormatter.vnd(totalFees)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shortfall > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Cọc không đủ bù → Lập khoản thu thêm: ${CurrencyFormatter.vnd(shortfall)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, (
            reason: _reasonCtrl.text.trim(),
            penalty: _penalty < 0 ? 0.0 : _penalty,
            transport: _transport < 0 ? 0.0 : _transport,
          )),
          child: const Text('Xác nhận hủy HĐ'),
        ),
      ],
    );
  }
}
