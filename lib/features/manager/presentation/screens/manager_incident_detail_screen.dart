import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/shared/widgets/media/media_viewer_gallery.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

class ManagerIncidentDetailScreen extends StatefulWidget {
  const ManagerIncidentDetailScreen({
    super.key,
    required this.incident,
    required this.managerApi,
  });

  final Map<String, dynamic> incident;
  final ManagerApi managerApi;

  static Future<bool?> open(
    BuildContext context, {
    required Map<String, dynamic> incident,
    required ManagerApi managerApi,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManagerIncidentDetailScreen(
          incident: incident,
          managerApi: managerApi,
        ),
      ),
    );
  }

  @override
  State<ManagerIncidentDetailScreen> createState() =>
      _ManagerIncidentDetailScreenState();
}

class _ManagerIncidentDetailScreenState
    extends State<ManagerIncidentDetailScreen> {
  bool _submitting = false;

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openRemoteAssignSheet() async {
    List<Map<String, dynamic>> techs;
    try {
      techs = await widget.managerApi.getTechniciansAvailability();
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
      return;
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<({String staffId, String note})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RemoteAssignSheet(
        technicians: techs,
        initialStaffId: widget.incident['remoteTechnicianStaffId'] as String?,
      ),
    );

    if (result != null && mounted) {
      setState(() => _submitting = true);
      try {
        await widget.managerApi.assignRemoteIncident(
          widget.incident['id'] as String,
          result.staffId,
          note: result.note,
        );
        if (mounted) {
          _msg('Đã giao hỗ trợ Online và gửi thông tin khách hàng cho KTV.');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) _msg(apiErrorMessage(e), isError: true);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openDispatchTeamSheet() async {
    final result = await showModalBottomSheet<
        ({
          DateTime scheduledStartAt,
          int durationMinutes,
          String leaderStaffId,
          List<String> memberStaffIds,
          String note,
        })>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DispatchTeamSheet(
        managerApi: widget.managerApi,
        onError: (err) => _msg(err, isError: true),
      ),
    );

    if (result != null && mounted) {
      setState(() => _submitting = true);
      try {
        await widget.managerApi.dispatchIncidentTeam(
          incidentId: widget.incident['id'] as String,
          scheduledStartAt: result.scheduledStartAt,
          durationMinutes: result.durationMinutes,
          leaderStaffId: result.leaderStaffId,
          memberStaffIds: result.memberStaffIds,
          note: result.note,
        );
        if (mounted) {
          _msg('Đã cử đội kỹ thuật tới hiện trường!');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) _msg(apiErrorMessage(e), isError: true);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.incident;
    final status = i['status'] as String? ?? 'OPEN';
    final canAct = status == 'OPEN' || status == 'REMOTE_SUPPORT';
    final urls = (i['attachmentUrls'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>();
    final serials =
        (i['equipmentSerials'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          i['incidentCode'] as String? ?? 'Chi tiết sự cố',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i['companyName'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trạng thái: $status',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Người liên hệ: ${i['contactName'] ?? '---'} • SĐT: ${i['contactPhone'] ?? '---'}',
                ),
                if (i['remoteTechnicianName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'KTV đang hỗ trợ Online: ${i['remoteTechnicianName']}',
                      style: const TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Divider(height: 18),
                const Text(
                  'Mô tả từ khách hàng:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(i['description'] as String? ?? ''),
                if ((i['resolution'] as String?)?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: status == 'OPEN'
                          ? AppColors.warningLight
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (status == 'OPEN'
                                ? AppColors.warning
                                : AppColors.success)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == 'OPEN'
                              ? 'Phản hồi từ KTV hỗ trợ từ xa:'
                              : 'Kết quả xử lý:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: status == 'OPEN'
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (i['resolution'] as String).trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (serials.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sn in serials)
                        Chip(
                          label: Text(sn, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.primaryLight,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hình ảnh hiện trường khách gửi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  MediaViewerGallery(
                    thumbSize: 110,
                    items: [
                      for (var idx = 0; idx < urls.length; idx++)
                        GalleryMediaItem(
                          url: urls[idx],
                          fileName: 'Ảnh sự cố #${idx + 1}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: !canAct
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 44,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.headset_mic_rounded,
                                size: 18,
                              ),
                              label: Text(
                                status == 'REMOTE_SUPPORT'
                                    ? 'Đổi KTV Online'
                                    : 'Hỗ trợ Online',
                              ),
                              onPressed: _openRemoteAssignSheet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              icon: const Icon(
                                Icons.engineering_rounded,
                                size: 18,
                              ),
                              label: const Text('Cử đội trực tiếp'),
                              onPressed: _openDispatchTeamSheet,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }
}

class _RemoteAssignSheet extends StatefulWidget {
  const _RemoteAssignSheet({
    required this.technicians,
    this.initialStaffId,
  });

  final List<Map<String, dynamic>> technicians;
  final String? initialStaffId;

  @override
  State<_RemoteAssignSheet> createState() => _RemoteAssignSheetState();
}

class _RemoteAssignSheetState extends State<_RemoteAssignSheet> {
  final _noteCtrl = TextEditingController();
  String? _selectedTech;

  @override
  void initState() {
    super.initState();
    _selectedTech = widget.initialStaffId;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giao / Đổi KTV hỗ trợ Online',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hỗ trợ Online linh hoạt, không khóa theo lịch hiện trường. Hệ thống sẽ gửi thông tin khách hàng ngay cho KTV.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: RadioGroup<String>(
              groupValue: _selectedTech,
              onChanged: (v) => setState(() => _selectedTech = v),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in widget.technicians)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: t['staffId'] as String,
                      title: Text(
                        t['fullName'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle:
                          Text('${t['employeeCode']} • ${t['phone'] ?? ''}'),
                    ),
                ],
              ),
            ),
          ),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Ghi chú cho KTV (tùy chọn)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: _selectedTech == null
                ? null
                : () => Navigator.pop(
                      context,
                      (staffId: _selectedTech!, note: _noteCtrl.text.trim()),
                    ),
            child: const Text('Gửi thông tin cho KTV'),
          ),
        ],
      ),
    );
  }
}

class _DispatchTeamSheet extends StatefulWidget {
  const _DispatchTeamSheet({
    required this.managerApi,
    required this.onError,
  });

  final ManagerApi managerApi;
  final ValueChanged<String> onError;

  @override
  State<_DispatchTeamSheet> createState() => _DispatchTeamSheetState();
}

class _DispatchTeamSheetState extends State<_DispatchTeamSheet> {
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _durationMins = 90;
  List<Map<String, dynamic>> _techs = const [];
  final Set<String> _selectedIds = {};
  String? _leaderId;
  bool _checking = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime _buildStart() =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _checkAvail() async {
    final mins = _time.hour * 60 + _time.minute;
    if (mins < 8 * 60 || mins > 18 * 60) {
      widget.onError('Chỉ cử đội xuất phát trong khung 08:00 – 18:00.');
      return;
    }
    setState(() => _checking = true);
    try {
      final list = await widget.managerApi.getTechniciansAvailability(
        startAt: _buildStart(),
        durationMinutes: _durationMins,
      );
      if (mounted) {
        setState(() {
          _techs = list;
          _selectedIds.clear();
          _leaderId = null;
        });
      }
    } catch (e) {
      widget.onError(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const Text(
            'Cử đội kỹ thuật tới hiện trường',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(DateFormatter.date(_date)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 60)),
                    );
                    if (p != null && mounted) setState(() => _date = p);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                  ),
                  onPressed: () async {
                    final p = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (p != null && mounted) setState(() => _time = p);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [60, 90, 120, 180])
                ChoiceChip(
                  label: Text('$m phút'),
                  selected: _durationMins == m,
                  onSelected: (_) => setState(() => _durationMins = m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: _checking ? null : _checkAvail,
            child: Text(_checking ? 'Đang kiểm tra...' : 'Kiểm tra KTV rảnh'),
          ),
          const SizedBox(height: 10),
          for (final t in _techs)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              enabled: t['isAvailable'] == true,
              leading: Checkbox(
                value: _selectedIds.contains(t['staffId']),
                onChanged: t['isAvailable'] == true
                    ? (v) => setState(() {
                          final id = t['staffId'] as String;
                          if (v == true) {
                            _selectedIds.add(id);
                            _leaderId ??= id;
                          } else {
                            _selectedIds.remove(id);
                            if (_leaderId == id) {
                              _leaderId = _selectedIds.isEmpty
                                  ? null
                                  : _selectedIds.first;
                            }
                          }
                        })
                    : null,
              ),
              title: Text(t['fullName'] as String),
              subtitle: Text(
                t['isAvailable'] == true ? 'Rảnh' : 'Bận khung giờ này',
                style: TextStyle(
                  color: t['isAvailable'] == true
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              trailing: _selectedIds.contains(t['staffId'])
                  ? IconButton(
                      icon: Icon(
                        _leaderId == t['staffId']
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _leaderId == t['staffId']
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _leaderId = t['staffId'] as String),
                    )
                  : null,
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Ghi chú xử lý sự cố',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: (_selectedIds.isEmpty || _leaderId == null)
                ? null
                : () => Navigator.pop(
                      context,
                      (
                        scheduledStartAt: _buildStart(),
                        durationMinutes: _durationMins,
                        leaderStaffId: _leaderId!,
                        memberStaffIds:
                            _selectedIds.where((e) => e != _leaderId).toList(),
                        note: _noteCtrl.text.trim(),
                      ),
                    ),
            child: const Text('Xác nhận cử đội'),
          ),
        ],
      ),
    );
  }
}
