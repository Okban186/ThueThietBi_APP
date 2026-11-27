import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_client.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/equipment/data/datasources/storekeeper_equipment_api.dart';
import 'package:thuethietbi_app/features/equipment/data/models/equipment_history.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';

/// Màn hình xem toàn bộ lịch sử vòng đời của 1 thiết bị vật lý:
/// - Tổng chi phí bảo trì / sửa chữa (nhân công + linh kiện) so với giá mua ban đầu.
/// - Tab 1: Nhật ký sửa chữa & danh sách linh kiện đã thay thế (kèm ảnh phóng to).
/// - Tab 2: Lịch sử sự cố & nguyên nhân lỗi.
/// - Tab 3: Lịch sử cho thuê & bàn giao.
class EquipmentHistoryScreen extends StatefulWidget {
  const EquipmentHistoryScreen({
    super.key,
    required this.api,
    required this.equipmentId,
    this.serialHint,
    this.onEditTap,
  });

  final StorekeeperEquipmentApi api;
  final String equipmentId;
  final String? serialHint;
  final VoidCallback? onEditTap;

  static Future<void> open(
    BuildContext context, {
    required StorekeeperEquipmentApi api,
    required String equipmentId,
    String? serialHint,
    VoidCallback? onEditTap,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EquipmentHistoryScreen(
          api: api,
          equipmentId: equipmentId,
          serialHint: serialHint,
          onEditTap: onEditTap,
        ),
      ),
    );
  }

  static Future<void> openWithClient(
    BuildContext context, {
    required ApiClient apiClient,
    required String equipmentId,
    String? serialHint,
  }) {
    return open(
      context,
      api: StorekeeperEquipmentApi(apiClient),
      equipmentId: equipmentId,
      serialHint: serialHint,
    );
  }

  @override
  State<EquipmentHistoryScreen> createState() => _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  EquipmentLifecycleHistory? _history;
  bool _loading = true;
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
      final data = await widget.api.getEquipmentHistory(widget.equipmentId);
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được lịch sử thiết bị.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _history;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            h?.serialNumber ?? widget.serialHint ?? 'Lịch sử thiết bị',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (widget.onEditTap != null)
              IconButton(
                tooltip: 'Chỉnh sửa thiết bị',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  widget.onEditTap!();
                },
              ),
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        body: _loading && h == null
            ? const Center(child: CircularProgressIndicator())
            : h == null
            ? AppEmptyView(
                icon: Icons.cloud_off_rounded,
                title: 'Không tải được dữ liệu',
                message: _error,
                action: FilledButton(
                  onPressed: _load,
                  child: const Text('Thử lại'),
                ),
              )
            : NestedScrollView(
                headerSliverBuilder: (_, __) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildSummaryHeader(h),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        tabs: [
                          Tab(
                            text:
                                'Bảo trì (${h.maintenanceHistory.length})',
                          ),
                          Tab(
                            text: 'Sự cố (${h.incidentHistory.length})',
                          ),
                          Tab(
                            text: 'Cho thuê (${h.rentalHistory.length})',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _buildMaintenanceTab(h),
                    _buildIncidentsTab(h),
                    _buildRentalsTab(h),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryHeader(EquipmentLifecycleHistory h) {
    final (stFg, stBg) = switch (h.status.toUpperCase()) {
      'AVAILABLE' => (AppColors.success, AppColors.successLight),
      'DAMAGED' || 'LOST' || 'DISPOSED' => (AppColors.error, AppColors.errorLight),
      'RENTED' => (AppColors.info, AppColors.infoLight),
      _ => (AppColors.warning, AppColors.warningLight),
    };
    final highCostWarning = (h.repairToAcquisitionPercent ?? 0) >= 50.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.serialNumber,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${h.modelName} (${h.modelCode})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(h.status, stFg, stBg),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(
                'Kho: ${h.warehouseName}',
                AppColors.textPrimary,
                AppColors.surfaceSecondary,
              ),
              _pill(
                'Tình trạng: ${h.condition}',
                AppColors.info,
                AppColors.infoLight,
              ),
              if (h.acquiredAt != null)
                _pill(
                  'Nhập: ${DateFormatter.date(h.acquiredAt!)}',
                  AppColors.textSecondary,
                  AppColors.surfaceSecondary,
                ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  'Lượt thuê',
                  '${h.totalRentalsCount}',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  'Lần bảo trì',
                  '${h.totalMaintenanceCount}',
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  'Sự cố',
                  '${h.totalIncidentsCount}',
                  AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highCostWarning
                  ? AppColors.errorLight
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highCostWarning
                    ? AppColors.error.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tổng chi phí sửa chữa tích lũy',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.vnd(h.totalMaintenanceCost),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: highCostWarning
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhân công: ${CurrencyFormatter.vnd(h.totalLaborCost)} • Linh kiện: ${CurrencyFormatter.vnd(h.totalPartsCost)}'
                  '${h.acquisitionCost != null ? ' • Giá mua: ${CurrencyFormatter.vnd(h.acquisitionCost!)}' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (h.repairToAcquisitionPercent != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (h.repairToAcquisitionPercent! / 100.0).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 6,
                      color: highCostWarning
                          ? AppColors.error
                          : AppColors.primary,
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    highCostWarning
                        ? 'Cảnh báo: Chi phí sửa chữa đã bằng ${h.repairToAcquisitionPercent!.toStringAsFixed(1)}% giá mua — nên cân nhắc thanh lý!'
                        : 'Tỷ lệ sửa chữa / giá mua: ${h.repairToAcquisitionPercent!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: highCostWarning
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab(EquipmentLifecycleHistory h) {
    if (h.maintenanceHistory.isEmpty) {
      return const AppEmptyView(
        icon: Icons.build_circle_outlined,
        title: 'Chưa có lịch sử sửa chữa / bảo trì',
        message:
            'Mọi đợt kiểm tra, bảo dưỡng và linh kiện đã thay cho thiết bị này sẽ được lưu đầy đủ tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: h.maintenanceHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, idx) {
          final m = h.maintenanceHistory[idx];
          final (stLabel, stFg, stBg) = switch (m.status.toUpperCase()) {
            'COMPLETED' => ('Hoàn tất', AppColors.success, AppColors.successLight),
            'IN_PROGRESS' => ('Đang xử lý', AppColors.info, AppColors.infoLight),
            'CANCELLED' => ('Đã hủy', AppColors.error, AppColors.errorLight),
            _ => ('Chờ xử lý', AppColors.warning, AppColors.warningLight),
          };

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
                        m.typeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    _pill(stLabel, stFg, stBg),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tạo lúc: ${DateFormatter.dateTime(m.createdAt)}'
                  '${m.completedAt != null ? ' • Xong: ${DateFormatter.dateTime(m.completedAt!)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (m.assignedTechnicianName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'KTV phụ trách: ${m.assignedTechnicianName!}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(m.description, style: const TextStyle(fontSize: 13)),
                if (m.result != null && m.result!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Kết luận: ${m.result!}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
                if (m.totalCost > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Chi phí đợt này: ${CurrencyFormatter.vnd(m.totalCost)} (Công: ${CurrencyFormatter.vnd(m.totalLaborCost)} • Linh kiện: ${CurrencyFormatter.vnd(m.totalPartsCost)})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                for (final rec in m.records) ...[
                  const SizedBox(height: 8),
                  Container(
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
                                'KTV thực hiện: ${rec.performedByName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (rec.completedAt != null)
                              Text(
                                DateFormatter.date(rec.completedAt!),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.description,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        if (rec.parts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Linh kiện đã thay thế:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final p in rec.parts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.settings_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${p.name} (SL: ${p.quantity == p.quantity.roundToDouble() ? p.quantity.toInt() : p.quantity} × ${CurrencyFormatter.vnd(p.unitCost)})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.vnd(p.totalCost),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (m.attachmentUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  MediaViewerGallery(
                    thumbSize: 72,
                    items: [
                      for (var i = 0; i < m.attachmentUrls.length; i++)
                        GalleryMediaItem(
                          url: m.attachmentUrls[i],
                          fileName: 'Ảnh bảo trì #${i + 1}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncidentsTab(EquipmentLifecycleHistory h) {
    if (h.incidentHistory.isEmpty) {
      return const AppEmptyView(
        icon: Icons.support_agent_outlined,
        title: 'Chưa có lịch sử sự cố',
        message: 'Thiết bị này chưa ghi nhận báo cáo sự cố nào từ khách hàng.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: h.incidentHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, idx) {
          final inc = h.incidentHistory[idx];
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
                        '${inc.incidentCode} • ${inc.companyName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _pill(
                      inc.status,
                      inc.status == 'RESOLVED'
                          ? AppColors.success
                          : AppColors.warning,
                      inc.status == 'RESOLVED'
                          ? AppColors.successLight
                          : AppColors.warningLight,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Báo lúc: ${DateFormatter.dateTime(inc.reportedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (inc.faultLabel != null) ...[
                  const SizedBox(height: 6),
                  _pill(
                    inc.faultLabel!,
                    inc.faultType == 'CUSTOMER_FAULT'
                        ? AppColors.error
                        : AppColors.info,
                    inc.faultType == 'CUSTOMER_FAULT'
                        ? AppColors.errorLight
                        : AppColors.infoLight,
                  ),
                ],
                const SizedBox(height: 6),
                Text(inc.description, style: const TextStyle(fontSize: 13)),
                if (inc.assessment != null &&
                    inc.assessment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Đánh giá KTV: ${inc.assessment!}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (inc.chargeAmount != null && inc.chargeAmount! > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Khoản phạt/bồi thường: ${CurrencyFormatter.vnd(inc.chargeAmount!)} (${inc.chargeStatus ?? ''})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRentalsTab(EquipmentLifecycleHistory h) {
    if (h.rentalHistory.isEmpty) {
      return const AppEmptyView(
        icon: Icons.assignment_outlined,
        title: 'Chưa có lịch sử bàn giao cho thuê',
        message: 'Thiết bị này chưa được xuất bàn giao cho hợp đồng nào.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: h.rentalHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, idx) {
          final r = h.rentalHistory[idx];
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
                        '${r.contractCode} • ${r.companyName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _pill(
                      r.handoverTypeLabel,
                      AppColors.primary,
                      AppColors.primaryLight,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Thời gian HĐ: ${DateFormatter.dateRange(r.startDate, r.endDate)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Phiếu ${r.handoverCode} • Giao ${DateFormatter.date(r.handoverDate)} (${r.handoverStatus})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
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

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabHeaderDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}
