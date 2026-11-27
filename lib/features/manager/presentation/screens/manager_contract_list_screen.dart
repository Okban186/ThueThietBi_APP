import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_contract.dart';
import 'package:thuethietbi_app/features/contracts/presentation/common/widgets/contract_status_badge.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'manager_contract_detail_screen.dart';

class ManagerContractListScreen extends StatefulWidget {
  const ManagerContractListScreen({
    super.key,
    required this.contractApi,
    required this.managerApi,
    required this.reloadVersion,
    required this.onChanged,
  });

  final RentalContractApi contractApi;
  final ManagerApi managerApi;
  final int reloadVersion;
  final VoidCallback onChanged;

  @override
  State<ManagerContractListScreen> createState() =>
      _ManagerContractListScreenState();
}

class _ManagerContractListScreenState extends State<ManagerContractListScreen> {
  final _searchCtrl = TextEditingController();
  List<RentalContract> _all = const [];
  RentalContractStatus? _statusFilter;
  String _keyword = '';
  bool _loading = true;
  String? _error;

  static const _filters = <(RentalContractStatus?, String)>[
    (null, 'Tất cả'),
    (RentalContractStatus.pendingApproval, 'Chờ duyệt'),
    (RentalContractStatus.signed, 'Chờ duyệt bản ký'),
    (RentalContractStatus.pendingDeposit, 'Chờ đặt cọc'),
    (RentalContractStatus.preparing, 'Đang chuẩn bị'),
    (RentalContractStatus.cancellationRequested, 'Chờ duyệt hủy'),
    (RentalContractStatus.pendingSignature, 'Chờ ký'),
    (RentalContractStatus.delivered, 'Đã giao'),
    (RentalContractStatus.cancelled, 'Đã hủy'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ManagerContractListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.contractApi.getContracts();
      if (mounted) setState(() => _all = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RentalContract> get _filtered {
    final q = _keyword.trim().toLowerCase();
    return _all.where((c) {
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return c.contractCode.toLowerCase().contains(q) ||
          (c.companyName ?? '').toLowerCase().contains(q) ||
          (c.companyCode ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

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
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _keyword = v),
                decoration: InputDecoration(
                  hintText: 'Tìm mã hợp đồng hoặc tên công ty...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _keyword = '');
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
                    for (final (st, label) in _filters)
                      AppFilterChip(
                        label: label,
                        selected: _statusFilter == st,
                        onTap: () => setState(() => _statusFilter = st),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AppEmptyView(
                        icon: Icons.error_outline_rounded,
                        title: 'Không tải được hợp đồng',
                        message: _error,
                        action: FilledButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      )
                    : items.isEmpty
                        ? const AppEmptyView(
                            icon: Icons.description_outlined,
                            title: 'Chưa có hợp đồng phù hợp',
                            message:
                                'Các hợp đồng chờ duyệt và hợp đồng bạn phụ trách sẽ hiện tại đây.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final c = items[i];
                              return _ContractCard(
                                contract: c,
                                onTap: () async {
                                  final changed =
                                      await ManagerContractDetailScreen.open(
                                    ctx,
                                    contractId: c.id,
                                    contractApi: widget.contractApi,
                                    managerApi: widget.managerApi,
                                  );
                                  if (changed == true && mounted) {
                                    _load();
                                    widget.onChanged();
                                  }
                                },
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.contract, required this.onTap});

  final RentalContract contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract.contractCode,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          contract.companyName ?? contract.companyCode ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ContractStatusBadge(status: contract.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    DateFormatter.dateRange(
                      contract.startDate,
                      contract.endDate,
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.vnd(contract.contractTotalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${contract.itemCount} dòng • ${contract.totalQuantity} thiết bị • Sales: ${contract.createdByName ?? '---'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
