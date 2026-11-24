import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/customer_incident_api.dart';
import '../../../data/models/customer_incident.dart';
import '../widgets/incident_status_badge.dart';

/// Chi tiết sự cố cho khách: máy, mô tả, ảnh, tiến độ và kết quả xử lý.
/// Khách hủy được khi sự cố còn chờ tiếp nhận.
class CustomerIncidentDetailScreen extends StatefulWidget {
  const CustomerIncidentDetailScreen({
    super.key,
    required this.api,
    required this.incidentId,
  });

  final CustomerIncidentApi api;
  final String incidentId;

  static Future<void> open(
    BuildContext context,
    CustomerIncidentApi api,
    String id,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerIncidentDetailScreen(api: api, incidentId: id),
      ),
    );
  }

  @override
  State<CustomerIncidentDetailScreen> createState() =>
      _CustomerIncidentDetailScreenState();
}

class _CustomerIncidentDetailScreenState
    extends State<CustomerIncidentDetailScreen> {
  CustomerIncidentDetail? _detail;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await widget.api.getIncident(widget.incidentId);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được sự cố.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel(CustomerIncident incident) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hủy ${incident.incidentCode}?'),
        content: const Text('Chỉ hủy khi sự cố đã tự khắc phục hoặc báo nhầm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy sự cố'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _isBusy = true);

    try {
      final detail = await widget.api.cancel(incident.id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(error)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final canCancel = detail?.incident.status == IncidentStatus.open;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.incident.incidentCode ?? 'Sự cố',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(detail),
      bottomNavigationBar: !canCancel
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: _isBusy ? null : () => _cancel(detail!.incident),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Hủy sự cố'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(CustomerIncidentDetail? detail) {
    if (detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail == null) {
      return AppEmptyView(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }

    final i = detail.incident;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.incidentCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IncidentStatusBadge(status: i.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(i.description, style: const TextStyle(height: 1.4)),
                const Divider(height: AppSpacing.xl),
                _InfoRow('Báo lúc', DateFormatter.dateTime(i.reportedAt)),
                _InfoRow('Người báo', i.reportedByName),
                _InfoRow(
                  'Liên hệ',
                  [
                    i.contactName,
                    i.contactPhone,
                  ].whereType<String>().join(' · '),
                ),
                if (i.resolvedAt != null)
                  _InfoRow('Xử lý xong', DateFormatter.dateTime(i.resolvedAt!)),
              ],
            ),
          ),
          if (i.resolution != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
              child: Text(
                'Kết quả xử lý: ${i.resolution}',
                style: const TextStyle(color: AppColors.success, height: 1.35),
              ),
            ),
          ] else if (i.status == IncidentStatus.open) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
              child: const Text(
                'Bên cho thuê đã nhận thông tin và sẽ liên hệ người liên hệ ở trên để hỗ trợ.',
                style: TextStyle(color: AppColors.warning, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Máy gặp sự cố (${detail.items.length})',
            child: Column(
              children: [
                for (final item in detail.items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      item.serialNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        item.modelName,
                        if (item.description != null) item.description!,
                        if (item.assessment != null)
                          'Đánh giá: ${item.assessment}',
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
          ),
          if (detail.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Ảnh (${detail.attachments.length})',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final a in detail.attachments)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: a.url,
                        cacheKey: a.storageFileId,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
