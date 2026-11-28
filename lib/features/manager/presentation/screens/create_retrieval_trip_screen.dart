import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

/// Màn hình Manager lập chuyến thu hồi thiết bị cuối kỳ / hết hạn / hủy HĐ (RETRIEVAL):
/// 1) Chọn các hợp đồng còn thiết bị ngoài hiện trường.
/// 2) Chọn ngày giờ xuất phát (08:00 - 18:00) & xem trước lộ trình tối ưu.
/// 3) Chọn KTV trưởng + thành viên (có kiểm tra trùng lịch) và tạo chuyến.
class CreateRetrievalTripScreen extends StatefulWidget {
  const CreateRetrievalTripScreen({
    super.key,
    required this.managerApi,
    this.preselectedContractId,
  });

  final ManagerApi managerApi;
  final String? preselectedContractId;

  static Future<bool?> open(
    BuildContext context, {
    required ManagerApi managerApi,
    String? preselectedContractId,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => CreateRetrievalTripScreen(
        managerApi: managerApi,
        preselectedContractId: preselectedContractId,
      ),
    ),
  );

  @override
  State<CreateRetrievalTripScreen> createState() =>
      _CreateRetrievalTripScreenState();
}

class _CreateRetrievalTripScreenState extends State<CreateRetrievalTripScreen> {
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _previewing = false;
  bool _submitting = false;

  List<Map<String, dynamic>> _contracts = const [];
  final Set<String> _selectedIds = {};

  DateTime _departureDate = DateTime.now();
  TimeOfDay _departureTime = const TimeOfDay(hour: 9, minute: 0);

  Map<String, dynamic>? _routePreview;
  List<Map<String, dynamic>> _technicians = const [];
  String? _leaderStaffId;
  final Set<String> _memberStaffIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.hour >= 17) {
      _departureDate = DateTime(now.year, now.month, now.day + 1);
      _departureTime = const TimeOfDay(hour: 8, minute: 30);
    } else if (now.hour < 8) {
      _departureDate = DateTime(now.year, now.month, now.day);
      _departureTime = const TimeOfDay(hour: 8, minute: 30);
    } else {
      _departureDate = DateTime(now.year, now.month, now.day);
      _departureTime = TimeOfDay(hour: (now.hour + 1).clamp(8, 17), minute: 0);
    }
    _loadInitial();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime get _scheduledStartAt => DateTime(
    _departureDate.year,
    _departureDate.month,
    _departureDate.day,
    _departureTime.hour,
    _departureTime.minute,
  );

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final list = await widget.managerApi.getPendingRetrievalContracts();
      if (!mounted) return;
      setState(() {
        _contracts = list;
        if (widget.preselectedContractId != null) {
          final match = list.where(
            (c) =>
                c['contractId'] == widget.preselectedContractId &&
                c['hasActiveRetrievalTrip'] != true,
          );
          if (match.isNotEmpty) {
            _selectedIds.add(widget.preselectedContractId!);
          }
        }
      });
      await _loadTechAvailability();
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTechAvailability({int durationMinutes = 90}) async {
    try {
      final list = await widget.managerApi.getTechniciansAvailability(
        startAt: _scheduledStartAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return;
      setState(() {
        _technicians = list;
        // Bỏ chọn KTV nếu bị trùng lịch ở khung giờ mới
        final busyIds = list
            .where((t) => t['isAvailable'] != true)
            .map((t) => t['staffId'] as String)
            .toSet();
        if (_leaderStaffId != null && busyIds.contains(_leaderStaffId)) {
          _leaderStaffId = null;
        }
        _memberStaffIds.removeWhere(busyIds.contains);
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDate: _departureDate.isBefore(today) ? today : _departureDate,
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
        _routePreview = null;
      });
      await _loadTechAvailability();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) {
      if (picked.hour < 8 || picked.hour > 18) {
        _msg('Khung giờ xuất phát chỉ từ 08:00 đến 18:00.', isError: true);
        return;
      }
      setState(() {
        _departureTime = picked;
        _routePreview = null;
      });
      await _loadTechAvailability();
    }
  }

  Future<void> _previewRoute() async {
    if (_selectedIds.isEmpty) {
      _msg('Vui lòng chọn ít nhất 1 hợp đồng cần thu hồi.', isError: true);
      return;
    }
    setState(() => _previewing = true);
    try {
      final preview = await widget.managerApi.previewRetrievalTrip(
        contractIds: _selectedIds.toList(),
        scheduledStartAt: _scheduledStartAt,
      );
      if (!mounted) return;
      setState(() => _routePreview = preview);
      final totalMins =
          (preview['totalDurationMinutes'] as num?)?.toInt() ?? 90;
      await _loadTechAvailability(durationMinutes: totalMins);
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      _msg('Vui lòng chọn ít nhất 1 hợp đồng cần thu hồi.', isError: true);
      return;
    }
    if (_leaderStaffId == null) {
      _msg('Vui lòng chọn KTV trưởng phụ trách chuyến thu hồi.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.managerApi.createRetrievalTrip(
        contractIds: _selectedIds.toList(),
        scheduledStartAt: _scheduledStartAt,
        leaderStaffId: _leaderStaffId!,
        memberStaffIds: _memberStaffIds
            .where((id) => id != _leaderStaffId)
            .toList(),
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      _msg(
        'Đã tạo chuyến thu hồi thiết bị (RETRIEVAL) và gửi thông báo tới đội KTV & khách hàng.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final stops = (_routePreview?['stops'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lập chuyến thu hồi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contracts.isEmpty
          ? const AppEmptyView(
              icon: Icons.assignment_return_outlined,
              title: 'Không có hợp đồng cần thu hồi',
              message: 'Các hợp đồng còn thiết bị đang cho thuê ngoài hiện trường (sắp hết hạn, đã hết hạn hoặc hủy HĐ) sẽ hiển thị tại đây.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Chọn hợp đồng cần thu hồi (${_selectedIds.length}/${_contracts.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final c in _contracts) _buildContractTile(c),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Thời gian xuất phát & Lộ trình tối ưu',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 17,
                              ),
                              label: Text(DateFormatter.date(_departureDate)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(
                                Icons.access_time_rounded,
                                size: 17,
                              ),
                              label: Text(
                                '${_departureTime.hour.toString().padLeft(2, '0')}:${_departureTime.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _previewing ? null : _previewRoute,
                          icon: _previewing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.route_rounded, size: 18),
                          label: const Text('Tính lộ trình thu hồi tối ưu'),
                        ),
                      ),
                      if (_routePreview != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng thời lượng dự kiến: ${_routePreview!['totalDurationMinutes']} phút '
                                '(Di chuyển ${_routePreview!['totalTravelMinutes']}p • Tháo dỡ ${_routePreview!['totalInstallMinutes']}p)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final s in stops)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Chặng #${s['stopOrder']}: ${s['label']} (~${s['travelMinutesFromPrevious']}p đi, ~${s['installMinutes']}p tháo)',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Phân công đội Kỹ thuật viên thu hồi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_technicians.isEmpty)
                        const Text(
                          'Không tải được danh sách KTV.',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        for (final tech in _technicians) _buildTechTile(tech),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Ghi chú cho đội thu hồi (tùy chọn)',
                          hintText: 'VD: Liên hệ bảo vệ cổng B, chuẩn bị xe tải nhỏ...',
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _contracts.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.assignment_return_rounded),
                  label: Text(
                    'Tạo chuyến thu hồi (${_selectedIds.length} điểm)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildContractTile(Map<String, dynamic> c) {
    final id = c['contractId'] as String;
    final hasActive = c['hasActiveRetrievalTrip'] == true;
    final isOverdue = c['isOverdue'] == true;
    final isEndingSoon = c['isEndingSoon'] == true;
    final isCancelled = c['isCancelledContract'] == true;
    final daysUntil = (c['daysUntilEndDate'] as num?)?.toInt() ?? 0;
    final outQty = (c['outstandingEquipmentCount'] as num?)?.toInt() ?? 0;
    final endDate = DateTime.parse(c['endDate'] as String);
    final addr = c['pickupAddress'] as String?;

    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primary,
      value: _selectedIds.contains(id),
      onChanged: hasActive
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
                _routePreview = null;
              });
            },
      title: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${c['contractCode']} • ${c['companyName'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          if (hasActive)
            _badge('Đã có lịch thu hồi', AppColors.info, AppColors.infoLight)
          else if (isOverdue)
            _badge(
              'Trễ ${daysUntil.abs()} ngày',
              AppColors.error,
              AppColors.errorLight,
            )
          else if (isCancelled)
            _badge('HĐ hủy', AppColors.error, AppColors.errorLight)
          else if (isEndingSoon)
            _badge(
              daysUntil == 0 ? 'Hết hạn hôm nay' : 'Còn $daysUntil ngày',
              AppColors.warning,
              AppColors.warningLight,
            ),
        ],
      ),
      subtitle: Text(
        [
          'Còn $outQty máy đang thuê',
          'Hết hạn: ${DateFormatter.date(endDate)}',
          if (addr != null && addr.trim().isNotEmpty) addr.trim(),
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTechTile(Map<String, dynamic> t) {
    final staffId = t['staffId'] as String;
    final avail = t['isAvailable'] == true;
    final isLeader = _leaderStaffId == staffId;
    final isMember = _memberStaffIds.contains(staffId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isLeader
            ? AppColors.primaryLight.withValues(alpha: 0.45)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeader
              ? AppColors.primary
              : avail
              ? AppColors.border
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t['fullName'] ?? ''} (${t['employeeCode'] ?? ''})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: avail
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
                Text(
                  avail ? 'Rảnh khung giờ này' : 'Đang bận lịch khác',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: avail ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (avail) ...[
            ChoiceChip(
              label: const Text(
                'Trưởng nhóm',
                style: TextStyle(fontSize: 11.5),
              ),
              selected: isLeader,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _leaderStaffId = staffId;
                    _memberStaffIds.remove(staffId);
                  } else {
                    _leaderStaffId = null;
                  }
                });
              },
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Đi cùng', style: TextStyle(fontSize: 11.5)),
              selected: isMember,
              onSelected: isLeader
                  ? null
                  : (v) {
                      setState(() {
                        if (v) {
                          _memberStaffIds.add(staffId);
                        } else {
                          _memberStaffIds.remove(staffId);
                        }
                      });
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
