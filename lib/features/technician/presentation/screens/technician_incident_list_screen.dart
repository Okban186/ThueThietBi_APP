import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/datasources/technician_incident_api.dart';
import '../../data/models/technician_incident_models.dart';
import 'technician_incident_detail_screen.dart';

/// Danh sách sự cố thiết bị được phân công cho Kỹ thuật viên (Hỗ trợ Online & Hiện trường).
class TechnicianIncidentListScreen extends StatefulWidget {
  const TechnicianIncidentListScreen({
    super.key,
    required this.incidentApi,
    required this.technicianApi,
    required this.reloadVersion,
    required this.onChanged,
  });

  final TechnicianIncidentApi incidentApi;
  final TechnicianApi technicianApi;
  final int reloadVersion;
  final VoidCallback onChanged;

  @override
  State<TechnicianIncidentListScreen> createState() =>
      _TechnicianIncidentListScreenState();
}

class _TechnicianIncidentListScreenState
    extends State<TechnicianIncidentListScreen> {
  List<TechnicianIncidentSummary> _items = const [];
  String? _statusFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TechnicianIncidentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.incidentApi.getMyIncidents(
        status: _statusFilter,
      );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được danh sách sự cố.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(TechnicianIncidentSummary item) async {
    final changed = await TechnicianIncidentDetailScreen.open(
      context,
      incidentApi: widget.incidentApi,
      technicianApi: widget.technicianApi,
      incidentId: item.incidentId,
    );
    if (changed == true && mounted) {
      widget.onChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppFilterChip(
                  label: 'Tất cả',
                  selected: _statusFilter == null,
                  onTap: () {
                    setState(() => _statusFilter = null);
                    _load();
                  },
                ),
                AppFilterChip(
                  label: 'Hỗ trợ Online',
                  selected: _statusFilter == 'REMOTE_SUPPORT',
                  onTap: () {
                    setState(() => _statusFilter = 'REMOTE_SUPPORT');
                    _load();
                  },
                ),
                AppFilterChip(
                  label: 'Đang điều phối',
                  selected: _statusFilter == 'DISPATCHING',
                  onTap: () {
                    setState(() => _statusFilter = 'DISPATCHING');
                    _load();
                  },
                ),
                AppFilterChip(
                  label: 'Tại hiện trường',
                  selected: _statusFilter == 'ON_SITE',
                  onTap: () {
                    setState(() => _statusFilter = 'ON_SITE');
                    _load();
                  },
                ),
                AppFilterChip(
                  label: 'Cần thu hồi',
                  selected: _statusFilter == 'RETURN_REQUIRED',
                  onTap: () {
                    setState(() => _statusFilter = 'RETURN_REQUIRED');
                    _load();
                  },
                ),
                AppFilterChip(
                  label: 'Đã xử lý',
                  selected: _statusFilter == 'RESOLVED',
                  onTap: () {
                    setState(() => _statusFilter = 'RESOLVED');
                    _load();
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _items.isEmpty
              ? AppEmptyView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được dữ liệu',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                )
              : _items.isEmpty
              ? const AppEmptyView(
                  icon: Icons.support_agent_outlined,
                  title: 'Chưa có sự cố nào được phân công',
                  message:
                      'Các yêu cầu hỗ trợ Online hoặc xử lý sự cố hiện trường của bạn sẽ hiển thị tại đây.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) => _buildCard(_items[idx]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(TechnicianIncidentSummary it) {
    final (stLabel, stFg, stBg) = switch (it.status.toUpperCase()) {
      'REMOTE_SUPPORT' => ('Hỗ trợ Online', AppColors.info, AppColors.infoLight),
      'DISPATCHING' => (
        'Đang điều phối',
        AppColors.warning,
        AppColors.warningLight,
      ),
      'ON_SITE' => ('Đang xử lý tại chỗ', AppColors.primary, AppColors.primaryLight),
      'RETURN_REQUIRED' => (
        'Cần thu hồi về kho',
        AppColors.error,
        AppColors.errorLight,
      ),
      'RESOLVED' => ('Đã xử lý xong', AppColors.success, AppColors.successLight),
      _ => (it.status, AppColors.textSecondary, AppColors.surfaceSecondary),
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(it),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      it.incidentCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pill(stLabel, stFg, stBg),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                it.companyName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(
                    it.isOnSiteMode ? 'Trực tiếp hiện trường' : 'Hỗ trợ Online',
                    it.isOnSiteMode ? AppColors.primary : AppColors.info,
                    it.isOnSiteMode
                        ? AppColors.primaryLight
                        : AppColors.infoLight,
                  ),
                  if (it.isOnSiteMode)
                    _pill(
                      it.isLeader ? '⭐ KTV trưởng' : 'Thành viên',
                      it.isLeader ? AppColors.primary : AppColors.textSecondary,
                      it.isLeader
                          ? AppColors.primaryLight
                          : AppColors.surfaceSecondary,
                    ),
                  _pill(
                    '${it.itemCount} thiết bị',
                    AppColors.textPrimary,
                    AppColors.surfaceSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                it.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                it.scheduledStartAt != null
                    ? 'Lịch xuất phát: ${DateFormatter.dateTime(it.scheduledStartAt!)}'
                    : 'Báo sự cố lúc: ${DateFormatter.dateTime(it.reportedAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}
