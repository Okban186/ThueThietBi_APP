import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

class ManagerScheduleScreen extends StatefulWidget {
  const ManagerScheduleScreen({
    super.key,
    required this.managerApi,
    required this.reloadVersion,
  });

  final ManagerApi managerApi;
  final int reloadVersion;

  @override
  State<ManagerScheduleScreen> createState() => _ManagerScheduleScreenState();
}

class _ManagerScheduleScreenState extends State<ManagerScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedStaffId;
  List<Map<String, dynamic>> _technicians = const [];
  List<Map<String, dynamic>> _schedules = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(covariant ManagerScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) {
      _loadSchedule();
    }
  }

  Future<void> _initData() async {
    try {
      final techs = await widget.managerApi.getTechniciansAvailability();
      if (mounted) setState(() => _technicians = techs);
    } catch (_) {}
    await _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.managerApi.getDailySchedule(
        _selectedDate,
        staffId: _selectedStaffId,
      );
      if (mounted) setState(() => _schedules = list);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtHm(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final baseDay = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormatter.weekdayDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Chọn ngày'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: baseDay.subtract(const Duration(days: 30)),
                        lastDate: baseDay.add(const Duration(days: 90)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                        _loadSchedule();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = baseDay.add(Duration(days: i));
                    final isSelected = d.year == _selectedDate.year &&
                        d.month == _selectedDate.month &&
                        d.day == _selectedDate.day;
                    const wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedDate = d);
                        _loadSchedule();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              wd[d.weekday - 1],
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isSelected
                                    ? AppColors.onPrimarySecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey(_selectedStaffId),
                initialValue: _selectedStaffId,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Lọc theo Kỹ thuật viên',
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả đội kỹ thuật'),
                  ),
                  for (final t in _technicians)
                    DropdownMenuItem<String?>(
                      value: t['staffId'] as String,
                      child: Text('${t['fullName']} (${t['employeeCode']})'),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _selectedStaffId = v);
                  _loadSchedule();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadSchedule,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AppEmptyView(
                        icon: Icons.error_outline_rounded,
                        title: 'Lỗi tải lịch trình',
                        message: _error,
                        action: FilledButton(
                          onPressed: _loadSchedule,
                          child: const Text('Thử lại'),
                        ),
                      )
                    : _schedules.isEmpty
                        ? const AppEmptyView(
                            icon: Icons.event_available_rounded,
                            title: 'Chưa có lịch điều phối',
                            message:
                                'Ngày này chưa có chuyến giao hoặc lịch xử lý sự cố nào.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                            itemCount: _schedules.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _buildScheduleCard(_schedules[i]),
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'HANDOVER';
    final status = item['status'] as String? ?? 'PENDING';
    final start = _fmtHm(item['scheduledStartAt'] as String);
    final end = _fmtHm(item['scheduledEndAt'] as String);
    final duration = (item['estimatedDurationMinutes'] as num?)?.toInt() ?? 0;
    final leader = item['leaderName'] as String? ?? '';
    final members = (item['memberNames'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>();
    final stops = (item['stops'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    final typeColor = type == 'INCIDENT' ? AppColors.error : AppColors.primary;
    final typeLabel = switch (type) {
      'HANDOVER' => 'GIAO LẮP',
      'INCIDENT' => 'SỰ CỐ',
      'MAINTENANCE' => 'BẢO TRÌ',
      'RETRIEVAL' => 'THU HỒI',
      _ => type,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$start – $end ($duration phút)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: status == 'COMPLETED'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] as String? ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Đội trưởng: $leader${members.isNotEmpty ? ' • TV: ${members.join(', ')}' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (stops.isNotEmpty) ...[
            const Divider(height: 16),
            for (final s in stops)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        '${s['stopOrder']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s['contractCode']} • ${s['companyName']}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Đi ${s['estimatedTravelMinutes']}p • Lắp ${s['estimatedInstallMinutes']}p',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
