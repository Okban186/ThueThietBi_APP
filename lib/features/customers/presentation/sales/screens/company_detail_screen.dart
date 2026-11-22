import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/models/company.dart';
import '../../../data/models/company_account.dart';
import '../../providers/company_provider.dart';
import '../widgets/company_status_badge.dart';
import 'company_account_form_screen.dart';
import 'company_form_screen.dart';

/// Chi tiết công ty khách hàng và các tài khoản đăng nhập của công ty.
class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  /// Mở màn hình, chia sẻ cùng [CompanyProvider] với màn hình gọi.
  static Future<void> open(BuildContext context, String companyId) {
    final provider = context.read<CompanyProvider>();

    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: CompanyDetailScreen(companyId: companyId),
        ),
      ),
    );
  }

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

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
      await context.read<CompanyProvider>().loadDetail(widget.companyId);
    } catch (error) {
      _loadError = apiErrorMessage(
        error,
        fallback: 'Không tải được thông tin công ty.',
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

  Future<void> _toggleStatus(Company company) async {
    final provider = context.read<CompanyProvider>();
    final deactivate = company.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          deactivate ? 'Ngừng hoạt động công ty?' : 'Mở lại hoạt động?',
        ),
        content: Text(
          deactivate
              ? '${company.name} sẽ được đánh dấu ngừng hoạt động và không tạo thêm tài khoản được. '
                    'Tài khoản đăng nhập hiện có không bị ảnh hưởng.'
              : '${company.name} sẽ hoạt động trở lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: deactivate
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final status = deactivate ? CompanyStatus.inactive : CompanyStatus.active;
      await provider.updateStatus(company.id, status);
      if (mounted) _showMessage('Đã chuyển sang "${status.label}".');
    } catch (error) {
      if (mounted) _showMessage(apiErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyProvider>();
    final detail = provider.detailOf(widget.companyId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết khách hàng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _isSubmitting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(detail),
    );
  }

  Widget _buildBody(CompanyDetail? detail) {
    if (detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _loadError,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final company = detail.company;

    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeaderCard(company: company),
            if (!company.canEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _ReadOnlyBanner(ownerName: company.createdByName),
            ],
            const SizedBox(height: AppSpacing.lg),
            _InfoCard(company: company),
            const SizedBox(height: AppSpacing.lg),
            _AccountsCard(
              detail: detail,
              onCreate: company.canEdit && company.isActive
                  ? () =>
                        CompanyAccountFormScreen.open(context, company: company)
                  : null,
            ),
            if (company.canEdit) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      iconColor: AppColors.primary,
                      title: const Text(
                        'Sửa thông tin công ty',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          CompanyFormScreen.open(context, company: company),
                    ),
                    ListTile(
                      leading: Icon(
                        company.isActive
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                      ),
                      iconColor: company.isActive
                          ? AppColors.error
                          : AppColors.success,
                      title: Text(
                        company.isActive
                            ? 'Ngừng hoạt động'
                            : 'Mở lại hoạt động',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: company.isActive
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                      onTap: () => _toggleStatus(company),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    return _Section(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company.companyCode,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                CompanyStatusBadge(status: company.companyStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.ownerName});

  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Khách hàng do ${ownerName ?? 'nhân viên khác'} phụ trách. Bạn chỉ có quyền xem.',
              style: const TextStyle(color: AppColors.info, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?)>[
      (Icons.receipt_long_outlined, 'Mã số thuế', company.taxCode),
      (Icons.location_on_outlined, 'Địa chỉ', company.address),
      (Icons.badge_outlined, 'Người tạo', company.createdByName),
      (
        Icons.schedule_rounded,
        'Ngày tạo',
        company.createdAt == null
            ? null
            : DateFormatter.date(company.createdAt!),
      ),
    ];

    return _Section(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 96,
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
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

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({required this.detail, required this.onCreate});

  final CompanyDetail detail;

  /// null: không được tạo (không phải người tạo hoặc công ty ngừng hoạt động).
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final accounts = detail.accounts;

    return _Section(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản đăng nhập (${accounts.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Người của công ty dùng để đăng nhập ứng dụng.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Chưa có tài khoản nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final account in accounts) _AccountRow(account: account),
          if (onCreate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onCreate,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Tạo tài khoản đăng nhập'),
            ),
          ] else if (detail.company.canEdit && !detail.company.isActive) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Mở lại hoạt động để tạo thêm tài khoản.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final CompanyAccount account;

  @override
  Widget build(BuildContext context) {
    final contact = [
      account.phone,
      account.email,
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primaryLight,
            child: Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  contact.isEmpty
                      ? '@${account.username}'
                      : '@${account.username} · $contact',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            account.statusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: account.isActive ? AppColors.success : AppColors.error,
            ),
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
