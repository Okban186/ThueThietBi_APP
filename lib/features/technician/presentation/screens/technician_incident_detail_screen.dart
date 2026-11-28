import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/utils/maps_launcher.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/datasources/technician_incident_api.dart';
import '../../data/models/technician_incident_models.dart';
import '../widgets/evidence_photo_picker.dart';

/// Màn chi tiết & xử lý sự cố thiết bị cho KTV (hỗ trợ mở Google Maps từng chặng, gọi khách, xác nhận tới hiện trường, chốt xử lý / tạo phiếu thu hồi).
class TechnicianIncidentDetailScreen extends StatefulWidget {
  const TechnicianIncidentDetailScreen({
    super.key,
    required this.incidentApi,
    required this.technicianApi,
    required this.incidentId,
  });

  final TechnicianIncidentApi incidentApi;
  final TechnicianApi technicianApi;
  final String incidentId;

  static Future<bool?> open(
    BuildContext context, {
    required TechnicianIncidentApi incidentApi,
    required TechnicianApi technicianApi,
    required String incidentId,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TechnicianIncidentDetailScreen(
          incidentApi: incidentApi,
          technicianApi: technicianApi,
          incidentId: incidentId,
        ),
      ),
    );
  }

  @override
  State<TechnicianIncidentDetailScreen> createState() =>
      _TechnicianIncidentDetailScreenState();
}

class _TechnicianIncidentDetailScreenState
    extends State<TechnicianIncidentDetailScreen> {
  TechnicianIncidentDetail? _detail;
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
      final data = await widget.incidentApi.getIncidentDetail(
        widget.incidentId,
      );
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được chi tiết sự cố.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _arriveOnSite() async {
    setState(() => _acting = true);
    try {
      final updated = await widget.incidentApi.startOnSite(widget.incidentId);
      if (mounted) {
        setState(() {
          _detail = updated;
          _changed = true;
        });
        _msg('Đã cập nhật trạng thái đang xử lý tại hiện trường (ON_SITE).');
      }
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể cập nhật trạng thái tới nơi.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openResolveSheet(TechnicianIncidentDetail detail) async {
    final res = await showModalBottomSheet<TechnicianResolveIncidentResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResolveIncidentSheet(
        incidentApi: widget.incidentApi,
        technicianApi: widget.technicianApi,
        detail: detail,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            d?.incidentCode ?? 'Chi tiết sự cố',
            style: const TextStyle(fontWeight: FontWeight.w700),
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
                    if (d.isOnSiteMode) ...[
                      const SizedBox(height: 10),
                      _buildRoleBanner(d),
                    ],
                    const SizedBox(height: 12),
                    _buildLocationAndContactCard(d),
                    if (d.members.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildTeamCard(d),
                    ],
                    const SizedBox(height: 12),
                    _buildItemsCard(d),
                    if (d.attachmentUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAttachmentsCard(d.attachmentUrls),
                    ],
                    if (d.isOnSiteMode && d.depot != null) ...[
                      const SizedBox(height: 12),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chặng về: ${d.depot!.warehouseName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            if (d.depot!.address != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                d.depot!.address!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.home_work_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Mở Google Maps chỉ đường về Kho',
                                ),
                                onPressed: () => MapsLauncher.openDirections(
                                  context,
                                  latitude: d.depot!.latitude,
                                  longitude: d.depot!.longitude,
                                  address: d.depot!.address,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: d != null && (d.canArrive || d.canResolve)
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (d.canArrive) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _acting ? null : _arriveOnSite,
                            icon: _acting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.location_on_outlined),
                            label: const Text('Đã tới nơi'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (d.canResolve)
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _acting
                                ? null
                                : () => _openResolveSheet(d),
                            icon: const Icon(Icons.task_alt_rounded),
                            label: const Text(
                              'Chốt kết quả xử lý',
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

  Widget _buildHeaderCard(TechnicianIncidentDetail d) {
    final (stLabel, stFg, stBg) = switch (d.status.toUpperCase()) {
      'REMOTE_SUPPORT' => ('Hỗ trợ Online', AppColors.info, AppColors.infoLight),
      'DISPATCHING' => (
        'Đang điều phối',
        AppColors.warning,
        AppColors.warningLight,
      ),
      'ON_SITE' => (
        'Đang xử lý tại chỗ',
        AppColors.primary,
        AppColors.primaryLight,
      ),
      'RETURN_REQUIRED' => (
        'Cần thu hồi về kho',
        AppColors.error,
        AppColors.errorLight,
      ),
      'RESOLVED' => ('Đã xử lý xong', AppColors.success, AppColors.successLight),
      _ => (d.status, AppColors.textSecondary, AppColors.surfaceSecondary),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.incidentCode,
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
            d.companyName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            d.description,
            style: const TextStyle(fontSize: 13.5),
          ),
          if (d.resolution != null && d.resolution!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: d.status.toUpperCase() == 'RETURN_REQUIRED'
                    ? AppColors.warningLight
                    : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Kết quả xử lý: ${d.resolution!}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: d.status.toUpperCase() == 'RETURN_REQUIRED'
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Báo lúc: ${DateFormatter.dateTime(d.reportedAt)}'
            '${d.scheduledStartAt != null ? '\nLịch cử đội: ${DateFormatter.dateTime(d.scheduledStartAt!)}' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBanner(TechnicianIncidentDetail d) => Container(
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
      children: [
        Icon(
          d.isLeader ? Icons.star_rounded : Icons.visibility_outlined,
          size: 18,
          color: d.isLeader ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            d.isLeader
                ? 'Bạn là KTV trưởng — có quyền xác nhận tới hiện trường và chốt xử lý sự cố.'
                : 'Bạn là Thành viên đi cùng — bạn có thể xem chi tiết và mở Google Maps chỉ đường.',
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

  Widget _buildLocationAndContactCard(TechnicianIncidentDetail d) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Liên hệ & Địa điểm',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 17,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${d.contactName ?? 'Khách hàng'}'
                '${d.contactPhone != null ? ' • ${d.contactPhone}' : ''}',
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            if (d.contactPhone != null && d.contactPhone!.trim().isNotEmpty)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => MapsLauncher.callPhone(context, d.contactPhone),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: const Text('Gọi'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.serviceAddress?.trim().isNotEmpty == true
                    ? d.serviceAddress!
                    : 'Chưa có địa chỉ cụ thể',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('Mở Google Maps chỉ đường tới điểm sự cố'),
            onPressed: () => MapsLauncher.openDirections(
              context,
              latitude: d.latitude,
              longitude: d.longitude,
              address: d.serviceAddress,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTeamCard(TechnicianIncidentDetail d) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đội xử lý hiện trường (${d.members.length} người)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        for (final m in d.members)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  m.isLeader ? Icons.star_rounded : Icons.person_outline,
                  size: 17,
                  color: m.isLeader
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${m.fullName} (${m.employeeCode})${m.isLeader ? ' • KTV trưởng' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildItemsCard(TechnicianIncidentDetail d) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thiết bị gặp sự cố (${d.items.length} máy)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        for (final it in d.items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${it.serialNumber} • ${it.modelName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (it.contractCode != null)
                  Text(
                    'Hợp đồng: ${it.contractCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (it.customerDescription != null &&
                    it.customerDescription!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Khách mô tả: ${it.customerDescription!}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
                if (it.assessment != null &&
                    it.assessment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'KTV đánh giá: ${it.assessment!}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildAttachmentsCard(List<String> urls) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ảnh đính kèm sự cố (${urls.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        MediaViewerGallery(
          thumbSize: 88,
          items: [
            for (var idx = 0; idx < urls.length; idx++)
              GalleryMediaItem(
                url: urls[idx],
                fileName: 'Ảnh sự cố #${idx + 1}',
              ),
          ],
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

class _ResolveIncidentSheet extends StatefulWidget {
  const _ResolveIncidentSheet({
    required this.incidentApi,
    required this.technicianApi,
    required this.detail,
  });

  final TechnicianIncidentApi incidentApi;
  final TechnicianApi technicianApi;
  final TechnicianIncidentDetail detail;

  @override
  State<_ResolveIncidentSheet> createState() => _ResolveIncidentSheetState();
}

class _ResolveIncidentSheetState extends State<_ResolveIncidentSheet> {
  final _resolutionCtrl = TextEditingController();
  final Map<String, TextEditingController> _assessCtrls = {};
  final Set<String> _returnEqIds = {};

  String _outcome = 'RESOLVED';
  List<String> _photos = const [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final it in widget.detail.items) {
      _assessCtrls[it.equipmentId] = TextEditingController(
        text: it.assessment ?? '',
      );
      _returnEqIds.add(it.equipmentId);
    }
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    for (final c in _assessCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _photoRequired =>
      widget.detail.isOnSiteMode || _outcome == 'RETURN_REQUIRED';

  Future<void> _submit() async {
    if (_resolutionCtrl.text.trim().isEmpty) {
      _msg('Vui lòng nhập kết quả xử lý / lý do thu hồi.', isError: true);
      return;
    }
    if (_photoRequired && _photos.isEmpty) {
      _msg(
        'Vui lòng chụp ít nhất 1 ảnh minh chứng xử lý hiện trường / tình trạng máy.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fileIds = _photos.isEmpty
          ? const <String>[]
          : await widget.technicianApi.uploadEvidenceImages(
              _photos,
              folder: 'incident',
            );

      final assessments = [
        for (final it in widget.detail.items)
          TechnicianIncidentAssessmentInput(
            equipmentId: it.equipmentId,
            assessment: _assessCtrls[it.equipmentId]?.text,
            needsReturn: _returnEqIds.contains(it.equipmentId),
          ),
      ];

      final res = await widget.incidentApi.resolveIncident(
        widget.detail.incidentId,
        outcome: _outcome,
        resolution: _resolutionCtrl.text,
        itemAssessments: assessments,
        attachmentFileIds: fileIds,
      );

      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        _msg(
          apiErrorMessage(e, fallback: 'Không thể cập nhật kết quả sự cố.'),
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
                    'Chốt xử lý • ${widget.detail.incidentCode}',
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
            if (!widget.detail.isOnSiteMode)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'RESOLVED',
                    icon: Icon(Icons.check_circle_outline, size: 17),
                    label: Text('Khắc phục online xong'),
                  ),
                  ButtonSegment(
                    value: 'REMOTE_FAILED',
                    icon: Icon(Icons.report_problem_outlined, size: 17),
                    label: Text('Không khắc phục được'),
                  ),
                ],
                selected: {_outcome},
                onSelectionChanged: _submitting
                    ? null
                    : (s) => setState(() => _outcome = s.first),
              )
            else
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'RESOLVED',
                    icon: Icon(Icons.check_circle_outline, size: 17),
                    label: Text('Đã khắc phục xong'),
                  ),
                  ButtonSegment(
                    value: 'RETURN_REQUIRED',
                    icon: Icon(Icons.assignment_return_outlined, size: 17),
                    label: Text('Thu hồi về kho'),
                  ),
                ],
                selected: {_outcome},
                onSelectionChanged: _submitting
                    ? null
                    : (s) => setState(() => _outcome = s.first),
              ),
            if (_outcome == 'REMOTE_FAILED') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Sự cố sẽ được chuyển lại cho Quản lý kèm lý do để phân công KTV khác hoặc cử đội tới hiện trường kiểm tra trực tiếp trước khi quyết định thu hồi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_outcome == 'RETURN_REQUIRED') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Hệ thống sẽ tự động tạo phiếu thu hồi (INCIDENT_RETURN) cho các máy được chọn bên dưới để Thủ kho kiểm nhận và chuyển sang bảo trì.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _resolutionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _outcome == 'RESOLVED'
                    ? (widget.detail.isOnSiteMode
                          ? 'Kết quả khắc phục sự cố *'
                          : 'Hướng dẫn / kết quả khắc phục online *')
                    : _outcome == 'REMOTE_FAILED'
                    ? 'Lý do không khắc phục được online *'
                    : 'Lý do cần thu hồi về kho *',
                hintText: _outcome == 'REMOTE_FAILED'
                    ? 'VD: Lỗi phần cứng bo mạch nguồn, cần cử đội mang thiết bị thay thế tới hiện trường...'
                    : null,
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Đánh giá từng thiết bị:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final it in widget.detail.items)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.serialNumber} • ${it.modelName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_outcome == 'RETURN_REQUIRED')
                          Checkbox(
                            value: _returnEqIds.contains(it.equipmentId),
                            activeColor: AppColors.error,
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() {
                                    if (v == true) {
                                      _returnEqIds.add(it.equipmentId);
                                    } else {
                                      _returnEqIds.remove(it.equipmentId);
                                    }
                                  }),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _assessCtrls[it.equipmentId],
                      decoration: const InputDecoration(
                        labelText: 'Đánh giá kỹ thuật (tùy chọn)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            EvidencePhotoPicker(
              title: 'Ảnh minh chứng xử lý sự cố',
              subtitle: _photoRequired
                  ? 'Bắt buộc ít nhất 1 ảnh hiện trường / tình trạng máy.'
                  : 'Tùy chọn (khuyên đính kèm ảnh chụp màn hình/hướng dẫn nếu có).',
              filePaths: _photos,
              maxPhotos: 10,
              required: _photoRequired,
              compact: true,
              onChanged: (list) => setState(() => _photos = list),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _outcome == 'RETURN_REQUIRED'
                    ? AppColors.error
                    : _outcome == 'REMOTE_FAILED'
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
                  : Icon(
                      _outcome == 'REMOTE_FAILED'
                          ? Icons.send_outlined
                          : Icons.check_rounded,
                    ),
              label: Text(
                _outcome == 'RETURN_REQUIRED'
                    ? 'Xác nhận thu hồi về kho'
                    : _outcome == 'REMOTE_FAILED'
                    ? 'Báo Quản lý không khắc phục được'
                    : 'Xác nhận đã khắc phục thành công',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
