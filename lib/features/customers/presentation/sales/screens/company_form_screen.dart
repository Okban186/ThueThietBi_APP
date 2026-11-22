import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';

import '../../../data/models/company.dart';
import '../../providers/company_provider.dart';
import 'company_detail_screen.dart';

/// Tạo công ty khách hàng (khi [company] null) hoặc sửa thông tin công ty.
class CompanyFormScreen extends StatefulWidget {
  const CompanyFormScreen({super.key, this.company});

  final Company? company;

  bool get isEditing => company != null;

  /// Mở form, chia sẻ cùng [CompanyProvider] với màn hình gọi.
  static Future<void> open(BuildContext context, {Company? company}) {
    final provider = context.read<CompanyProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: CompanyFormScreen(company: company),
        ),
      ),
    );
  }

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  static final _taxCodePattern = RegExp(r'^\d{10}(-\d{3})?$');

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.company?.name,
  );
  late final _taxCodeController = TextEditingController(
    text: widget.company?.taxCode,
  );
  late final _addressController = TextEditingController(
    text: widget.company?.address,
  );

  bool _isSubmitting = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _taxCodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CompanyProvider>();
    final address = _addressController.text.trim();

    try {
      final detail = widget.isEditing
          ? await provider.updateCompany(
              id: widget.company!.id,
              name: _nameController.text.trim(),
              taxCode: _taxCodeController.text.trim(),
              address: address.isEmpty ? null : address,
            )
          : await provider.createCompany(
              name: _nameController.text.trim(),
              taxCode: _taxCodeController.text.trim(),
              address: address.isEmpty ? null : address,
            );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.isEditing
                ? 'Đã lưu thông tin công ty.'
                : 'Đã thêm ${detail.company.name} (${detail.company.companyCode}).',
          ),
        ),
      );

      if (widget.isEditing) {
        navigator.pop();
      } else {
        // Thay form bằng màn hình chi tiết để tạo tài khoản đăng nhập ngay.
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: CompanyDetailScreen(companyId: detail.company.id),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Sửa thông tin công ty' : 'Thêm khách hàng',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                  'Mã công ty: ${widget.company!.companyCode}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên công ty *',
                hintText: 'Ví dụ: Công ty TNHH ABC',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Vui lòng nhập tên công ty.';
                if (text.length > 255) return 'Tên công ty tối đa 255 ký tự.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _taxCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã số thuế *',
                hintText: '0101234567 hoặc 0101234567-001',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Vui lòng nhập mã số thuế.';
                if (!_taxCodePattern.hasMatch(text)) {
                  return 'Mã số thuế gồm 10 chữ số (chi nhánh: thêm -XXX).';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 4,
              validator: (value) => (value ?? '').trim().length > 500
                  ? 'Địa chỉ tối đa 500 ký tự.'
                  : null,
            ),
            if (!widget.isEditing)
              const Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.sm,
                  left: AppSpacing.xs,
                ),
                child: Text(
                  'Mã công ty được tạo tự động. Sau khi lưu, bạn có thể tạo tài khoản '
                  'đăng nhập cho người của công ty.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
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
                          : Icons.add_business_outlined,
                    ),
              label: Text(
                widget.isEditing ? 'Lưu thay đổi' : 'Thêm khách hàng',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
