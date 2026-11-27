import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/features/contracts/data/models/rental_pricing.dart';
import 'package:thuethietbi_app/features/contracts/presentation/providers/rental_contract_provider.dart';
import 'package:thuethietbi_app/features/customers/data/models/company.dart';
import 'package:thuethietbi_app/features/customers/presentation/providers/company_provider.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/reservation_api.dart';
import '../../../data/models/reservation.dart';
import '../../providers/reservation_provider.dart';
import 'reservation_detail_screen.dart';

/// Lập phiếu giữ chỗ (khi [reservation] null) hoặc sửa thông tin chung của phiếu.
/// Thiết bị được thêm ở màn chi tiết sau khi lưu.
class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({super.key, this.reservation});

  final Reservation? reservation;

  bool get isEditing => reservation != null;

  /// Mở form, chia sẻ [ReservationProvider] và [CompanyProvider] với màn hình gọi.
  static Future<void> open(BuildContext context, {Reservation? reservation}) {
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
          child: ReservationFormScreen(reservation: reservation),
        ),
      ),
    );
  }

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  static final _phonePattern = RegExp(r'^[0-9+ ]{8,20}$');

  final _formKey = GlobalKey<FormState>();
  late final _contactNameController = TextEditingController(
    text: widget.reservation?.contactName,
  );
  late final _contactPhoneController = TextEditingController(
    text: widget.reservation?.contactPhone,
  );
  late final _noteController = TextEditingController(
    text: widget.reservation?.note,
  );

  late String? _companyId = widget.reservation?.companyId;
  late String? _companyLabel = widget.reservation == null
      ? null
      : '${widget.reservation!.companyName} (${widget.reservation!.companyCode})';
  late DateTimeRange? _dates = widget.reservation == null
      ? null
      : DateTimeRange(
          start: widget.reservation!.requestedFrom,
          end: widget.reservation!.requestedTo,
        );

  bool _isSubmitting = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCompany() async {
    final companies = context.read<CompanyProvider>();

    if (!companies.hasLoaded) await companies.load();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Company>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CompanyPickerSheet(
        companies: companies.companies.where((c) => c.isActive).toList(),
        selectedId: _companyId,
      ),
    );

    if (selected != null) {
      setState(() {
        _companyId = selected.id;
        _companyLabel = '${selected.name} (${selected.companyCode})';
      });
    }
  }

  static const int _minAdvanceBookingDays = 3;

  DateTime get _minStartDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(const Duration(days: _minAdvanceBookingDays));
  }

  Future<void> _pickDates() async {
    final minStart = _minStartDate;
    final safeInitial =
        _dates != null && !_dates!.start.isBefore(minStart) ? _dates : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: minStart,
      lastDate: DateTime(minStart.year + 2, 12, 31),
      initialDateRange: safeInitial,
      helpText:
          'Chọn ngày thuê (bắt đầu từ ${DateFormatter.date(minStart)} trở đi)',
      saveText: 'Chọn',
    );

    if (picked != null) setState(() => _dates = picked);
  }

  int? get _rentalDays => _dates == null
      ? null
      : RentalPricing.rentalDays(_dates!.start, _dates!.end);

  bool get _isTooSoon =>
      _dates != null && _dates!.start.isBefore(_minStartDate);

  bool get _isTooShort =>
      _rentalDays != null && _rentalDays! < RentalPricing.minRentalDays;

  String? _datesError(bool showErrors) {
    if (_dates == null) {
      return showErrors ? 'Vui lòng chọn thời gian thuê.' : null;
    }

    if (_isTooSoon) {
      return 'Ngày bắt đầu thuê phải cách hôm nay tối thiểu $_minAdvanceBookingDays ngày (từ ${DateFormatter.date(_minStartDate)} trở đi).';
    }

    // Báo ngay khi chọn, không chờ bấm Lưu.
    if (_isTooShort) {
      return 'Thuê tối thiểu ${RentalPricing.minRentalDays} ngày, gồm cả ngày đầu và cuối.';
    }

    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    final valid = _formKey.currentState!.validate();

    if (!valid ||
        _companyId == null ||
        _dates == null ||
        _isTooSoon ||
        _isTooShort) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<ReservationProvider>();
    final companies = context.read<CompanyProvider>();
    final contracts = context.read<RentalContractProvider>();
    final note = _noteController.text.trim();

    final input = ReservationInput(
      companyId: _companyId!,
      requestedFrom: _dates!.start,
      requestedTo: _dates!.end,
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      note: note.isEmpty ? null : note,
    );

    try {
      final saved = widget.isEditing
          ? await provider.update(widget.reservation!.id, input)
          : await provider.create(input);

      if (!mounted) return;

      final navigator = Navigator.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.isEditing
                ? 'Đã lưu phiếu ${saved.reservationCode}.'
                : 'Đã tạo phiếu ${saved.reservationCode}. Hãy thêm thiết bị.',
          ),
        ),
      );

      if (widget.isEditing) {
        navigator.pop();
      } else {
        // Chuyển sang chi tiết để thêm model thiết bị ngay.
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: provider),
                ChangeNotifierProvider.value(value: companies),
                ChangeNotifierProvider.value(value: contracts),
              ],
              child: ReservationDetailScreen(reservationId: saved.id),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            content: Text(apiErrorMessage(error)),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showErrors = _autovalidateMode != AutovalidateMode.disabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Sửa phiếu giữ chỗ' : 'Lập phiếu giữ chỗ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const _SectionTitle('Thông tin khách hàng'),
            _PickerField(
              label: 'Công ty *',
              icon: Icons.business_outlined,
              value: _companyLabel,
              placeholder: 'Chọn công ty...',
              trailing: Icons.search_rounded,
              errorText: showErrors && _companyId == null
                  ? 'Vui lòng chọn công ty.'
                  : null,
              onTap: _pickCompany,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Người liên hệ *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Vui lòng nhập người liên hệ.';
                if (text.length > 150) return 'Tối đa 150 ký tự.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Vui lòng nhập số điện thoại.';
                if (!_phonePattern.hasMatch(text)) {
                  return 'Số điện thoại không hợp lệ.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('Thời gian thuê'),
            _PickerField(
              label: 'Từ ngày – Đến ngày *',
              icon: Icons.date_range_outlined,
              value: _dates == null
                  ? null
                  : '${DateFormatter.dateRange(_dates!.start, _dates!.end)}'
                        '  ($_rentalDays ngày)',
              placeholder: 'Chọn ngày',
              trailing: Icons.calendar_month_outlined,
              errorText: _datesError(showErrors),
              onTap: _pickDates,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('Ghi chú'),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Ghi chú...',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 6,
              validator: (value) => (value ?? '').trim().length > 2000
                  ? 'Ghi chú tối đa 2000 ký tự.'
                  : null,
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.info,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Tạo phiếu giữ chỗ trước. Sau khi tạo, bạn có thể mở chi tiết '
                        'phiếu để thêm model thiết bị và điều chỉnh số lượng.',
                        style: TextStyle(color: AppColors.info, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      widget.isEditing
                          ? Icons.save_outlined
                          : Icons.event_available_outlined,
                    ),
              label: Text(
                widget.isEditing ? 'Lưu thay đổi' : 'Tạo phiếu giữ chỗ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Ô chọn (công ty, ngày) có giao diện giống TextFormField.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.trailing,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String placeholder;
  final IconData trailing;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          // Luôn đẩy nhãn lên trên để không đè lên dòng gợi ý khi chưa chọn.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(icon),
          suffixIcon: Icon(trailing),
          errorText: errorText,
        ),
        child: Text(
          value ?? placeholder,
          style: TextStyle(
            color: value == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CompanyPickerSheet extends StatefulWidget {
  const _CompanyPickerSheet({
    required this.companies,
    required this.selectedId,
  });

  final List<Company> companies;
  final String? selectedId;

  @override
  State<_CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<_CompanyPickerSheet> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final keyword = _keyword.trim().toLowerCase();
    final companies = widget.companies.where((c) {
      if (keyword.isEmpty) return true;
      return [
        c.name,
        c.companyCode,
        c.taxCode,
      ].any((v) => v.toLowerCase().contains(keyword));
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const Text(
              'Chọn công ty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _keyword = value),
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên, mã công ty, mã số thuế...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: companies.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: Text(
                          'Không có công ty đang hoạt động phù hợp.\n'
                          'Thêm khách hàng ở tab "Khách hàng".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];

                        return ListTile(
                          leading: const Icon(Icons.business_rounded),
                          title: Text(company.name),
                          subtitle: Text(
                            '${company.companyCode} · MST ${company.taxCode}',
                          ),
                          selected: company.id == widget.selectedId,
                          onTap: () => Navigator.pop(context, company),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
