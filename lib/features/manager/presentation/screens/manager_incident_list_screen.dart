import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

import 'manager_incident_detail_screen.dart';

class ManagerIncidentListScreen extends StatefulWidget {
  const ManagerIncidentListScreen({
    super.key,
    required this.managerApi,
    required this.reloadVersion,
    required this.onChanged,
  });

  final ManagerApi managerApi;
  final int reloadVersion;
  final VoidCallback onChanged;

  @override
  State<ManagerIncidentListScreen> createState() =>
      _ManagerIncidentListScreenState();
}

class _ManagerIncidentListScreenState extends State<ManagerIncidentListScreen> {
  String? _statusFilter;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  static const _filters = <(String?, String)>[
    (null, 'Tất cả'),
    ('OPEN', 'Mới mở'),
    ('REMOTE_SUPPORT', 'Hỗ trợ Online'),
    ('DISPATCHING', 'Đã cử đội'),
    ('ON_SITE', 'Tại hiện trường'),
    ('RESOLVED', 'Đã xử lý'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ManagerIncidentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.managerApi.getIncidents(status: _statusFilter);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (code, label) in _filters)
                  AppFilterChip(
                    label: label,
                    selected: _statusFilter == code,
                    onTap: () {
                      setState(() => _statusFilter = code);
                      _load();
                    },
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AppEmptyView(
                        icon: Icons.error_outline_rounded,
                        title: 'Không tải được sự cố',
                        message: _error,
                        action: FilledButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      )
                    : _items.isEmpty
                        ? const AppEmptyView(
                            icon: Icons.support_agent_rounded,
                            title: 'Chưa có yêu cầu sự cố',
                            message:
                                'Yêu cầu báo hỏng thiết bị từ tài khoản khách hàng sẽ hiện tại đây.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final item = _items[i];
                              final status =
                                  item['status'] as String? ?? 'OPEN';
                              final serials =
                                  (item['equipmentSerials'] as List<dynamic>? ??
                                          const <dynamic>[])
                                      .cast<String>();
                              final reportedAt = DateTime.parse(
                                item['reportedAt'] as String,
                              ).toLocal();

                              return Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final changed =
                                        await ManagerIncidentDetailScreen.open(
                                      ctx,
                                      incident: item,
                                      managerApi: widget.managerApi,
                                    );
                                    if (changed == true && mounted) {
                                      _load();
                                      widget.onChanged();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item['incidentCode']} • ${item['companyName']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ),
                                            _statusChip(status),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['description'] as String? ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Báo lúc: ${DateFormatter.dateTime(reportedAt)}${serials.isNotEmpty ? ' • Máy: ${serials.join(', ')}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final (label, fg, bg) = switch (status) {
      'OPEN' => ('Mới mở', AppColors.error, AppColors.errorLight),
      'REMOTE_SUPPORT' => ('Hỗ trợ Online', AppColors.info, AppColors.infoLight),
      'DISPATCHING' => ('Đã cử đội', AppColors.warning, AppColors.warningLight),
      'ON_SITE' => ('Tại hiện trường', AppColors.warning, AppColors.warningLight),
      'RESOLVED' => ('Đã xử lý', AppColors.success, AppColors.successLight),
      _ => (status, AppColors.textSecondary, AppColors.surfaceSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
