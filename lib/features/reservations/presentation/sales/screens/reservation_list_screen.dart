import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/reservation.dart';
import '../../common/widgets/reservation_status_badge.dart';
import '../../providers/reservation_provider.dart';
import 'reservation_detail_screen.dart';

/// Danh sách phiếu giữ chỗ (tab "Đặt thuê" của Sales).
class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<ReservationProvider>().keyword,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final reservations = provider.filteredReservations;

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: provider.setKeyword,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã phiếu, khách hàng, người liên hệ...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.setKeyword('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppFilterChip(
                      label: 'Tất cả',
                      selected: provider.statusFilter == null,
                      onTap: () => provider.setStatusFilter(null),
                    ),
                    for (final status in ReservationStatus.filterable)
                      AppFilterChip(
                        label: status.label,
                        selected: provider.statusFilter == status,
                        onTap: () => provider.setStatusFilter(
                          provider.statusFilter == status ? null : status,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.load,
            child: _buildBody(provider, reservations),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    ReservationProvider provider,
    List<Reservation> reservations,
  ) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && !provider.hasLoaded) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: provider.errorMessage,
          action: FilledButton(
            onPressed: provider.load,
            child: const Text('Thử lại'),
          ),
        ),
      );
    }

    if (reservations.isEmpty) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.event_note_outlined,
          title: provider.reservations.isEmpty
              ? 'Chưa có phiếu đặt thuê'
              : 'Không có phiếu phù hợp',
          message: provider.reservations.isEmpty
              ? 'Bấm "Tạo đặt thuê" để lập phiếu giữ chỗ đầu tiên.'
              : 'Thử đổi từ khóa hoặc bộ lọc.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        96,
      ),
      itemCount: reservations.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${reservations.length} phiếu',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final reservation = reservations[index - 1];

        return _ReservationCard(
          reservation: reservation,
          onTap: () => ReservationDetailScreen.open(context, reservation.id),
        );
      },
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onTap});

  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final items = reservation.itemCount == 0
        ? 'Chưa có thiết bị'
        : '${reservation.itemCount} model · ${reservation.totalQuantity} thiết bị';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reservation.reservationCode,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ReservationStatusBadge(status: reservation.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.companyName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Meta(
                      icon: Icons.calendar_today_outlined,
                      text: DateFormatter.dateRange(
                        reservation.requestedFrom,
                        reservation.requestedTo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Meta(icon: Icons.inventory_2_outlined, text: items),
                    if (reservation.isOpen) ...[
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.timer_outlined,
                        text:
                            'Giữ chỗ đến ${DateFormatter.dateTime(reservation.expiresAt)}',
                        color: AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.textSecondary;

    return Row(
      children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: foreground),
          ),
        ),
      ],
    );
  }
}
