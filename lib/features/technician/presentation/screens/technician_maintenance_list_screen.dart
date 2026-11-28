import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/datasources/technician_maintenance_api.dart';
import '../../data/models/technician_maintenance_models.dart';
import 'technician_maintenance_detail_screen.dart';

/// Danh sách phiếu kiểm tra / bảo trì thiết bị tại kho cho Kỹ thuật viên.
class TechnicianMaintenanceListScreen extends StatefulWidget {
  const TechnicianMaintenanceListScreen({
    super.key,
    required this.maintenanceApi,
    required this.technicianApi,
    required this.reloadVersion,
    required this.onChanged,
  });

  final TechnicianMaintenanceApi maintenanceApi;
  final TechnicianApi technicianApi;
  final int reloadVersion;
  final VoidCallback onChanged;

  @override
  State<TechnicianMaintenanceListScreen> createState() =>
      _TechnicianMaintenanceListScreenState();
}

class _TechnicianMaintenanceListScreenState
    extends State<TechnicianMaintenanceListScreen> {
  final _searchCtrl = TextEditingController();
  List<MaintenanceTaskSummary> _tasks = const [];
  String? _statusFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TechnicianMaintenanceListScreen oldWidget) {
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
      final list = await widget.maintenanceApi.getTasks(
        status: _statusFilter,
        keyword: _searchCtrl.text,
      );
      if (mounted) setState(() => _tasks = list);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được danh sách phiếu bảo trì.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(MaintenanceTaskSummary task) async {
    final changed = await TechnicianMaintenanceDetailScreen.open(
      context,
      maintenanceApi: widget.maintenanceApi,
      technicianApi: widget.technicianApi,
      taskId: task.id,
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Tìm theo serial, mã/tên model, mô tả...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
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
                      label: 'Chờ xử lý',
                      selected: _statusFilter == 'PENDING',
                      onTap: () {
                        setState(() => _statusFilter = 'PENDING');
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Đang bảo trì',
                      selected: _statusFilter == 'IN_PROGRESS',
                      onTap: () {
                        setState(() => _statusFilter = 'IN_PROGRESS');
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Hoàn tất',
                      selected: _statusFilter == 'COMPLETED',
                      onTap: () {
                        setState(() => _statusFilter = 'COMPLETED');
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading && _tasks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _tasks.isEmpty
              ? AppEmptyView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được dữ liệu',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                )
              : _tasks.isEmpty
              ? const AppEmptyView(
                  icon: Icons.build_circle_outlined,
                  title: 'Chưa có phiếu bảo trì nào',
                  message:
                      'Các máy lỗi thu hồi về kho hoặc máy cần kiểm tra bảo dưỡng sẽ hiển thị tại đây.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) => _buildTaskCard(_tasks[idx]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(MaintenanceTaskSummary t) {
    final (stLabel, stFg, stBg) = switch (t.status.toUpperCase()) {
      'IN_PROGRESS' => ('Đang bảo trì', AppColors.info, AppColors.infoLight),
      'COMPLETED' => ('Hoàn tất', AppColors.success, AppColors.successLight),
      'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
      _ => ('Chờ xử lý', AppColors.warning, AppColors.warningLight),
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(t),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.serialNumber,
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
                '${t.modelName} (${t.modelCode})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(
                    t.typeLabel,
                    AppColors.primary,
                    AppColors.primaryLight,
                  ),
                  _pill(
                    t.warehouseName,
                    AppColors.textSecondary,
                    AppColors.surfaceSecondary,
                  ),
                  if (t.canComplete)
                    _pill(
                      t.isClaimed
                          ? 'Phụ trách: ${t.assignedTechnicianName ?? 'Tôi'}'
                          : 'Chưa ai nhận — Chạm để tiếp nhận',
                      t.isClaimed ? AppColors.primary : AppColors.warning,
                      t.isClaimed
                          ? AppColors.primaryLight
                          : AppColors.warningLight,
                    ),
                  if (t.attachmentCount > 0)
                    _pill(
                      '${t.attachmentCount} ảnh',
                      AppColors.textSecondary,
                      AppColors.surfaceSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tạo lúc: ${DateFormatter.dateTime(t.createdAt)}',
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
