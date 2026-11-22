import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/auth/auth_session.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/user_account.dart';
import '../../providers/user_management_provider.dart';
import '../widgets/user_badges.dart';
import 'user_form_screen.dart';

/// Chi tiết và thao tác quản trị một tài khoản.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  /// Mở màn hình, chia sẻ cùng [UserManagementProvider] với màn hình gọi.
  static Future<void> open(BuildContext context, String userId) {
    final provider = context.read<UserManagementProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: UserDetailScreen(userId: userId),
        ),
      ),
    );
  }

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isSubmitting = false;

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

  Future<void> _run(Future<void> Function() action, String successMessage) async {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserManagementProvider>();
    final user = provider.findById(widget.userId);
    final currentUserId = context.read<AuthSession>().currentUser?.id;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tài khoản')),
        body: const Center(child: Text('Không tìm thấy tài khoản.')),
      );
    }

    final isSelf = user.id == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết tài khoản',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _isSubmitting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileHeader(user: user, isSelf: isSelf),
            const SizedBox(height: AppSpacing.lg),
            _InfoCard(user: user),
            const SizedBox(height: AppSpacing.lg),
            _ActionsCard(
              children: [
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Sửa thông tin',
                  onTap: () => UserFormScreen.open(context, user: user),
                ),
                _ActionTile(
                  icon: Icons.badge_outlined,
                  title: 'Đổi vai trò',
                  subtitle: isSelf
                      ? 'Không thể tự đổi vai trò của chính mình'
                      : user.isCompanyAccount
                      ? 'Tài khoản khách hàng do bộ phận kinh doanh quản lý'
                      : user.role?.name,
                  enabled: !isSelf && !user.isCompanyAccount,
                  onTap: () => _changeRole(user),
                ),
                _ActionTile(
                  icon: Icons.toggle_on_outlined,
                  title: 'Đổi trạng thái',
                  subtitle: isSelf
                      ? 'Không thể tự đổi trạng thái của chính mình'
                      : user.status.label,
                  enabled: !isSelf,
                  onTap: () => _changeStatus(user),
                ),
                _ActionTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Đặt lại mật khẩu',
                  subtitle: isSelf
                      ? 'Đổi mật khẩu của bạn trong trang tài khoản'
                      : 'Phiên đăng nhập hiện tại của tài khoản sẽ bị đăng xuất',
                  enabled: !isSelf,
                  onTap: () => _resetPassword(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(UserAccount user) async {
    final provider = context.read<UserManagementProvider>();

    final roleCode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: user.role?.code,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetTitle('Chọn vai trò'),
              for (final role in provider.assignableRoles)
                RadioListTile<String>(
                  value: role.code,
                  title: Text(role.name),
                  subtitle: role.description == null ? null : Text(role.description!),
                ),
            ],
          ),
        ),
      ),
    );

    if (roleCode == null || roleCode == user.role?.code) return;

    await _run(
      () => provider.updateRole(user.id, roleCode),
      'Đã đổi vai trò.',
    );
  }

  Future<void> _changeStatus(UserAccount user) async {
    final provider = context.read<UserManagementProvider>();

    final status = await showModalBottomSheet<UserAccountStatus>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<UserAccountStatus>(
          groupValue: user.status,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetTitle('Trạng thái tài khoản'),
              RadioListTile(
                value: UserAccountStatus.active,
                title: Text('Hoạt động'),
                subtitle: Text('Được đăng nhập và sử dụng ứng dụng'),
              ),
              RadioListTile(
                value: UserAccountStatus.inactive,
                title: Text('Ngừng hoạt động'),
                subtitle: Text('Ví dụ nhân viên đã nghỉ việc'),
              ),
              RadioListTile(
                value: UserAccountStatus.locked,
                title: Text('Khóa'),
                subtitle: Text('Tạm khóa, không được đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );

    if (status == null || status == user.status || !mounted) return;

    if (status != UserAccountStatus.active) {
      final confirmed = await _confirm(
        title: '${status == UserAccountStatus.locked ? 'Khóa' : 'Ngừng hoạt động'} tài khoản?',
        message:
            '${user.fullName} sẽ bị đăng xuất ngay và không thể đăng nhập cho đến khi được mở lại.',
        confirmLabel: 'Xác nhận',
      );

      if (!confirmed) return;
    }

    await _run(
      () => provider.updateStatus(user.id, status),
      'Đã chuyển sang "${status.label}".',
    );
  }

  Future<void> _resetPassword(UserAccount user) async {
    final provider = context.read<UserManagementProvider>();

    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(fullName: user.fullName),
    );

    if (newPassword == null) return;

    await _run(
      () => provider.resetPassword(user.id, newPassword),
      'Đã đặt lại mật khẩu. Hãy gửi mật khẩu mới cho ${user.fullName}.',
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.isSelf});

  final UserAccount user;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          UserAvatar(user: user, radius: 30),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? '${user.fullName} (bạn)' : user.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    UserRoleBadge(role: user.role),
                    UserStatusBadge(status: user.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?)>[
      if (user.employeeCode != null)
        (Icons.qr_code_2_rounded, 'Mã nhân viên', user.employeeCode),
      if (user.companyName != null)
        (Icons.business_outlined, 'Công ty', user.companyName),
      (Icons.work_outline_rounded, 'Chức vụ', user.position),
      (Icons.email_outlined, 'Email', user.email),
      (Icons.phone_outlined, 'Số điện thoại', user.phone),
      (
        Icons.event_outlined,
        'Ngày vào làm',
        user.hireDate == null ? null : DateFormatter.date(user.hireDate!),
      ),
      (
        Icons.login_rounded,
        'Đăng nhập gần nhất',
        user.lastLoginAt == null ? 'Chưa đăng nhập' : DateFormatter.relative(user.lastLoginAt!),
      ),
      (Icons.schedule_rounded, 'Ngày tạo', DateFormatter.date(user.createdAt.toLocal())),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      value ?? '—',
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

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      iconColor: AppColors.primary,
      onTap: onTap,
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.fullName});

  final String fullName;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đặt lại mật khẩu'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mật khẩu mới cho ${widget.fullName}. Phiên đăng nhập hiện tại của tài khoản này sẽ bị đăng xuất.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) =>
                  (value ?? '').length < 6 ? 'Mật khẩu tối thiểu 6 ký tự.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
              validator: (value) =>
                  value != _passwordController.text ? 'Mật khẩu nhập lại không khớp.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _passwordController.text);
            }
          },
          child: const Text('Đặt lại'),
        ),
      ],
    );
  }
}
