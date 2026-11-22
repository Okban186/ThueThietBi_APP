import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/user_account.dart';
import '../../providers/user_management_provider.dart';

/// Tạo tài khoản nhân viên (khi [user] null) hoặc sửa thông tin tài khoản.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});

  final UserAccount? user;

  bool get isEditing => user != null;

  /// Mở form, chia sẻ cùng [UserManagementProvider] với màn hình gọi.
  /// Trả về tài khoản sau khi lưu thành công.
  static Future<UserAccount?> open(BuildContext context, {UserAccount? user}) {
    final provider = context.read<UserManagementProvider>();

    return Navigator.of(context).push<UserAccount>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: UserFormScreen(user: user),
        ),
      ),
    );
  }

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9._-]{3,50}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phonePattern = RegExp(r'^[0-9+ ]{8,20}$');

  final _formKey = GlobalKey<FormState>();

  late final _usernameController = TextEditingController();
  late final _passwordController = TextEditingController();
  late final _fullNameController = TextEditingController(text: widget.user?.fullName);
  late final _emailController = TextEditingController(text: widget.user?.email);
  late final _phoneController = TextEditingController(text: widget.user?.phone);
  late final _positionController = TextEditingController(text: widget.user?.position);

  late DateTime? _hireDate = widget.user?.hireDate;
  String? _roleCode;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  // Sau lần bấm lưu đầu tiên, kiểm tra ngay khi người dùng sửa để lỗi tự biến mất.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isStaffAccount => !(widget.user?.isCompanyAccount ?? false);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();

    return value.isEmpty ? null : value;
  }

  Future<void> _pickHireDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Chọn ngày vào làm',
    );

    if (picked != null) setState(() => _hireDate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<UserManagementProvider>();

    try {
      final saved = widget.isEditing
          ? await provider.updateUser(
              id: widget.user!.id,
              fullName: _fullNameController.text.trim(),
              email: _optional(_emailController),
              phone: _optional(_phoneController),
              position: _optional(_positionController),
              hireDate: _hireDate,
            )
          : await provider.createUser(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              fullName: _fullNameController.text.trim(),
              roleCode: _roleCode!,
              email: _optional(_emailController),
              phone: _optional(_phoneController),
              position: _optional(_positionController),
              hireDate: _hireDate,
            );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            widget.isEditing
                ? 'Đã lưu thông tin.'
                : 'Đã tạo tài khoản ${saved.username} (${saved.employeeCode ?? ''}).',
          ),
        ),
      );

      Navigator.of(context).pop(saved);
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
    final roles = context.watch<UserManagementProvider>().assignableRoles;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Sửa thông tin' : 'Tạo tài khoản nhân viên',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!widget.isEditing) ...[
              const _SectionTitle('Thông tin đăng nhập'),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Vui lòng nhập tên đăng nhập.';
                  if (!_usernamePattern.hasMatch(value!.trim())) {
                    return '3–50 ký tự: chữ không dấu, số, dấu . _ -';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').length < 6 ? 'Mật khẩu tối thiểu 6 ký tự.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _roleCode,
                decoration: const InputDecoration(
                  labelText: 'Vai trò *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: [
                  for (final role in roles)
                    DropdownMenuItem(value: role.code, child: Text(role.name)),
                ],
                onChanged: (value) => setState(() => _roleCode = value),
                validator: (value) => value == null ? 'Vui lòng chọn vai trò.' : null,
              ),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
                child: Text(
                  'Mã nhân viên được tạo tự động theo vai trò. '
                  'Tài khoản khách hàng do bộ phận kinh doanh tạo.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const _SectionTitle('Thông tin cá nhân'),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Vui lòng nhập họ tên.';
                if (text.length > 150) return 'Họ tên tối đa 150 ký tự.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                return text.isNotEmpty && !_emailPattern.hasMatch(text)
                    ? 'Email không hợp lệ.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                return text.isNotEmpty && !_phonePattern.hasMatch(text)
                    ? 'Số điện thoại không hợp lệ.'
                    : null;
              },
            ),
            if (_isStaffAccount) ...[
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Thông tin nhân viên'),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: 'Chức vụ',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                validator: (value) =>
                    (value ?? '').trim().length > 100 ? 'Chức vụ tối đa 100 ký tự.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickHireDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày vào làm',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: _hireDate == null
                        ? null
                        : IconButton(
                            tooltip: 'Xóa ngày',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _hireDate = null),
                          ),
                  ),
                  child: Text(
                    _hireDate == null ? 'Chưa chọn' : DateFormatter.date(_hireDate!),
                    style: TextStyle(
                      color: _hireDate == null
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(widget.isEditing ? Icons.save_outlined : Icons.person_add_alt_1_rounded),
              label: Text(widget.isEditing ? 'Lưu thay đổi' : 'Tạo tài khoản'),
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
