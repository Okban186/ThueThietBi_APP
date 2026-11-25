import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/theme/app_spacing.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_scrollable_center.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import '../../../data/datasources/customer_incident_api.dart';
import '../../../data/models/customer_incident.dart';
import '../widgets/incident_status_badge.dart';
import 'customer_incident_detail_screen.dart';

/// Tab "Sự cố" của khách hàng: các sự cố công ty đã báo và tiến độ xử lý.
class CustomerIncidentListScreen extends StatefulWidget {
  const CustomerIncidentListScreen({super.key, required this.api});

  final CustomerIncidentApi api;

  @override
  State<CustomerIncidentListScreen> createState() =>
      CustomerIncidentListScreenState();
}

class CustomerIncidentListScreenState
    extends State<CustomerIncidentListScreen> {
  List<CustomerIncident> _incidents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final incidents = await widget.api.getIncidents();
      if (mounted) setState(() => _incidents = incidents);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            error,
            fallback: 'Không tải được danh sách sự cố.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: reload, child: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading && _incidents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: _error,
          action: FilledButton(onPressed: reload, child: const Text('Thử lại')),
        ),
      );
    }

    if (_incidents.isEmpty) {
      return const AppScrollableCenter(
        child: AppEmptyView(
          icon: Icons.build_circle_outlined,
          title: 'Chưa có sự cố nào',
          message: 'Khi máy đang thuê gặp vấn đề, bấm "Báo sự cố" để bên cho thuê hỗ trợ.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        96,
      ),
      itemCount: _incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final incident = _incidents[index];

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            onTap: () async {
              await CustomerIncidentDetailScreen.open(
                context,
                widget.api,
                incident.id,
              );
              reload();
            },
            child: Ink(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          incident.incidentCode,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IncidentStatusBadge(status: incident.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${incident.itemCount} máy · Báo lúc ${DateFormatter.dateTime(incident.reportedAt)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
