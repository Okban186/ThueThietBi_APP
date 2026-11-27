import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/features/returns/data/datasources/return_api.dart';
import 'package:thuethietbi_app/features/returns/presentation/storekeeper/screens/return_list_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/handover_api.dart';
import '../../../data/models/handover_preparation.dart';
import '../../common/widgets/handover_status_badge.dart';
import 'handover_contract_screen.dart';
import 'handover_detail_screen.dart';

/// Tab "Giao nhận" của thủ kho: hợp đồng cần soạn bàn giao, các phiếu bàn giao
/// và nhận trả máy kỹ thuật viên thu hồi về.
class HandoverHomeScreen extends StatefulWidget {
  const HandoverHomeScreen({
    super.key,
    required this.api,
    required this.returnApi,
  });

  final HandoverApi api;
  final ReturnApi returnApi;

  @override
  State<HandoverHomeScreen> createState() => HandoverHomeScreenState();
}

class HandoverHomeScreenState extends State<HandoverHomeScreen> {
  final _contractsKey = GlobalKey<_ContractsTabState>();
  final _notesKey = GlobalKey<_NotesTabState>();
  final _returnsKey = GlobalKey<ReturnListViewState>();

  /// Tải lại các danh sách (gọi khi chuyển sang tab).
  void reload() {
    _contractsKey.currentState?.reload();
    _notesKey.currentState?.reload();
    _returnsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const ColoredBox(
            color: AppColors.surface,
            child: TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Cần soạn'),
                Tab(text: 'Phiếu giao'),
                Tab(text: 'Nhận trả'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ContractsTab(
                  key: _contractsKey,
                  api: widget.api,
                  onChanged: reload,
                ),
                _NotesTab(key: _notesKey, api: widget.api, onChanged: reload),
                ReturnListView(key: _returnsKey, api: widget.returnApi),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ cần soạn

class _ContractsTab extends StatefulWidget {
  const _ContractsTab({super.key, required this.api, required this.onChanged});

  final HandoverApi api;
  final VoidCallback onChanged;

  @override
  State<_ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<_ContractsTab>
    with AutomaticKeepAliveClientMixin {
  List<PreparationContract> _contracts = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contracts = await widget.api.getContractsToPrepare();
      if (mounted) setState(() => _contracts = contracts);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được hợp đồng cần soạn.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(onRefresh: reload, child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading && _contracts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: _error,
          action: FilledButton(onPressed: reload, child: const Text('Thử lại')),
        ),
      );
    }

    if (_contracts.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'Không có hợp đồng cần soạn',
          message: 'Hợp đồng đã ký sẽ hiện ở đây để kho chuẩn bị thiết bị.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _contracts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final c = _contracts[index];

        return _ContractCard(
          contract: c,
          onTap: () async {
            await HandoverContractScreen.open(
              context,
              widget.api,
              c.contractId,
            );
            widget.onChanged();
          },
        );
      },
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.contract, required this.onTap});

  final PreparationContract contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    final progress = c.totalQuantity == 0
        ? 0.0
        : c.allocatedQuantity / c.totalQuantity;
    final done = c.remainingQuantity <= 0;

    return _Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.contractCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ContractStatusBadge(status: c.contractStatus),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${c.companyName} (${c.companyCode})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _IconText(
            icon: Icons.event_outlined,
            text: 'Bắt đầu thuê ${DateFormatter.date(c.startDate)}',
            color: _startColor(c.startDate),
          ),
          if (c.deliveryAddress != null)
            _IconText(
              icon: Icons.location_on_outlined,
              text: c.deliveryAddress!,
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 6,
                    color: done ? AppColors.success : AppColors.primary,
                    backgroundColor: AppColors.surfaceSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Đã xếp ${c.allocatedQuantity}/${c.totalQuantity} máy',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: done ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (c.hasPendingDefectiveReturn) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Chờ thu hồi xong phiếu ${c.pendingDefectiveReturnCode ?? ''} trước khi giao bù',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ] else if (c.hasBlockedIncidentReplacement) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c.blockedIncidentReplacementReason!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ] else if (c.hasReadyIncidentReplacement) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sẵn sàng soạn máy thay thế sự cố ${c.readyIncidentCode ?? ''} (${c.remainingQuantity} máy)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
            ),
          ] else if (c.contractStatus == RentalContractStatus.partiallyDelivered &&
              c.remainingQuantity > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sẵn sàng soạn phiếu giao bù (${c.remainingQuantity} máy)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hợp đồng sắp tới ngày thuê (≤ 2 ngày) tô cam để ưu tiên.
  static Color _startColor(DateTime start) {
    final today = DateUtils.dateOnly(DateTime.now());
    return start.difference(today).inDays <= 2
        ? AppColors.warning
        : AppColors.textSecondary;
  }
}

// ------------------------------------------------------------------ phiếu

class _NotesTab extends StatefulWidget {
  const _NotesTab({super.key, required this.api, required this.onChanged});

  final HandoverApi api;
  final VoidCallback onChanged;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab>
    with AutomaticKeepAliveClientMixin {
  List<HandoverSummary> _notes = [];
  bool _isLoading = true;
  String? _error;
  HandoverStatus? _filter;

  static const _filters = [
    HandoverStatus.preparing,
    HandoverStatus.pendingApproval,
    HandoverStatus.shipping,
    HandoverStatus.completed,
    HandoverStatus.cancelled,
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notes = await widget.api.getNotes();
      if (mounted) setState(() => _notes = notes);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được phiếu bàn giao.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visible = _filter == null
        ? _notes
        : _notes.where((n) => n.status == _filter).toList();

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppFilterChip(
                  label: 'Tất cả',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
              ),
              for (final status in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppFilterChip(
                    label: status.label,
                    selected: _filter == status,
                    onTap: () => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: reload,
            child: _buildBody(visible),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<HandoverSummary> visible) {
    if (_isLoading && _notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: _error,
          action: FilledButton(onPressed: reload, child: const Text('Thử lại')),
        ),
      );
    }

    if (visible.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.local_shipping_outlined,
          title: 'Chưa có phiếu bàn giao',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => HandoverNoteCard(
        note: visible[index],
        onTap: () async {
          await HandoverDetailScreen.open(
            context,
            widget.api,
            visible[index].id,
          );
          widget.onChanged();
        },
      ),
    );
  }
}

/// Thẻ phiếu bàn giao: mã, hợp đồng, ngày giao, số máy, trạng thái.
class HandoverNoteCard extends StatelessWidget {
  const HandoverNoteCard({super.key, required this.note, required this.onTap});

  final HandoverSummary note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        note.handoverCode,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (note.isSupplementary || note.isIncidentReplacement) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: note.isIncidentReplacement
                              ? AppColors.infoLight
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          note.isIncidentReplacement ? 'Đổi sự cố' : 'Giao bù',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: note.isIncidentReplacement
                                ? AppColors.info
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              HandoverStatusBadge(status: note.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${note.contractCode} · ${note.companyName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _IconText(
                  icon: Icons.local_shipping_outlined,
                  text: 'Giao ${DateFormatter.date(note.handoverDate)}',
                ),
              ),
              Text(
                '${note.itemCount} máy',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          _IconText(
            icon: Icons.person_outline_rounded,
            text: 'Người nhận: ${note.receivedByName}',
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: note.isClaimed
                  ? AppColors.primaryLight
                  : AppColors.warningLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              note.isClaimed
                  ? 'Phụ trách: ${note.assignedStorekeeperName ?? 'Tôi'}'
                  : 'Chưa ai tiếp nhận — Chạm để nhận soạn',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: note.isClaimed ? AppColors.primary : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: child,
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c),
            ),
          ),
        ],
      ),
    );
  }
}
