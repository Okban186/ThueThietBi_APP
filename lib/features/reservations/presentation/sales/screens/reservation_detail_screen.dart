import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/contracts/presentation/providers/rental_contract_provider.dart';
import 'package:thuethietbi_app/features/contracts/presentation/sales/screens/contract_form_screen.dart';
import 'package:thuethietbi_app/features/customers/presentation/providers/company_provider.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/reservation.dart';
import '../../../data/models/reservation_item.dart';
import '../../common/widgets/reservation_status_badge.dart';
import '../../providers/reservation_provider.dart';
import '../widgets/quantity_stepper.dart';
import 'equipment_model_picker_screen.dart';
import 'reservation_form_screen.dart';

/// Chi tiết phiếu giữ chỗ: thông tin, thiết bị (model + số lượng) và thao tác theo trạng thái.
class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservationId});

  final String reservationId;

  /// Mở màn hình, chia sẻ [ReservationProvider] và [CompanyProvider] với màn hình gọi.
  static Future<void> open(BuildContext context, String reservationId) {
    final reservations = context.read<ReservationProvider>();
    final companies = context.read<CompanyProvider>();
    final contracts = context.read<RentalContractProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: reservations),
            ChangeNotifierProvider.value(value: companies),
            ChangeNotifierProvider.value(value: contracts),
          ],
          child: ReservationDetailScreen(reservationId: reservationId),
        ),
      ),
    );
  }

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  /// Danh sách thiết bị đang chỉnh trên máy (null: chưa sửa, dùng dữ liệu server).
  List<ReservationItem>? _draftItems;

  bool get _isDirty => _draftItems != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await context.read<ReservationProvider>().loadDetail(
        widget.reservationId,
      );
      _draftItems = null;
    } catch (error) {
      _loadError = apiErrorMessage(
        error,
        fallback: 'Không tải được phiếu đặt thuê.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _isSubmitting = true);

    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(apiErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ------------------------------------------------------------ thiết bị

  Future<void> _addModel(
    Reservation reservation,
    List<ReservationItem> items,
  ) async {
    final provider = context.read<ReservationProvider>();

    final picked = await EquipmentModelPickerScreen.open(
      context,
      api: provider.equipmentModelApi,
      from: reservation.requestedFrom,
      to: reservation.requestedTo,
      reservationId: reservation.id,
      existingModelIds: items.map((i) => i.equipmentModelId).toSet(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _draftItems = [
        ...items,
        ReservationItem(
          id: 'new-${picked.model.id}',
          equipmentModelId: picked.model.id,
          equipmentModelCode: picked.model.code,
          equipmentModelName: picked.model.name,
          unit: picked.model.unit,
          rentalPriceDaily: picked.model.rentalPriceDaily,
          rentalPriceMonthly: picked.model.rentalPriceMonthly,
          quantity: picked.quantity,
          availableQuantity: picked.availableQuantity,
        ),
      ];
    });
  }

  void _changeQuantity(
    List<ReservationItem> items,
    ReservationItem item,
    int quantity,
  ) {
    setState(() {
      _draftItems = [
        for (final i in items)
          i.equipmentModelId == item.equipmentModelId
              ? i.copyWith(quantity: quantity)
              : i,
      ];
    });
  }

  void _removeItem(List<ReservationItem> items, ReservationItem item) {
    setState(() {
      _draftItems = items
          .where((i) => i.equipmentModelId != item.equipmentModelId)
          .toList();
    });
  }

  Future<void> _saveItems(Reservation reservation) async {
    final provider = context.read<ReservationProvider>();
    final quantities = {
      for (final i in _draftItems!) i.equipmentModelId: i.quantity,
    };

    await _run(() async {
      await provider.updateItems(reservation.id, quantities);
      _draftItems = null;
    }, 'Đã lưu thiết bị của phiếu.');
  }

  // ------------------------------------------------------------ trạng thái

  Future<void> _approve(Reservation reservation) async {
    final confirmed = await _confirm(
      title: 'Xác nhận phiếu ${reservation.reservationCode}?',
      message:
          'Phiếu đã xác nhận mới được tạo hợp đồng. Số lượng thiết bị sẽ được kiểm tra lại '
          'trước khi xác nhận. Bạn vẫn có thể mở lại để chỉnh sửa.',
      confirmLabel: 'Xác nhận phiếu',
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<ReservationProvider>();
    await _run(() => provider.approve(reservation.id), 'Đã xác nhận phiếu.');
  }

  Future<void> _createContract(Reservation reservation) async {
    final provider = context.read<ReservationProvider>();

    await ContractFormScreen.create(context, reservationId: reservation.id);

    // Phiếu chuyển "Đã tạo hợp đồng" nếu hợp đồng được tạo.
    if (mounted) await provider.loadDetail(reservation.id);
  }

  Future<void> _reopen(Reservation reservation) async {
    final confirmed = await _confirm(
      title: 'Mở lại để chỉnh sửa?',
      message:
          'Phiếu sẽ về trạng thái "Chờ xử lý". Hạn giữ chỗ không thay đổi; '
          'nhớ xác nhận lại sau khi sửa.',
      confirmLabel: 'Mở lại',
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<ReservationProvider>();
    await _run(
      () => provider.reopen(reservation.id),
      'Đã mở lại phiếu để chỉnh sửa.',
    );
  }

  Future<void> _cancel(Reservation reservation) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(code: reservation.reservationCode),
    );

    if (reason == null || !mounted) return;

    final provider = context.read<ReservationProvider>();
    await _run(
      () => provider.cancel(
        reservation.id,
        reason: reason.isEmpty ? null : reason,
      ),
      'Đã hủy phiếu ${reservation.reservationCode}.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi thiết bị?'),
        content: const Text('Danh sách thiết bị đã sửa nhưng chưa lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ------------------------------------------------------------ giao diện

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>().detailOf(
      widget.reservationId,
    );

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);

        if (await _confirmDiscard()) {
          setState(() => _draftItems = null);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            reservation?.reservationCode ?? 'Phiếu đặt thuê',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: _isSubmitting
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
        ),
        body: _buildBody(reservation),
        bottomNavigationBar: reservation == null
            ? null
            : _buildActions(reservation),
      ),
    );
  }

  Widget _buildBody(Reservation? reservation) {
    if (reservation == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reservation == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _loadError,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final items = _draftItems ?? reservation.items;
    final canEditItems = reservation.canEdit && reservation.isPending;

    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: RefreshIndicator(
        onRefresh: () async {
          if (await _confirmDiscard()) await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeaderCard(reservation: reservation),
            if (!reservation.canEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: AppColors.info,
                background: AppColors.infoLight,
                icon: Icons.info_outline_rounded,
                text:
                    'Phiếu do ${reservation.createdByName ?? 'nhân viên khác'} lập. '
                    'Bạn chỉ có quyền xem.',
              ),
            ] else if (reservation.isApproved) ...[
              const SizedBox(height: AppSpacing.md),
              const _Banner(
                color: AppColors.success,
                background: AppColors.successLight,
                icon: Icons.verified_outlined,
                text:
                    'Phiếu đã xác nhận, có thể tạo hợp đồng. '
                    'Muốn đổi thiết bị hoặc ngày, hãy mở lại để chỉnh sửa.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _InfoCard(
              reservation: reservation,
              onEdit: canEditItems && !_isDirty
                  ? () => ReservationFormScreen.open(
                      context,
                      reservation: reservation,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ItemsCard(
              items: items,
              editable: canEditItems,
              showAvailability: reservation.isOpen,
              isDirty: _isDirty,
              onAdd: () => _addModel(reservation, items),
              onQuantityChanged: (item, q) => _changeQuantity(items, item, q),
              onRemove: (item) => _removeItem(items, item),
              onSave: () => _saveItems(reservation),
              onDiscard: () => setState(() => _draftItems = null),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget? _buildActions(Reservation reservation) {
    if (!reservation.canEdit || !reservation.isOpen) return null;

    final buttons = <Widget>[
      if (reservation.isPending)
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSubmitting || _isDirty || reservation.items.isEmpty
                ? null
                : () => _approve(reservation),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Xác nhận phiếu'),
          ),
        ),
      if (reservation.isApproved) ...[
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _createContract(reservation),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Tạo hợp đồng'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.outlined(
          tooltip: 'Mở lại để chỉnh sửa',
          onPressed: _isSubmitting ? null : () => _reopen(reservation),
          icon: const Icon(Icons.edit_note_rounded),
        ),
      ],
      const SizedBox(width: AppSpacing.sm),
      IconButton.outlined(
        tooltip: 'Hủy phiếu',
        color: AppColors.error,
        onPressed: _isSubmitting ? null : () => _cancel(reservation),
        icon: const Icon(Icons.cancel_outlined),
      ),
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reservation.isPending &&
                (_isDirty || reservation.items.isEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _isDirty
                      ? 'Lưu thiết bị trước khi xác nhận.'
                      : 'Thêm ít nhất một model để xác nhận.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Row(children: buttons),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final remaining = reservation.expiresAt.difference(DateTime.now());
    final remainingText = remaining.inHours >= 24
        ? 'còn ${remaining.inDays} ngày'
        : remaining.inMinutes > 0
        ? 'còn ${remaining.inHours} giờ'
        : 'sắp hết hạn';

    return _Section(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reservation.reservationCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ReservationStatusBadge(status: reservation.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${reservation.companyName ?? ''} (${reservation.companyCode ?? ''})',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (reservation.isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Giữ chỗ đến ${DateFormatter.dateTime(reservation.expiresAt)} ($remainingText)',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.reservation, required this.onEdit});

  final Reservation reservation;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final days =
        reservation.requestedTo.difference(reservation.requestedFrom).inDays +
        1;

    final rows = <(IconData, String, String?)>[
      (
        Icons.date_range_outlined,
        'Thời gian thuê',
        '${DateFormatter.dateRange(reservation.requestedFrom, reservation.requestedTo)} ($days ngày)',
      ),
      (Icons.person_outline_rounded, 'Người liên hệ', reservation.contactName),
      (Icons.phone_outlined, 'Số điện thoại', reservation.contactPhone),
      (Icons.badge_outlined, 'Người lập', reservation.createdByName),
      (Icons.notes_rounded, 'Ghi chú', reservation.note),
    ];

    return _Section(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thông tin phiếu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
            ],
          ),
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value == null || value.isEmpty ? '—' : value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
    required this.editable,
    required this.showAvailability,
    required this.isDirty,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onSave,
    required this.onDiscard,
  });

  final List<ReservationItem> items;
  final bool editable;

  /// Chỉ hiện số máy còn trống khi phiếu còn hiệu lực giữ chỗ.
  final bool showAvailability;
  final bool isDirty;
  final VoidCallback onAdd;
  final void Function(ReservationItem item, int quantity) onQuantityChanged;
  final ValueChanged<ReservationItem> onRemove;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, i) => sum + i.quantity);

    return _Section(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thiết bị giữ chỗ (${items.length} model · $total máy)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (editable)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm model'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Đặt chỗ chỉ giữ theo model và số lượng; chưa chọn máy (serial) cụ thể ở bước này.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: AppColors.textDisabled,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      editable
                          ? 'Chưa có model nào. Thêm model khi khách xác định nhu cầu.'
                          : 'Chưa có model nào.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final item in items)
              _ItemRow(
                item: item,
                editable: editable,
                showAvailability: showAvailability,
                onQuantityChanged: (q) => onQuantityChanged(item, q),
                onRemove: () => onRemove(item),
              ),
          if (isDirty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton(
                  onPressed: onDiscard,
                  child: const Text('Bỏ thay đổi'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu thiết bị'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.editable,
    required this.showAvailability,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final ReservationItem item;
  final bool editable;
  final bool showAvailability;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final available = showAvailability ? item.availableQuantity : null;
    final overLimit = available != null && item.quantity > available;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: overLimit ? AppColors.errorLight : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.equipmentModelName ?? item.equipmentModelId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.equipmentModelCode ?? ''} · ${CurrencyFormatter.vnd(item.rentalPriceDaily)}/ngày',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (editable)
                IconButton(
                  tooltip: 'Bỏ model',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (available != null)
                Expanded(
                  child: Text(
                    overLimit
                        ? 'Chỉ còn $available máy trống'
                        : 'Còn trống tối đa $available',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: overLimit
                          ? AppColors.error
                          : AppColors.textSecondary,
                      fontWeight: overLimit ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (editable)
                QuantityStepper(
                  value: item.quantity,
                  max: available,
                  onChanged: onQuantityChanged,
                )
              else
                Text(
                  'x ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.background,
    required this.icon,
    required this.text,
  });

  final Color color, background;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.code});

  final String code;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Hủy phiếu ${widget.code}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thiết bị đang giữ sẽ được nhả ra cho phiếu khác. Không thể hoàn tác.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Lý do hủy (không bắt buộc)',
              hintText: 'Ví dụ: khách không thuê nữa',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Không hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Hủy phiếu'),
        ),
      ],
    );
  }
}
