import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/currency_formatter.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/rental_contract_api.dart';
import '../../../data/models/contract_document.dart';
import '../../../data/models/contract_representative.dart';
import '../../../data/models/rental_contract.dart';
import '../../../data/models/rental_contract_item.dart';
import '../../../data/models/rental_contract_service_model.dart';
import '../../../data/models/rental_pricing.dart';
import '../../providers/rental_contract_provider.dart';
import 'contract_detail_screen.dart';

/// Tạo hợp đồng từ phiếu đã xác nhận ([reservationId]) hoặc sửa hợp đồng ([contract])
/// khi còn Bản nháp / Bị từ chối.
class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen._({this.reservationId, this.contract});

  final String? reservationId;
  final RentalContract? contract;

  bool get isEditing => contract != null;

  static Future<void> create(
    BuildContext context, {
    required String reservationId,
  }) => _open(context, ContractFormScreen._(reservationId: reservationId));

  static Future<void> edit(
    BuildContext context, {
    required RentalContract contract,
  }) => _open(context, ContractFormScreen._(contract: contract));

  static Future<void> _open(BuildContext context, ContractFormScreen screen) {
    final provider = context.read<RentalContractProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChangeNotifierProvider.value(value: provider, child: screen),
      ),
    );
  }

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

/// Ô giấy tờ: ảnh đã có trên server (khi sửa) hoặc ảnh mới chọn trên máy.
class _DocumentSlot {
  _DocumentSlot(this.kind);

  final ContractDocumentKind kind;
  String? storageFileId;
  String? remoteUrl;
  String? localPath;

  bool get hasImage => localPath != null || storageFileId != null;
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  static final _idNumberPattern = RegExp(r'^(\d{9}|\d{12})$');
  static final _phonePattern = RegExp(r'^[0-9+ ]{8,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _deliveryAddressController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  final _noteController = TextEditingController();
  final _repNameController = TextEditingController();
  final _repIdController = TextEditingController();
  final _repPhoneController = TextEditingController();
  final _repEmailController = TextEditingController();
  final _depositController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String _submitStep = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // Thông tin cố định theo phiếu.
  String _title = '';
  String _subtitle = '';
  late DateTime _startDate;
  late DateTime _endDate;
  int _rentalDays = 0;
  double _depositRate = 0.2;

  RepresentativeType _repType = RepresentativeType.legal;
  List<RentalContractItem> _items = [];
  final List<RentalContractServiceModel> _services = [];

  /// Cọc tự tính theo tỷ lệ cho đến khi Sales sửa tay.
  bool _depositEdited = false;

  final Map<ContractDocumentKind, _DocumentSlot> _documents = {
    for (final kind in [
      ContractDocumentKind.idCardFront,
      ContractDocumentKind.idCardBack,
      ContractDocumentKind.businessLicense,
      ContractDocumentKind.authorizationLetter,
    ])
      kind: _DocumentSlot(kind),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _deliveryAddressController,
      _deliveryNoteController,
      _noteController,
      _repNameController,
      _repIdController,
      _repPhoneController,
      _repEmailController,
      _depositController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<RentalContractProvider>();

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      if (widget.isEditing) {
        final contract = await provider.loadDetail(widget.contract!.id);
        _fillFromContract(contract);
        // Backend tính lại giá theo giá niêm yết khi lưu: hiển thị đúng số đó.
        _items = await provider.repriceItems(_items, _rentalDays);
      } else {
        final s = await provider.getSuggestion(widget.reservationId!);
        _title = 'Tạo hợp đồng';
        _subtitle = 'Từ phiếu ${s.reservationCode} · ${s.companyName}';
        _startDate = s.startDate;
        _endDate = s.endDate;
        _rentalDays = s.rentalDays;
        _depositRate = s.depositRate;
        _items = s.items;
        _depositController.text = s.depositRequiredAmount.round().toString();
      }
    } catch (error) {
      _loadError = apiErrorMessage(
        error,
        fallback: 'Không tải được dữ liệu hợp đồng.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillFromContract(RentalContract contract) {
    final detail = contract.detail!;

    _title = 'Sửa hợp đồng ${contract.contractCode}';
    _subtitle =
        '${contract.companyName ?? ''} · phiếu ${contract.reservationCode ?? ''}';
    _startDate = contract.startDate;
    _endDate = contract.endDate;
    _rentalDays = contract.rentalDays;
    _items = detail.items;
    _services
      ..clear()
      ..addAll(detail.services);
    _deliveryAddressController.text = detail.deliveryAddress ?? '';
    _deliveryNoteController.text = detail.deliveryNote ?? '';
    _noteController.text = detail.note ?? '';
    _depositController.text = contract.depositRequiredAmount.round().toString();
    _depositEdited = true;

    final rep = detail.representative;
    if (rep != null) {
      _repNameController.text = rep.fullName;
      _repIdController.text = rep.idNumber;
      _repPhoneController.text = rep.phone ?? '';
      _repEmailController.text = rep.email ?? '';
      _repType = rep.representativeType;
    }

    for (final document in detail.documents) {
      final slot = _documents[document.kind];
      if (slot == null) continue;
      slot
        ..storageFileId = document.storageFileId
        ..remoteUrl = document.url;
    }
  }

  // ------------------------------------------------------------ tiền
  // Loại thuê, đơn vị tính và đơn giá theo số ngày thuê và giá niêm yết của
  // model (RentalPricing), Sales không sửa được.

  RentalType get _rentalType => RentalType.forDays(_rentalDays);

  double _amountOf(RentalContractItem item) =>
      item.quantity *
      item.agreedUnitPrice *
      item.billingUnit.billableUnits(_rentalDays);

  double get _itemsTotal =>
      _items.fold(0.0, (sum, item) => sum + _amountOf(item));

  double get _servicesTotal => _services
      .where((s) => s.isCharged)
      .fold(0.0, (sum, s) => sum + s.quantity * s.unitPrice);

  double get _total => _itemsTotal + _servicesTotal;

  void _recalculate() {
    if (!_depositEdited) {
      _depositController.text = ((_total * _depositRate / 1000).round() * 1000)
          .toString();
    }
    setState(() {});
  }

  // ------------------------------------------------------------ dịch vụ

  Future<void> _editService({int? index}) async {
    final result = await showDialog<RentalContractServiceModel>(
      context: context,
      builder: (_) =>
          _ServiceDialog(initial: index == null ? null : _services[index]),
    );

    if (result == null) return;

    if (index == null) {
      _services.add(result);
    } else {
      _services[index] = result;
    }
    _recalculate();
  }

  // ------------------------------------------------------------ giấy tờ

  Future<void> _pickDocument(_DocumentSlot slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.kind.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Giảm kích thước để nằm trong giới hạn 5 MB/ảnh của Backend.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 82,
    );

    if (file != null) {
      setState(() {
        slot
          ..localPath = file.path
          ..storageFileId = null
          ..remoteUrl = null;
      });
    }
  }

  List<_DocumentSlot> get _requiredSlots => [
    _documents[ContractDocumentKind.idCardFront]!,
    _documents[ContractDocumentKind.idCardBack]!,
    _documents[ContractDocumentKind.businessLicense]!,
    if (_repType == RepresentativeType.authorized)
      _documents[ContractDocumentKind.authorizationLetter]!,
  ];

  // ------------------------------------------------------------ lưu

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    final valid = _formKey.currentState!.validate();
    final missingDocs = _requiredSlots.where((s) => !s.hasImage).toList();

    if (!valid || missingDocs.isNotEmpty) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      if (missingDocs.isNotEmpty) {
        _showError(
          'Vui lòng tải lên: ${missingDocs.map((s) => s.kind.label).join(', ')}.',
        );
      }
      return;
    }

    final provider = context.read<RentalContractProvider>();
    setState(() => _isSubmitting = true);

    try {
      // 1. Upload ảnh mới chọn (giữ nguyên ảnh đã có trên server).
      final toUpload = _requiredSlots
          .where((s) => s.localPath != null)
          .toList();

      if (toUpload.isNotEmpty) {
        setState(
          () => _submitStep = 'Đang tải ${toUpload.length} ảnh giấy tờ...',
        );
        final ids = await provider.api.uploadImages(
          toUpload.map((s) => s.localPath!).toList(),
        );
        for (var i = 0; i < toUpload.length; i++) {
          toUpload[i]
            ..storageFileId = ids[i]
            ..localPath = null;
        }
      }

      // 2. Lưu hợp đồng.
      setState(() => _submitStep = 'Đang lưu hợp đồng...');

      String? optional(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();

      final input = RentalContractInput(
        items: _items,
        services: _services,
        representative: ContractRepresentative(
          fullName: _repNameController.text.trim(),
          idNumber: _repIdController.text.trim(),
          phone: optional(_repPhoneController),
          email: optional(_repEmailController),
          representativeType: _repType,
        ),
        depositRequiredAmount: double.tryParse(_depositController.text) ?? 0,
        idCardFrontFileId:
            _documents[ContractDocumentKind.idCardFront]!.storageFileId!,
        idCardBackFileId:
            _documents[ContractDocumentKind.idCardBack]!.storageFileId!,
        businessLicenseFileId:
            _documents[ContractDocumentKind.businessLicense]!.storageFileId!,
        authorizationLetterFileId: _repType == RepresentativeType.authorized
            ? _documents[ContractDocumentKind.authorizationLetter]!
                  .storageFileId
            : null,
        deliveryAddress: optional(_deliveryAddressController),
        deliveryNote: optional(_deliveryNoteController),
        note: optional(_noteController),
      );

      final saved = widget.isEditing
          ? await provider.update(widget.contract!.id, input)
          : await provider.create(widget.reservationId!, input);

      if (!mounted) return;

      final navigator = Navigator.of(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.isEditing
                ? 'Đã lưu hợp đồng ${saved.contractCode}.'
                : 'Đã tạo hợp đồng ${saved.contractCode} (bản nháp). Kiểm tra lại rồi gửi duyệt.',
          ),
        ),
      );

      if (widget.isEditing) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: ContractDetailScreen(contractId: saved.id),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError(
          error is UploadFailedException
              ? error.message
              : apiErrorMessage(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStep = '';
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(message),
        ),
      );
  }

  // ------------------------------------------------------------ giao diện

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Hỏi lại trước khi thoát để không mất dữ liệu đã nhập.
      canPop: _isLoading || _loadError != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSubmitting) return;
        final navigator = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Thoát khỏi form?'),
            content: const Text('Những thay đổi chưa lưu sẽ bị mất.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Thoát'),
              ),
            ],
          ),
        );
        if (leave ?? false) navigator.pop();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title.isEmpty ? 'Hợp đồng' : _title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _loadError,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              _subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Thông tin thuê',
              children: [
                _ReadOnlyRow(
                  icon: Icons.date_range_outlined,
                  label: 'Thời gian thuê',
                  value:
                      '${DateFormatter.dateRange(_startDate, _endDate)} ($_rentalDays ngày)',
                ),
                const SizedBox(height: AppSpacing.md),
                _ReadOnlyRow(
                  icon: Icons.sell_outlined,
                  label: 'Hình thức thuê',
                  value: _rentalType == RentalType.longTerm
                      ? '${_rentalType.label} (trên ${RentalPricing.shortTermMaxDays} ngày, tính theo giá tháng)'
                      : '${_rentalType.label} (đến ${RentalPricing.shortTermMaxDays} ngày, tính theo giá ngày)',
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _deliveryAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ giao hàng',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().length > 500
                      ? 'Tối đa 500 ký tự.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _deliveryNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú giao hàng',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Thiết bị (${_items.length} model)',
              subtitle: 'Model và số lượng theo phiếu đã xác nhận.',
              children: [
                for (var i = 0; i < _items.length; i++) _buildItemRow(i),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Dịch vụ đi kèm',
              subtitle: 'Chỉ dịch vụ do bên cho thuê thực hiện mới tính tiền.',
              trailing: TextButton.icon(
                onPressed: () => _editService(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm'),
              ),
              children: [
                if (_services.isEmpty)
                  const Text(
                    'Chưa có dịch vụ.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                for (var i = 0; i < _services.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_services[i].serviceType.label),
                    subtitle: Text(
                      '${_services[i].providedBy.label} · ${_services[i].quantity} × ${CurrencyFormatter.vnd(_services[i].unitPrice)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: () {
                        _services.removeAt(i);
                        _recalculate();
                      },
                    ),
                    onTap: () => _editService(index: i),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Người đại diện ký',
              children: [
                DropdownButtonFormField<RepresentativeType>(
                  initialValue: _repType,
                  decoration: const InputDecoration(
                    labelText: 'Tư cách người ký *',
                  ),
                  items: [
                    for (final t in RepresentativeType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() => _repType = v ?? _repType),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _repNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Vui lòng nhập họ tên người đại diện.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _repIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số CCCD *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => _idNumberPattern.hasMatch((v ?? '').trim())
                      ? null
                      : 'Số CCCD gồm 12 chữ số (CMND cũ: 9 số).',
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _repPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.isNotEmpty && !_phonePattern.hasMatch(t)
                        ? 'Số điện thoại không hợp lệ.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _repEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.isNotEmpty && !_emailPattern.hasMatch(t)
                        ? 'Email không hợp lệ.'
                        : null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Giấy tờ',
              subtitle: 'Ảnh rõ nét, tối đa 5 MB mỗi ảnh.',
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.25,
                  children: [
                    for (final slot in _requiredSlots)
                      _DocumentTile(
                        slot: slot,
                        showError:
                            _autovalidateMode != AutovalidateMode.disabled &&
                            !slot.hasImage,
                        onTap: () => _pickDocument(slot),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Giá trị hợp đồng',
              children: [
                _MoneyRow(label: 'Tiền thuê thiết bị', value: _itemsTotal),
                _MoneyRow(
                  label: 'Dịch vụ (bên cho thuê)',
                  value: _servicesTotal,
                ),
                const Divider(height: AppSpacing.xl),
                _MoneyRow(label: 'Tổng giá trị', value: _total, bold: true),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Tiền đặt cọc (đ)',
                    helperText: _depositEdited
                        ? 'Đã chỉnh tay'
                        : 'Tự tính ${(_depositRate * 100).round()}% tổng giá trị',
                    suffixIcon: _depositEdited
                        ? IconButton(
                            tooltip: 'Tính lại theo tỷ lệ',
                            icon: const Icon(Icons.restart_alt_rounded),
                            onPressed: () {
                              _depositEdited = false;
                              _recalculate();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _depositEdited = true),
                  validator: (v) {
                    final value = double.tryParse(v ?? '') ?? 0;
                    return value > _total
                        ? 'Tiền cọc không được lớn hơn tổng giá trị.'
                        : null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú hợp đồng',
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    final units = item.billingUnit.billableUnits(_rentalDays);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.equipmentModelName ?? ''} × ${item.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            item.equipmentModelCode ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${item.quantity} × ${CurrencyFormatter.vnd(item.agreedUnitPrice)}/${item.billingUnit.unitLabel} × $units ${item.billingUnit.unitLabel} = ${CurrencyFormatter.vnd(_amountOf(item))}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSubmitting ? _submitStep : 'Tổng giá trị',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.vnd(_total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(widget.isEditing ? 'Lưu' : 'Tạo hợp đồng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    // Nhãn ở trên, giá trị ở dưới để khoảng ngày dài không bị ngắt dòng.
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? AppColors.primary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(CurrencyFormatter.vnd(value), style: style),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.slot,
    required this.showError,
    required this.onTap,
  });

  final _DocumentSlot slot;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (slot.localPath != null) {
      content = Image.file(File(slot.localPath!), fit: BoxFit.cover);
    } else if (slot.remoteUrl != null) {
      content = CachedNetworkImage(
        imageUrl: slot.remoteUrl!,
        cacheKey: slot.storageFileId,
        fit: BoxFit.cover,
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            color: showError ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(height: 6),
          Text(
            slot.kind.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: showError ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          border: Border.all(
            color: showError ? AppColors.error : AppColors.border,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (slot.hasImage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    slot.kind.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({this.initial});

  final RentalContractServiceModel? initial;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late ContractServiceType _type =
      widget.initial?.serviceType ?? ContractServiceType.delivery;
  late ServiceProvider _provider =
      widget.initial?.providedBy ?? ServiceProvider.rentalCompany;
  late final _quantityController = TextEditingController(
    text: '${widget.initial?.quantity ?? 1}',
  );
  late final _priceController = TextEditingController(
    text: '${widget.initial?.unitPrice.round() ?? 0}',
  );
  late final _noteController = TextEditingController(
    text: widget.initial?.note,
  );

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ContractServiceType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Loại dịch vụ'),
                items: [
                  for (final t in ContractServiceType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ServiceProvider>(
                initialValue: _provider,
                decoration: const InputDecoration(labelText: 'Bên thực hiện'),
                items: [
                  for (final p in ServiceProvider.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _provider = v ?? _provider),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'SL'),
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) < 1 ? 'Từ 1' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Đơn giá (đ)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final note = _noteController.text.trim();
            Navigator.pop(
              context,
              RentalContractServiceModel(
                serviceType: _type,
                providedBy: _provider,
                quantity: int.parse(_quantityController.text),
                unitPrice: double.tryParse(_priceController.text) ?? 0,
                note: note.isEmpty ? null : note,
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
