import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/features/dashboard/data/datasources/customer_portal_api.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/rental_contract.dart';
import '../../common/widgets/contract_status_badge.dart';
import 'customer_contract_detail_screen.dart';

/// Nhóm lọc hợp đồng của khách hàng.
enum _ContractFilter {
  all('Tất cả'),
  active('Đang thuê'),
  pendingSignature('Chờ ký'),
  finished('Đã kết thúc');

  const _ContractFilter(this.label);

  final String label;

  bool matches(RentalContractStatus status) => switch (this) {
    all => true,
    active => const {
      RentalContractStatus.signed,
      RentalContractStatus.pendingDeposit,
      RentalContractStatus.preparing,
      RentalContractStatus.partiallyDelivered,
      RentalContractStatus.delivered,
      RentalContractStatus.cancellationRequested,
    }.contains(status),
    pendingSignature => status == RentalContractStatus.pendingSignature,
    finished => const {
      RentalContractStatus.completed,
      RentalContractStatus.expired,
      RentalContractStatus.cancelled,
    }.contains(status),
  };
}

/// Danh sách hợp đồng của công ty khách hàng (chỉ xem).
class CustomerContractListScreen extends StatefulWidget {
  const CustomerContractListScreen({super.key, required this.api});

  final CustomerPortalApi api;

  @override
  State<CustomerContractListScreen> createState() =>
      CustomerContractListScreenState();
}

class CustomerContractListScreenState
    extends State<CustomerContractListScreen> {
  List<RentalContract> _contracts = [];
  bool _isLoading = true;
  String? _error;
  _ContractFilter _filter = _ContractFilter.all;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Tải lại danh sách (gọi từ layout khi chuyển sang tab).
  Future<void> reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contracts = await widget.api.getContracts();
      if (mounted) setState(() => _contracts = contracts);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được danh sách hợp đồng.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _contracts.where((c) => _filter.matches(c.status)).toList();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            children: [
              for (final filter in _ContractFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppFilterChip(
                    label: filter.label,
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter),
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

  Widget _buildBody(List<RentalContract> visible) {
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

    if (visible.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.description_outlined,
          title: 'Chưa có hợp đồng',
          message: 'Hợp đồng hiển thị ở đây sau khi được bên cho thuê duyệt và gửi để ký.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final contract = visible[index];

        return CustomerContractCard(
          contract: contract,
          onTap: () async {
            await CustomerContractDetailScreen.open(
              context,
              widget.api,
              contract.id,
            );
            reload();
          },
        );
      },
    );
  }
}

/// Thẻ hợp đồng: mã, thời gian, trạng thái, số máy, tổng tiền.
class CustomerContractCard extends StatelessWidget {
  const CustomerContractCard({
    super.key,
    required this.contract,
    required this.onTap,
  });

  final RentalContract contract;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contract.contractCode,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ContractStatusBadge(status: contract.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IconText(
                      icon: Icons.calendar_today_outlined,
                      text:
                          '${DateFormatter.dateRange(contract.startDate, contract.endDate)} (${contract.rentalDays} ngày)',
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _IconText(
                            icon: Icons.inventory_2_outlined,
                            text:
                                '${contract.totalQuantity} máy · ${contract.rentalType.label}',
                          ),
                        ),
                        Text(
                          CurrencyFormatter.vnd(contract.contractTotalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
