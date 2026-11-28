import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/widgets/scanner/quick_serial_scanner_sheet.dart';

import '../../../data/datasources/customer_incident_api.dart';
import '../../../data/models/customer_incident.dart';

/// Khách báo sự cố (UX tối ưu cho doanh nghiệp thuê nhiều thiết bị):
/// - Quét mã vạch (Barcode/QR) trên tem máy hoặc nhập mã Serial để xác nhận đúng thiết bị đang thuê.
/// - Không hiển thị danh sách tích chọn dài dòng gây khó thao tác khi thuê hàng trăm/nghìn máy.
class CustomerIncidentFormScreen extends StatefulWidget {
  const CustomerIncidentFormScreen._({
    required this.api,
    required this.defaultContactName,
    required this.defaultContactPhone,
  });

  final CustomerIncidentApi api;
  final String defaultContactName, defaultContactPhone;

  static const maxImages = 5;

  /// Trả về sự cố vừa tạo (null nếu thoát).
  static Future<CustomerIncidentDetail?> open(
    BuildContext context, {
    required CustomerIncidentApi api,
    String? contactName,
    String? contactPhone,
  }) => Navigator.of(context).push<CustomerIncidentDetail>(
    MaterialPageRoute(
      builder: (_) => CustomerIncidentFormScreen._(
        api: api,
        defaultContactName: contactName ?? '',
        defaultContactPhone: contactPhone ?? '',
      ),
    ),
  );

  @override
  State<CustomerIncidentFormScreen> createState() =>
      _CustomerIncidentFormScreenState();
}

class _CustomerIncidentFormScreenState
    extends State<CustomerIncidentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serialController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final _contactNameController = TextEditingController(
    text: widget.defaultContactName,
  );
  late final _contactPhoneController = TextEditingController(
    text: widget.defaultContactPhone,
  );

  final List<RentedEquipment> _selectedEquipments = [];
  final List<XFile> _images = [];
  bool _isLookingUp = false;
  String? _lookupError;
  bool _isSaving = false;
  String _saveStep = '';

  @override
  void dispose() {
    _serialController.dispose();
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scanned = await QuickSerialScannerSheet.open(
      context,
      title: 'Quét mã vạch thiết bị gặp sự cố',
      subtitle:
          'Đưa tem mã vạch/QR trên thiết bị đang thuê vào khung camera hoặc nhập tay bên dưới.',
    );
    if (scanned != null && scanned.trim().isNotEmpty && mounted) {
      _serialController.text = scanned.trim();
      await _lookupAndAddSerial(scanned.trim());
    }
  }

  Future<void> _lookupAndAddSerial(String raw) async {
    final serial = raw.trim();
    if (serial.isEmpty) {
      setState(() => _lookupError = 'Vui lòng nhập hoặc quét mã serial thiết bị.');
      return;
    }

    if (_selectedEquipments.any(
      (e) => e.serialNumber.toLowerCase() == serial.toLowerCase(),
    )) {
      setState(
        () => _lookupError = 'Thiết bị "$serial" đã được thêm vào danh sách báo sự cố.',
      );
      return;
    }

    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });

    try {
      final equipment = await widget.api.lookupRentedSerial(serial);
      if (!mounted) return;

      if (_selectedEquipments.any(
        (e) => e.equipmentId == equipment.equipmentId,
      )) {
        setState(
          () => _lookupError =
              'Thiết bị ${equipment.serialNumber} đã nằm trong danh sách báo sự cố.',
        );
        return;
      }

      setState(() {
        _selectedEquipments.add(equipment);
        _serialController.clear();
        _lookupError = null;
      });
      _showMessage(
        'Đã thêm ${equipment.modelName} (${equipment.serialNumber})',
        isError: false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _lookupError = apiErrorMessage(
            error,
            fallback: 'Không tìm thấy thiết bị đang thuê với mã serial này.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<void> _pickImages() async {
    final remaining = CustomerIncidentFormScreen.maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (!mounted || picked.isEmpty) return;

    setState(() => _images.addAll(picked.take(remaining)));
  }

  Future<void> _takePhoto() async {
    if (_images.length >= CustomerIncidentFormScreen.maxImages) return;

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (!mounted || photo == null) return;

    setState(() => _images.add(photo));
  }

  Future<void> _submit() async {
    if (_selectedEquipments.isEmpty) {
      _showMessage(
        'Vui lòng quét hoặc nhập ít nhất 1 mã serial thiết bị gặp sự cố.',
        isError: true,
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _saveStep = _images.isEmpty
          ? 'Đang gửi báo cáo sự cố...'
          : 'Đang tải ${_images.length} ảnh minh họa...';
    });

    try {
      final fileIds = _images.isEmpty
          ? const <String>[]
          : await widget.api.uploadImages([for (final f in _images) f.path]);

      if (mounted) setState(() => _saveStep = 'Đang gửi báo cáo sự cố...');

      final created = await widget.api.create(
        IncidentInput(
          description: _descriptionController.text.trim(),
          contactName: _contactNameController.text.trim(),
          contactPhone: _contactPhoneController.text.trim(),
          equipmentIds: [for (final e in _selectedEquipments) e.equipmentId],
          attachmentFileIds: fileIds,
        ),
      );

      if (mounted) Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is IncidentUploadException
              ? error.message
              : apiErrorMessage(error, fallback: 'Không gửi được báo cáo sự cố.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStep = '';
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Báo sự cố thiết bị',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            110,
          ),
          children: [
            // 1. Quét mã vạch hoặc nhập Serial thiết bị
            _SectionCard(
              title: '1. Thiết bị gặp sự cố (${_selectedEquipments.length})',
              subtitle:
                  'Quét mã vạch trên tem máy hoặc nhập đúng số Serial — hệ thống sẽ tự kiểm tra thiết bị thuộc hợp đồng công ty bạn đang thuê.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: (_isSaving || _isLookingUp) ? null : _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'Quét mã vạch / QR thiết bị',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serialController,
                          enabled: !_isSaving && !_isLookingUp,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _lookupAndAddSerial,
                          decoration: InputDecoration(
                            labelText: 'Hoặc nhập mã Serial thiết bị',
                            hintText: 'VD: SN-LAPTOP-001',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(78, 48),
                        ),
                        onPressed: (_isSaving || _isLookingUp)
                            ? null
                            : () => _lookupAndAddSerial(_serialController.text),
                        child: _isLookingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Thêm'),
                      ),
                    ],
                  ),
                  if (_lookupError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lookupError!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedEquipments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (var i = 0; i < _selectedEquipments.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.devices_other_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedEquipments[i].serialNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedEquipments[i].modelName} • HĐ ${_selectedEquipments[i].contractCode}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Bỏ máy này',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 19,
                                color: AppColors.error,
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () => setState(
                                      () => _selectedEquipments.removeAt(i),
                                    ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Mô tả sự cố
            _SectionCard(
              title: '2. Mô tả tình trạng sự cố',
              child: TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng mô tả tình trạng sự cố.'
                    : null,
                decoration: InputDecoration(
                  hintText:
                      'VD: Máy không lên nguồn, màn hình chớp nháy, báo lỗi kết nối...',
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Thông tin người liên hệ
            _SectionCard(
              title: '3. Người liên hệ tại hiện trường',
              child: Column(
                children: [
                  TextFormField(
                    controller: _contactNameController,
                    enabled: !_isSaving,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên người liên hệ.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Họ tên người liên hệ *',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactPhoneController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập số điện thoại liên hệ.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại liên hệ *',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Ảnh minh họa
            _SectionCard(
              title:
                  '4. Ảnh minh họa (${_images.length}/${CustomerIncidentFormScreen.maxImages})',
              subtitle: 'Tùy chọn — giúp kỹ thuật viên chẩn đoán nhanh hơn.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            (_isSaving ||
                                _images.length >=
                                    CustomerIncidentFormScreen.maxImages)
                            ? null
                            : _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            (_isSaving ||
                                _images.length >=
                                    CustomerIncidentFormScreen.maxImages)
                            ? null
                            : _pickImages,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Chọn từ thư viện'),
                      ),
                    ],
                  ),
                  if (_images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_images[i].path),
                                width: 82,
                                height: 82,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 3,
                              right: 3,
                              child: GestureDetector(
                                onTap: _isSaving
                                    ? null
                                    : () => setState(() => _images.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _isSaving ? null : _submit,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSaving
                  ? _saveStep
                  : 'Gửi báo cáo sự cố (${_selectedEquipments.length} máy)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
