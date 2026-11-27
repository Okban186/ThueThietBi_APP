import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/payment_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../data/datasources/technician_api.dart';
import '../../data/models/technician_models.dart';
import 'technician_trip_detail_screen.dart';

/// Danh sách chuyến giao hàng được phân công cho Kỹ thuật viên.
class TechnicianTripListScreen extends StatefulWidget {
  const TechnicianTripListScreen({
    super.key,
    required this.api,
    required this.paymentApi,
    required this.reloadVersion,
    required this.onChanged,
  });

  final TechnicianApi api;
  final PaymentApi paymentApi;
  final int reloadVersion;
  final VoidCallback onChanged;

  @override
  State<TechnicianTripListScreen> createState() =>
      _TechnicianTripListScreenState();
}

class _TechnicianTripListScreenState extends State<TechnicianTripListScreen> {
  List<TechnicianAssignmentSummary> _trips = const [];
  String? _statusFilter; // null = Tất cả
  String? _typeFilter; // null = Tất cả (Giao lắp + Thu hồi), HANDOVER, RETRIEVAL
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TechnicianTripListScreen oldWidget) {
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
      final list = await widget.api.getAssignments(
        status: _statusFilter,
        type: _typeFilter,
      );
      final filtered = list
          .where((t) => t.type.toUpperCase() == 'HANDOVER' || t.isRetrieval)
          .toList();
      if (mounted) setState(() => _trips = filtered);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được danh sách chuyến giao.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(TechnicianAssignmentSummary trip) async {
    final changed = await TechnicianTripDetailScreen.open(
      context,
      api: widget.api,
      paymentApi: widget.paymentApi,
      assignmentId: trip.assignmentId,
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
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppFilterChip(
                      label: 'Mọi loại chuyến',
                      selected: _typeFilter == null,
                      onTap: () {
                        setState(() => _typeFilter = null);
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Giao lắp',
                      selected: _typeFilter == 'HANDOVER',
                      onTap: () {
                        setState(() => _typeFilter = 'HANDOVER');
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Thu hồi cuối kỳ',
                      selected: _typeFilter == 'RETRIEVAL',
                      onTap: () {
                        setState(() => _typeFilter = 'RETRIEVAL');
                        _load();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppFilterChip(
                      label: 'Tất cả trạng thái',
                      selected: _statusFilter == null,
                      onTap: () {
                        setState(() => _statusFilter = null);
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Đang thực hiện',
                      selected: _statusFilter == 'IN_PROGRESS',
                      onTap: () {
                        setState(() => _statusFilter = 'IN_PROGRESS');
                        _load();
                      },
                    ),
                    AppFilterChip(
                      label: 'Chờ xuất phát',
                      selected: _statusFilter == 'PENDING',
                      onTap: () {
                        setState(() => _statusFilter = 'PENDING');
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
          child: _loading && _trips.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _trips.isEmpty
              ? AppEmptyView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được dữ liệu',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                )
              : _trips.isEmpty
              ? const AppEmptyView(
                  icon: Icons.local_shipping_outlined,
                  title: 'Chưa có chuyến giao nào',
                  message:
                      'Các chuyến giao lắp do Quản lý điều phối cho bạn sẽ hiển thị tại đây.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) => _buildTripCard(_trips[idx]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTripCard(TechnicianAssignmentSummary trip) {
    final (stLabel, stFg, stBg) = switch (trip.status.toUpperCase()) {
      'IN_PROGRESS' => (
        trip.isRetrieval ? 'Đang đi thu hồi' : 'Đang đi giao',
        AppColors.info,
        AppColors.infoLight,
      ),
      'COMPLETED' => ('Hoàn tất', AppColors.success, AppColors.successLight),
      'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
      _ => ('Chờ xuất phát', AppColors.warning, AppColors.warningLight),
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(trip),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pill(stLabel, stFg, stBg),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(
                    trip.isRetrieval ? 'Thu hồi' : 'Giao lắp',
                    trip.isRetrieval ? AppColors.warning : AppColors.info,
                    trip.isRetrieval ? AppColors.warningLight : AppColors.infoLight,
                  ),
                  _pill(
                    trip.isLeader ? '⭐ KTV trưởng' : 'Thành viên',
                    trip.isLeader ? AppColors.primary : AppColors.textSecondary,
                    trip.isLeader
                        ? AppColors.primaryLight
                        : AppColors.surfaceSecondary,
                  ),
                  _pill(
                    '${trip.completedStopCount}/${trip.stopCount} điểm hoàn tất',
                    AppColors.textPrimary,
                    AppColors.surfaceSecondary,
                  ),
                  if (trip.estimatedDurationMinutes != null)
                    _pill(
                      '~${trip.estimatedDurationMinutes} phút',
                      AppColors.textSecondary,
                      AppColors.surfaceSecondary,
                    ),
                ],
              ),
              if (trip.scheduledStartAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Xuất phát: ${DateFormatter.dateTime(trip.scheduledStartAt!)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (trip.stops.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final s in trip.stops.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• Chặng #${s.stopOrder}: ${s.companyName} (${s.itemCount} máy)${s.isSupplementary ? ' [Giao bù]' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                if (trip.stops.length > 2)
                  Text(
                    '+ ${trip.stops.length - 2} điểm dừng khác...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
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
