import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'create_delivery_trip_screen.dart';

/// Màn hình Quản lý & Tạo lịch giao bù hàng (hợp đồng PARTIALLY_DELIVERED):
/// - Tách bạch rõ 3 nhóm:
///   1. Sẵn sàng tạo lịch giao bù (Kho đã kiểm nhận xong phiếu thu hồi máy lỗi) -> nút 1 chạm "Tạo lịch giao bù".
///   2. Đang chờ Kho thu hồi máy lỗi (khóa không cho tạo lịch giao bù cho tới khi Kho xác nhận phiếu TH-...).
///   3. Đã xếp lịch giao bù.
class ManagerSupplementaryScreen extends StatefulWidget {
  const ManagerSupplementaryScreen({
    super.key,
    required this.managerApi,
    required this.contractApi,
  });

  final ManagerApi managerApi;
  final RentalContractApi contractApi;

  static Future<bool?> open(
    BuildContext context, {
    required ManagerApi managerApi,
    required RentalContractApi contractApi,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManagerSupplementaryScreen(
          managerApi: managerApi,
          contractApi: contractApi,
        ),
      ),
    );
  }

  @override
  State<ManagerSupplementaryScreen> createState() =>
      _ManagerSupplementaryScreenState();
}

class _ManagerSupplementaryScreenState
    extends State<ManagerSupplementaryScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
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
      final list = await widget.managerApi.getSupplementaryOverview();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Không tải được danh sách giao bù.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scheduleSupplementary(String contractId) async {
    final ok = await CreateDeliveryTripScreen.open(
      context,
      managerApi: widget.managerApi,
      contractApi: widget.contractApi,
      preselectedContractId: contractId,
    );
    if (ok == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _items.where((e) => e['canScheduleNow'] == true).toList();
    final waitingReturn =
        _items.where((e) => e['isWaitingDefectiveReturn'] == true).toList();
    final scheduled = _items
        .where(
          (e) =>
              e['canScheduleNow'] != true &&
              e['isWaitingDefectiveReturn'] != true,
        )
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Quản lý giao bù hàng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading && _items.isEmpty
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
                icon: Icons.local_shipping_outlined,
                title: 'Không có đơn nào cần giao bù',
                message:
                    'Khi đợt giao có máy lỗi, hợp đồng sẽ xuất hiện tại đây để theo dõi thu hồi và tạo lịch giao bù miễn phí ship.',
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (ready.isNotEmpty) ...[
                      _sectionTitle(
                        'Sẵn sàng tạo lịch giao bù (${ready.length})',
                        AppColors.success,
                      ),
                      const SizedBox(height: 8),
                      for (final it in ready) _buildCard(it),
                      const SizedBox(height: 14),
                    ],
                    if (waitingReturn.isNotEmpty) ...[
                      _sectionTitle(
                        'Đang chờ Kho thu hồi máy lỗi (${waitingReturn.length})',
                        AppColors.warning,
                      ),
                      const SizedBox(height: 8),
                      for (final it in waitingReturn) _buildCard(it),
                      const SizedBox(height: 14),
                    ],
                    if (scheduled.isNotEmpty) ...[
                      _sectionTitle(
                        'Đã xếp lịch giao bù (${scheduled.length})',
                        AppColors.info,
                      ),
                      const SizedBox(height: 8),
                      for (final it in scheduled) _buildCard(it),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );

  Widget _buildCard(Map<String, dynamic> it) {
    final contractId = it['contractId'] as String;
    final contractCode = it['contractCode'] as String? ?? '';
    final companyName = it['companyName'] as String? ?? '';
    final address = it['deliveryAddress'] as String?;
    final total = (it['totalQuantity'] as num?)?.toInt() ?? 0;
    final good = (it['deliveredGoodQuantity'] as num?)?.toInt() ?? 0;
    final missing = (it['missingQuantity'] as num?)?.toInt() ?? 0;
    final waitingReturn = it['isWaitingDefectiveReturn'] == true;
    final pendingRetCode = it['pendingDefectiveReturnCode'] as String?;
    final suppCode = it['existingSupplementaryHandoverCode'] as String?;
    final suppStatus = it['existingSupplementaryStatus'] as String?;
    final canSchedule = it['canScheduleNow'] == true;
    final alreadyScheduled = it['isAlreadyScheduled'] == true;
    final startDate = it['startDate'] != null
        ? DateTime.parse(it['startDate'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canSchedule
              ? AppColors.success.withValues(alpha: 0.45)
              : waitingReturn
              ? AppColors.warning.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$contractCode • $companyName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: canSchedule
                      ? AppColors.successLight
                      : waitingReturn
                      ? AppColors.warningLight
                      : AppColors.infoLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  canSchedule
                      ? 'Sẵn sàng giao bù'
                      : waitingReturn
                      ? 'Chờ thu hồi'
                      : 'Đã xếp lịch',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: canSchedule
                        ? AppColors.success
                        : waitingReturn
                        ? AppColors.warning
                        : AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tiến độ giao đạt: $good/$total máy • Cần giao bù: $missing máy'
            '${startDate != null ? ' • Bắt đầu thuê: ${DateFormatter.date(startDate)}' : ''}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (address != null && address.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Địa chỉ: $address',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (suppCode != null) ...[
            const SizedBox(height: 4),
            Text(
              'Phiếu giao bù: $suppCode (${suppStatus ?? ''})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (waitingReturn)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Bắt buộc Kho hoàn tất kiểm nhận phiếu thu hồi máy lỗi ${pendingRetCode ?? ''} trước khi tạo lịch giao bù.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (canSchedule)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () => _scheduleSupplementary(contractId),
                icon: const Icon(Icons.add_road_rounded, size: 18),
                label: Text('Tạo lịch giao bù ($missing máy • miễn phí ship)'),
              ),
            )
          else if (alreadyScheduled)
            const Text(
              'Đơn giao bù này đã được gắn vào lịch trình chuyến giao.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
