import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/contract_status_history.dart';
import '../../../data/models/rental_contract.dart';
import 'contract_status_badge.dart';

/// Timeline dọc hiển thị lịch sử trạng thái hợp đồng.
/// Dùng chung giữa các màn hình Sales, Manager và Khách hàng (COMPANY)
/// để đồng bộ màu sắc, icon, đường nối và chip chuyển trạng thái.
class ContractStatusTimeline extends StatelessWidget {
  const ContractStatusTimeline({
    super.key,
    required this.history,
    this.newestFirst = true,
    this.showActor = true,
  });

  final List<ContractStatusHistory> history;
  final bool newestFirst;
  final bool showActor;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Text(
        'Chưa có lịch sử trạng thái.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    final items = newestFirst ? history.reversed.toList() : history;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineItem(
            entry: items[i],
            isFirst: i == 0,
            isLast: i == items.length - 1,
            showActor: showActor,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.showActor,
  });

  final ContractStatusHistory entry;
  final bool isFirst;
  final bool isLast;
  final bool showActor;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = _styleFor(entry.status);
    final hasTransition = entry.previousStatus != entry.status;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isFirst ? fg : bg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fg.withValues(alpha: isFirst ? 1 : 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isFirst ? Colors.white : fg,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppColors.surfaceSecondary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                  border: Border.all(
                    color: isFirst
                        ? fg.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasTransition)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ContractStatusBadge(status: entry.previousStatus),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          ContractStatusBadge(status: entry.status),
                        ],
                      )
                    else
                      ContractStatusBadge(status: entry.status),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13.5,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            showActor &&
                                    (entry.changedByName?.trim().isNotEmpty ??
                                        false)
                                ? '${DateFormatter.dateTime(entry.changedAt)} · ${entry.changedByName}'
                                : DateFormatter.dateTime(entry.changedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.note != null &&
                        entry.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.note!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, IconData) _styleFor(RentalContractStatus status) =>
      switch (status) {
        RentalContractStatus.draft => (
          AppColors.textSecondary,
          AppColors.surfaceSecondary,
          Icons.edit_note_rounded,
        ),
        RentalContractStatus.pendingApproval => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.hourglass_top_rounded,
        ),
        RentalContractStatus.rejected => (
          AppColors.error,
          AppColors.errorLight,
          Icons.close_rounded,
        ),
        RentalContractStatus.pendingSignature => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.draw_outlined,
        ),
        RentalContractStatus.signed => (
          AppColors.success,
          AppColors.successLight,
          Icons.verified_rounded,
        ),
        RentalContractStatus.preparing => (
          AppColors.info,
          AppColors.infoLight,
          Icons.inventory_2_outlined,
        ),
        RentalContractStatus.partiallyDelivered => (
          AppColors.info,
          AppColors.infoLight,
          Icons.local_shipping_outlined,
        ),
        RentalContractStatus.delivered => (
          AppColors.info,
          AppColors.infoLight,
          Icons.local_shipping_rounded,
        ),
        RentalContractStatus.completed => (
          AppColors.success,
          AppColors.successLight,
          Icons.task_alt_rounded,
        ),
        RentalContractStatus.expired => (
          AppColors.error,
          AppColors.errorLight,
          Icons.event_busy_rounded,
        ),
        RentalContractStatus.cancellationRequested => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.pending_actions_rounded,
        ),
        RentalContractStatus.cancelled => (
          AppColors.error,
          AppColors.errorLight,
          Icons.cancel_outlined,
        ),
      };
}
