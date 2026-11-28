import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/features/equipment/presentation/storekeeper/screens/equipment_history_screen.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/datasources/technician_maintenance_api.dart';
import '../../data/models/technician_maintenance_models.dart';
import '../widgets/evidence_photo_picker.dart';

/// Màn hình chi tiết & xử lý phiếu bảo trì thiết bị tại kho.
class TechnicianMaintenanceDetailScreen extends StatefulWidget {
  const TechnicianMaintenanceDetailScreen({
    super.key,
    required this.maintenanceApi,
    required this.technicianApi,
    required this.taskId,
  });

  final TechnicianMaintenanceApi maintenanceApi;
  final TechnicianApi technicianApi;
  final String taskId;

  static Future<bool?> open(
    BuildContext context, {
    required TechnicianMaintenanceApi maintenanceApi,
    required TechnicianApi technicianApi,
    required String taskId,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TechnicianMaintenanceDetailScreen(
          maintenanceApi: maintenanceApi,
          technicianApi: technicianApi,
          taskId: taskId,
        ),
      ),
    );
  }

  @override
  State<TechnicianMaintenanceDetailScreen> createState() =>
      _TechnicianMaintenanceDetailScreenState();
}

class _TechnicianMaintenanceDetailScreenState
    extends State<TechnicianMaintenanceDetailScreen> {
  MaintenanceTaskDetail? _detail;
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
      final data = await widget.maintenanceApi.getTaskDetail(widget.taskId);
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được chi tiết phiếu bảo trì.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimTask() async {
    setState(() => _acting = true);
    try {
      final updated = await widget.maintenanceApi.claimTask(widget.taskId);
      if (mounted) {
        setState(() {
          _detail = updated;
          _changed = true;
        });
        _msg('Bạn đã tiếp nhận phụ trách phiếu bảo trì này.');
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể tiếp nhận phiếu bảo trì.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _startTask() async {
    setState(() => _acting = true);
    try {
      final updated = await widget.maintenanceApi.startTask(widget.taskId);
      if (mounted) {
        setState(() {
          _detail = updated;
          _changed = true;
        });
        _msg('Đã bắt đầu kiểm tra / bảo trì thiết bị.');
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể bắt đầu phiếu bảo trì.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openCompleteSheet(
    MaintenanceTaskSummary task,
    MaintenanceIncidentContext? incidentContext,
  ) async {
    final res = await showModalBottomSheet<CompleteMaintenanceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CompleteMaintenanceSheet(
        maintenanceApi: widget.maintenanceApi,
        technicianApi: widget.technicianApi,
        task: task,
        incidentContext: incidentContext,
      ),
    );

    if (res != null && mounted) {
      _changed = true;
      _msg(res.message);
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
    final t = d?.task;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Chi tiết bảo trì',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null || t == null
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
                    if (d.incidentContext != null) ...[
                      _buildIncidentContextCard(d.incidentContext!),
                      const SizedBox(height: 12),
                    ],
                    _buildTaskInfoCard(t),
                    const SizedBox(height: 12),
                    if (d.attachmentUrls.isNotEmpty) ...[
                      _buildAttachmentsCard(d.attachmentUrls),
                      const SizedBox(height: 12),
                    ],
                    _buildRecordsCard(d.records),
                  ],
                ),
              ),
        bottomNavigationBar: t != null && t.canComplete
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: (t.isPending && !t.isClaimed)
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _acting ? null : _claimTask,
                          icon: _acting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.assignment_ind_outlined),
                          label: const Text(
                            'Tiếp nhận xử lý phiếu bảo trì này',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )
                      : Row(
                          children: [
                            if (t.isPending) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  onPressed: _acting ? null : _startTask,
                                  icon: _acting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Bắt đầu'),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed: _acting
                                    ? null
                                    : () => _openCompleteSheet(
                                        t,
                                        d?.incidentContext,
                                      ),
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                label: const Text(
                                  'Hoàn tất & chốt kết quả',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildIncidentContextCard(MaintenanceIncidentContext ctx) {
    final faultLabel = switch (ctx.existingFaultType?.toUpperCase()) {
      'TECHNICAL_FAULT' => 'Lỗi kỹ thuật / hao mòn tự nhiên (0 đ)',
      'CUSTOMER_FAULT' => 'Lỗi do khách hàng',
      _ => 'Chưa phân định trách nhiệm',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thu hồi từ sự cố ${ctx.incidentCode}${ctx.contractCode != null ? ' • ${ctx.contractCode}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Khách hàng: ${ctx.companyName}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'Mô tả sự cố: ${ctx.incidentDescription}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Trách nhiệm hiện tại: $faultLabel'
            '${ctx.existingChargeAmount != null ? ' • Đề xuất/Phí: ${CurrencyFormatter.vnd(ctx.existingChargeAmount!)} (${ctx.existingChargeStatus ?? ''})' : ''}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Khi bấm "Hoàn tất & chốt kết quả", KTV vui lòng phân định rõ lỗi kỹ thuật (0 đ) hay lỗi khách hàng để gửi Quản lý duyệt chi phí & mở giao máy thay thế.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInfoCard(MaintenanceTaskSummary t) {
    final (stLabel, stFg, stBg) = switch (t.status.toUpperCase()) {
      'IN_PROGRESS' => ('Đang bảo trì', AppColors.info, AppColors.infoLight),
      'COMPLETED' => ('Hoàn tất', AppColors.success, AppColors.successLight),
      'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
      _ => ('Chờ xử lý', AppColors.warning, AppColors.warningLight),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.serialNumber,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill(stLabel, stFg, stBg),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${t.modelName} (${t.modelCode})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(t.typeLabel, AppColors.primary, AppColors.primaryLight),
              _pill(
                'Kho: ${t.warehouseName}',
                AppColors.textSecondary,
                AppColors.surfaceSecondary,
              ),
              _pill(
                'Trạng thái máy: ${t.equipmentStatus}',
                AppColors.textPrimary,
                AppColors.surfaceSecondary,
              ),
              _pill(
                'Tình trạng: ${t.equipmentCondition}',
                AppColors.textPrimary,
                AppColors.surfaceSecondary,
              ),
            ],
          ),
          const Divider(height: 20),
          const Text(
            'Nội dung yêu cầu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            t.description,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.engineering_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.isClaimed
                      ? 'KTV phụ trách: ${t.assignedTechnicianName ?? 'Đã tiếp nhận'}'
                      : 'KTV phụ trách: Chưa có người tiếp nhận',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t.isClaimed ? AppColors.primary : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => EquipmentHistoryScreen.openWithClient(
                context,
                apiClient: widget.technicianApi.apiClient,
                equipmentId: t.equipmentId,
                serialHint: t.serialNumber,
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Xem lịch sử sửa chữa & linh kiện của máy'),
            ),
          ),
          if (t.result != null && t.result!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Kết luận: ${t.result!}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tạo lúc: ${DateFormatter.dateTime(t.createdAt)}'
            '${t.startedAt != null ? '\nBắt đầu: ${DateFormatter.dateTime(t.startedAt!)}' : ''}'
            '${t.completedAt != null ? '\nHoàn tất: ${DateFormatter.dateTime(t.completedAt!)}' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard(List<String> urls) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ảnh minh chứng bảo trì (${urls.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        MediaViewerGallery(
          thumbSize: 88,
          items: [
            for (var idx = 0; idx < urls.length; idx++)
              GalleryMediaItem(
                url: urls[idx],
                fileName: 'Ảnh bảo trì #${idx + 1}',
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRecordsCard(List<MaintenanceRecordItem> records) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhật ký bảo trì & linh kiện (${records.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Text(
            'Chưa có biên bản kiểm tra/sửa chữa nào.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        else
          for (final rec in records)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rec.performedByName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (rec.completedAt != null)
                        Text(
                          DateFormatter.dateTime(rec.completedAt!),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(rec.description, style: const TextStyle(fontSize: 13)),
                  if (rec.note != null && rec.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ghi chú: ${rec.note!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Nhân công: ${CurrencyFormatter.vnd(rec.laborCost)} • Linh kiện: ${CurrencyFormatter.vnd(rec.partsTotalCost)} • Tổng: ${CurrencyFormatter.vnd(rec.totalCost)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (rec.parts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final p in rec.parts)
                      Text(
                        '• ${p.name}: ${p.quantity} × ${CurrencyFormatter.vnd(p.unitCost)} = ${CurrencyFormatter.vnd(p.totalCost)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ],
              ),
            ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
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

class _PartDraft {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final unitCostCtrl = TextEditingController(text: '0');

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCostCtrl.dispose();
  }
}

class _CompleteMaintenanceSheet extends StatefulWidget {
  const _CompleteMaintenanceSheet({
    required this.maintenanceApi,
    required this.technicianApi,
    required this.task,
    this.incidentContext,
  });

  final TechnicianMaintenanceApi maintenanceApi;
  final TechnicianApi technicianApi;
  final MaintenanceTaskSummary task;
  final MaintenanceIncidentContext? incidentContext;

  @override
  State<_CompleteMaintenanceSheet> createState() =>
      _CompleteMaintenanceSheetState();
}

class _CompleteMaintenanceSheetState extends State<_CompleteMaintenanceSheet> {
  final _descCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();
  final _laborCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  final _proposedAmountCtrl = TextEditingController();
  final _proposedDescCtrl = TextEditingController();
  final List<_PartDraft> _parts = [];

  String _outcome = 'AVAILABLE';
  String _condition = 'GOOD';
  String _incidentFaultType = 'TECHNICAL_FAULT';
  String _proposedChargeType = 'REPAIR';
  List<String> _photos = const [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existingFault = widget.incidentContext?.existingFaultType?.toUpperCase();
    if (existingFault == 'CUSTOMER_FAULT' || existingFault == 'TECHNICAL_FAULT') {
      _incidentFaultType = existingFault!;
    }
    final existingAmt = widget.incidentContext?.existingChargeAmount;
    if (existingAmt != null && existingAmt > 0) {
      _proposedAmountCtrl.text = existingAmt.round().toString();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _resultCtrl.dispose();
    _laborCtrl.dispose();
    _noteCtrl.dispose();
    _proposedAmountCtrl.dispose();
    _proposedDescCtrl.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      _msg('Vui lòng nhập nội dung kiểm tra / sửa chữa đã thực hiện.', isError: true);
      return;
    }
    if (_resultCtrl.text.trim().isEmpty) {
      _msg('Vui lòng nhập kết luận sau bảo trì.', isError: true);
      return;
    }
    if (_photos.isEmpty) {
      _msg('Vui lòng chụp ít nhất 1 ảnh minh chứng hoàn tất bảo trì.', isError: true);
      return;
    }

    final partInputs = <MaintenancePartInput>[];
    for (final p in _parts) {
      final name = p.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final qty = double.tryParse(p.qtyCtrl.text.trim()) ?? 0;
      final unitCost =
          double.tryParse(p.unitCostCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;
      if (qty <= 0) {
        _msg('Số lượng linh kiện "$name" phải lớn hơn 0.', isError: true);
        return;
      }
      partInputs.add(
        MaintenancePartInput(name: name, quantity: qty, unitCost: unitCost),
      );
    }

    final laborCost =
        double.tryParse(_laborCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final partsTotal = partInputs.fold<double>(
      0,
      (sum, p) => sum + (p.quantity * p.unitCost),
    );

    final hasIncident = widget.incidentContext != null;
    double? proposedAmount;
    if (hasIncident && _incidentFaultType == 'CUSTOMER_FAULT') {
      final rawProp = _proposedAmountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
      proposedAmount = rawProp.isEmpty
          ? (laborCost + partsTotal)
          : (double.tryParse(rawProp) ?? 0);
      if (proposedAmount <= 0) {
        _msg(
          'Với lỗi do khách hàng, vui lòng nhập chi phí nhân công/linh kiện hoặc số tiền đề xuất thu > 0 đ.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final fileIds = await widget.technicianApi.uploadEvidenceImages(
        _photos,
        folder: 'maintenance',
      );
      final res = await widget.maintenanceApi.completeTask(
        widget.task.id,
        description: _descCtrl.text,
        result: _resultCtrl.text,
        outcome: _outcome,
        newCondition: _outcome == 'DAMAGED' ? 'DAMAGED' : _condition,
        laborCost: laborCost,
        note: _noteCtrl.text,
        parts: partInputs,
        attachmentFileIds: fileIds,
        incidentFaultType: hasIncident ? _incidentFaultType : null,
        proposedChargeType: hasIncident && _incidentFaultType == 'CUSTOMER_FAULT'
            ? _proposedChargeType
            : null,
        proposedChargeAmount: proposedAmount,
        proposedChargeDescription:
            hasIncident && _incidentFaultType == 'CUSTOMER_FAULT'
            ? _proposedDescCtrl.text
            : null,
      );
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể hoàn tất phiếu bảo trì.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
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
                    'Chốt bảo trì • ${widget.task.serialNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Kết quả đầu ra của thiết bị *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'AVAILABLE',
                  label: Text('Đạt (Về kho)'),
                ),
                ButtonSegment(
                  value: 'KEEP_MAINTENANCE',
                  label: Text('Sửa tiếp'),
                ),
                ButtonSegment(
                  value: 'DAMAGED',
                  label: Text('Hỏng nặng'),
                ),
              ],
              selected: {_outcome},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() {
                      _outcome = s.first;
                      if (_outcome == 'AVAILABLE' && _condition == 'DAMAGED') {
                        _condition = 'GOOD';
                      }
                    }),
            ),
            if (_outcome != 'DAMAGED') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: InputDecoration(
                  labelText: 'Tình trạng máy sau bảo trì',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: 'GOOD', child: Text('Tốt (GOOD)')),
                  const DropdownMenuItem(value: 'FAIR', child: Text('Khá (FAIR)')),
                  if (_outcome == 'KEEP_MAINTENANCE')
                    const DropdownMenuItem(
                      value: 'DAMAGED',
                      child: Text('Còn hỏng (DAMAGED)'),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _condition = v);
                      },
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Nội dung kiểm tra / sửa chữa đã làm *',
                hintText: 'VD: Vệ sinh quạt tản nhiệt, thay nguồn, test chạy ổn 30 phút...',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _resultCtrl,
              decoration: InputDecoration(
                labelText: 'Kết luận sau bảo trì *',
                hintText: 'VD: Máy hoạt động ổn định, đủ điều kiện cho thuê lại',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _laborCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Chi phí nhân công (VNĐ)',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _parts.add(_PartDraft())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm linh kiện'),
                ),
              ],
            ),
            if (_parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < _parts.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _parts[i].nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tên linh kiện / vật tư',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            onPressed: _submitting
                                ? null
                                : () => setState(() {
                                    _parts.removeAt(i).dispose();
                                  }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _parts[i].qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'SL',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _parts[i].unitCostCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Đơn giá (VNĐ)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Ghi chú thêm (tùy chọn)',
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (widget.incidentContext != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _incidentFaultType == 'CUSTOMER_FAULT'
                      ? AppColors.errorLight.withValues(alpha: 0.5)
                      : AppColors.successLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (_incidentFaultType == 'CUSTOMER_FAULT'
                            ? AppColors.error
                            : AppColors.success)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Phân định trách nhiệm sự cố (${widget.incidentContext!.incidentCode}) *',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'TECHNICAL_FAULT',
                          label: Text('Lỗi kỹ thuật (0 đ)'),
                        ),
                        ButtonSegment(
                          value: 'CUSTOMER_FAULT',
                          label: Text('Lỗi khách hàng'),
                        ),
                      ],
                      selected: {_incidentFaultType},
                      onSelectionChanged: _submitting
                          ? null
                          : (s) => setState(() {
                              _incidentFaultType = s.first;
                              if (_outcome == 'DAMAGED') {
                                _proposedChargeType = 'REPLACEMENT';
                              }
                            }),
                    ),
                    const SizedBox(height: 8),
                    if (_incidentFaultType == 'TECHNICAL_FAULT')
                      const Text(
                        'Khách không bị phạt (0 đ). Hệ thống sẽ mở khóa ngay cho Kho & Quản lý giao máy thay thế miễn phí.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _proposedChargeType,
                        decoration: InputDecoration(
                          labelText: 'Loại khoản thu đề xuất *',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'REPAIR',
                            child: Text('Chi phí sửa chữa / thay linh kiện (REPAIR)'),
                          ),
                          DropdownMenuItem(
                            value: 'REPLACEMENT',
                            child: Text('Bồi thường hỏng hoàn toàn (REPLACEMENT)'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Chi phí phát sinh khác (OTHER)'),
                          ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _proposedChargeType = v);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _proposedAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Số tiền đề xuất thu khách (VNĐ)',
                          hintText:
                              'Để trống sẽ tự lấy (Nhân công + Tổng linh kiện)',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _proposedDescCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Giải trình lỗi do khách hàng (gửi Manager duyệt)',
                          hintText:
                              'VD: Máy bị rơi vỡ mainboard / vào nước trong quá trình sử dụng...',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            EvidencePhotoPicker(
              title: 'Ảnh minh chứng sau kiểm tra / sửa chữa',
              subtitle: 'Bắt buộc tối thiểu 1 ảnh chụp tình trạng máy sau khi xử lý.',
              filePaths: _photos,
              maxPhotos: 10,
              required: true,
              compact: true,
              onChanged: (list) => setState(() => _photos = list),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _outcome == 'DAMAGED'
                    ? AppColors.error
                    : _outcome == 'KEEP_MAINTENANCE'
                    ? AppColors.warning
                    : AppColors.success,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu & hoàn tất phiếu bảo trì'),
            ),
          ],
        ),
      ),
    );
  }
}
