import 'dart:async';
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
import '../../../data/models/shipping_quote.dart';
import '../../providers/rental_contract_provider.dart';
import 'contract_detail_screen.dart';

/// Tạo hợp đồng từ phiếu đã xác nhận ([reservationId]) hoặc sửa hợp đồng ([contract])
/// khi còn Bản nháp / Bị từ chối.
///
/// Phí vận chuyển do Backend tự đo khoảng cách và tính theo chính sách ưu đãi thuê nhiều;
/// Sales không được tự tạo dịch vụ hay sửa tay giá vận chuyển.
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
  String? _shippingPolicySummary;
  late DateTime _startDate;
  late DateTime _endDate;
  int _rentalDays = 0;
  double _depositRate = 0.2;

  RepresentativeType _repType = RepresentativeType.legal;
  List<RentalContractItem> _items = [];

  // Vận chuyển tự động tính từ Backend (Sales chỉ chọn phương thức, không sửa giá).
  ServiceProvider _deliveryProvider = ServiceProvider.rentalCompany;
  ShippingQuote? _shippingQuote;
  bool _isQuotingShipping = false;
  String? _shippingError;
  Timer? _quoteDebounce;

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
    _quoteDebounce?.cancel();
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
        _shippingPolicySummary = s.shippingPolicySummary;
        _startDate = s.startDate;
        _endDate = s.endDate;
        _rentalDays = s.rentalDays;
        _depositRate = s.depositRate;
        _items = s.items;
        _depositController.text = s.depositRequiredAmount.round().toString();
        if (s.companyAddress != null && s.companyAddress!.trim().isNotEmpty) {
          _deliveryAddressController.text = s.companyAddress!.trim();
        }
      }
    } catch (error) {
      _loadError = apiErrorMessage(
        error,
        fallback: 'Không tải được dữ liệu hợp đồng.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (mounted &&
        _loadError == null &&
        (_deliveryProvider == ServiceProvider.customer ||
            _deliveryAddressController.text.trim().isNotEmpty)) {
      _fetchShippingQuote();
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

    final existingDelivery = detail.services
        .where((s) => s.serviceType == ContractServiceType.delivery)
        .firstOrNull;
    _deliveryProvider =
        existingDelivery?.providedBy ?? ServiceProvider.rentalCompany;

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

  // ------------------------------------------------------------ tiền & vận chuyển

  RentalType get _rentalType => RentalType.forDays(_rentalDays);

  double _amountOf(RentalContractItem item) =>
      item.quantity *
      item.agreedUnitPrice *
      item.billingUnit.billableUnits(_rentalDays);

  double get _itemsTotal =>
      _items.fold(0.0, (sum, item) => sum + _amountOf(item));

  double get _shippingFee => _deliveryProvider == ServiceProvider.customer
      ? 0.0
      : (_shippingQuote?.finalFee ?? 0.0);

  double get _total => _itemsTotal + _shippingFee;

  void _recalculate() {
    if (!_depositEdited) {
      _depositController.text = ((_total * _depositRate / 1000).round() * 1000)
          .toString();
    }
    setState(() {});
  }

  void _scheduleShippingQuote() {
    _quoteDebounce?.cancel();
    if (_deliveryProvider == ServiceProvider.customer) {
      _fetchShippingQuote();
      return;
    }

    final address = _deliveryAddressController.text.trim();
    if (address.length < 5) {
      setState(() {
        _shippingQuote = null;
        _shippingError = null;
      });
      _recalculate();
      return;
    }

    _quoteDebounce = Timer(
      const Duration(milliseconds: 900),
      _fetchShippingQuote,
    );
  }

  Future<void> _fetchShippingQuote() async {
    _quoteDebounce?.cancel();
    final address = _deliveryAddressController.text.trim();

    if (_deliveryProvider == ServiceProvider.rentalCompany && address.isEmpty) {
      setState(() {
        _shippingQuote = null;
        _shippingError = 'Nhập địa chỉ giao hàng để hệ thống tính phí.';
      });
      _recalculate();
      return;
    }

    setState(() {
      _isQuotingShipping = true;
      _shippingError = null;
    });

    try {
      final quote = await context
          .read<RentalContractProvider>()
          .getShippingQuote(
            reservationId: widget.isEditing ? null : widget.reservationId,
            contractId: widget.isEditing ? widget.contract!.id : null,
            providedBy: _deliveryProvider,
            deliveryAddress: address.isEmpty ? null : address,
          );
      if (!mounted) return;
      setState(() {
        _shippingQuote = quote;
        _shippingError = null;
      });
      _recalculate();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _shippingQuote = null;
        _shippingError = apiErrorMessage(
          error,
          fallback: 'Chưa đo được khoảng cách giao hàng.',
        );
      });
      _recalculate();
    } finally {
      if (mounted) setState(() => _isQuotingShipping = false);
    }
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

      // 2. Lưu hợp đồng (Backend tự tính và khóa phí vận chuyển).
      setState(() => _submitStep = 'Đang tính phí & lưu hợp đồng...');

      String? optional(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();

      final input = RentalContractInput(
        items: _items,
        deliveryProvidedBy: _deliveryProvider,
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
              title: 'Thông tin thuê & vận chuyển',
              subtitle: 'Phí vận chuyển do hệ thống tự tính theo khoảng cách (2 lượt) và ưu đãi thuê nhiều.',
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
                const Text(
                  'Phương thức vận chuyển',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<ServiceProvider>(
                  segments: const [
                    ButtonSegment(
                      value: ServiceProvider.rentalCompany,
                      label: Text('Bên cho thuê giao'),
                      icon: Icon(Icons.local_shipping_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ServiceProvider.customer,
                      label: Text('Khách tự vận chuyển'),
                      icon: Icon(Icons.directions_car_outlined, size: 18),
                    ),
                  ],
                  selected: {_deliveryProvider},
                  onSelectionChanged: (selection) {
                    setState(() => _deliveryProvider = selection.first);
                    _fetchShippingQuote();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _deliveryAddressController,
                  decoration: InputDecoration(
                    labelText:
                        _deliveryProvider == ServiceProvider.rentalCompany
                        ? 'Địa chỉ giao hàng *'
                        : 'Địa chỉ giao hàng (không bắt buộc)',
                    hintText:
                        'VD: 123 Nguyễn Văn Linh, Quận 7, TP. Hồ Chí Minh',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon:
                        _deliveryProvider == ServiceProvider.rentalCompany
                        ? IconButton(
                            tooltip: 'Tính phí vận chuyển',
                            onPressed: _isQuotingShipping
                                ? null
                                : _fetchShippingQuote,
                            icon: _isQuotingShipping
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.route_outlined),
                          )
                        : null,
                  ),
                  onChanged: (_) => _scheduleShippingQuote(),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (_deliveryProvider == ServiceProvider.rentalCompany &&
                        text.isEmpty) {
                      return 'Vui lòng nhập địa chỉ giao hàng.';
                    }
                    if (text.length > 500) return 'Tối đa 500 ký tự.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildShippingQuoteCard(),
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
                  label: _deliveryProvider == ServiceProvider.customer
                      ? 'Phí vận chuyển (khách tự vận chuyển)'
                      : 'Phí vận chuyển (tự động, 2 lượt)',
                  value: _shippingFee,
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

  Widget _buildShippingQuoteCard() {
    if (_deliveryProvider == ServiceProvider.customer) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Khách hàng tự vận chuyển · Phí vận chuyển: 0 đ (khóa tự động).',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isQuotingShipping) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Đang đo khoảng cách từ Kho chính và tính phí vận chuyển...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_shippingError != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _shippingError!,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _fetchShippingQuote,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final q = _shippingQuote;
    if (q == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        child: Text(
          _shippingPolicySummary ?? 'Nhập địa chỉ giao hàng rồi bấm biểu tượng lộ trình để hệ thống tự tính phí vận chuyển.',
          style: const TextStyle(
            color: AppColors.info,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Phí vận chuyển tự động (không chỉnh tay)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                q.finalFee == 0
                    ? 'Miễn phí'
                    : CurrencyFormatter.vnd(q.finalFee),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Khoảng cách: ${q.distanceKm?.toStringAsFixed(1) ?? '0'} km (× ${q.trips} lượt giao & thu hồi)'
            '${q.isEstimated ? ' · ước lượng' : ''}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Miễn phí ${q.freeRadiusKm.toStringAsFixed(0)} km đầu · Tính phí ${q.chargeableKm.toStringAsFixed(1)} km × ${CurrencyFormatter.vnd(q.pricePerKmOneWay)}/km/lượt',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (q.promotionDescription != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                q.promotionDescription!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ],
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
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
