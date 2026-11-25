import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';

import '../../../data/datasources/customer_incident_api.dart';
import '../../../data/models/customer_incident.dart';

/// Khách báo sự cố: chọn máy đang thuê gặp vấn đề, mô tả, người liên hệ,
/// ảnh minh họa (tối đa 5 ảnh).
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
  final _descriptionController = TextEditingController();
  late final _contactNameController = TextEditingController(
    text: widget.defaultContactName,
  );
  late final _contactPhoneController = TextEditingController(
    text: widget.defaultContactPhone,
  );

  List<RentedEquipment> _equipments = [];
  final Set<String> _selected = {};
  final List<XFile> _images = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _saveStep = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final equipments = await widget.api.getRentedEquipments();
      if (mounted) setState(() => _equipments = equipments);
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = apiErrorMessage(
            error,
            fallback: 'Không tải được danh sách máy đang thuê.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    final remaining = CustomerIncidentFormScreen.maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      limit: remaining,
    );

    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked.take(remaining)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selected.isEmpty) {
      _showError('Hãy chọn máy gặp sự cố.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveStep = _images.isEmpty ? 'Đang gửi...' : 'Đang tải ảnh lên...';
    });

    try {
      final fileIds = await widget.api.uploadImages(
        _images.map((i) => i.path).toList(),
      );

      if (mounted) setState(() => _saveStep = 'Đang gửi...');

      final result = await widget.api.create(
        IncidentInput(
          description: _descriptionController.text.trim(),
          contactName: _contactNameController.text.trim(),
          contactPhone: _contactPhoneController.text.trim(),
          equipmentIds: _selected.toList(),
          attachmentFileIds: fileIds,
        ),
      );

      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        _showError(
          error is IncidentUploadException
              ? error.message
              : apiErrorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Báo sự cố',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _equipments.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSaving ? _saveStep : 'Gửi báo sự cố'),
                ),
              ),
            ),
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

    if (_equipments.isEmpty) {
      return const AppEmptyView(
        icon: Icons.inventory_2_outlined,
        title: 'Chưa có máy đang thuê',
        message: 'Chỉ báo sự cố được cho máy đã giao đến công ty. Vui lòng liên hệ nhân viên kinh doanh nếu cần hỗ trợ.',
      );
    }

    final byContract = <String, List<RentedEquipment>>{};
    for (final e in _equipments) {
      byContract.putIfAbsent(e.contractCode, () => []).add(e);
    }

    return AbsorbPointer(
      absorbing: _isSaving,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Section(
              title: 'Máy gặp sự cố (${_selected.length})',
              children: [
                for (final entry in byContract.entries) ...[
                  Text(
                    'Hợp đồng ${entry.key}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  for (final e in entry.value)
                    CheckboxListTile(
                      value: _selected.contains(e.equipmentId),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(e.equipmentId);
                        } else {
                          _selected.remove(e.equipmentId);
                        }
                      }),
                      title: Text(
                        e.serialNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(e.modelName),
                    ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Mô tả sự cố',
              children: [
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: máy không lên nguồn sau khi sạc, màn hình bị sọc...',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Vui lòng mô tả sự cố.' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_images[i].path),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => setState(() => _images.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_images.length < CustomerIncidentFormScreen.maxImages)
                      InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 2),
                              Text('Thêm ảnh', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Người liên hệ tại công ty',
              children: [
                TextFormField(
                  controller: _contactNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Vui lòng nhập người liên hệ.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      RegExp(r'^[0-9+ ]{8,20}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Số điện thoại không hợp lệ.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
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
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
