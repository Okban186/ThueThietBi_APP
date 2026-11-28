import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/contracts/data/datasources/rental_contract_api.dart';
import 'package:thuethietbi_app/features/manager/data/datasources/manager_api.dart';
import 'package:thuethietbi_app/shared/formatters/date_formatter.dart';

class CreateDeliveryTripScreen extends StatefulWidget {
  const CreateDeliveryTripScreen({
    super.key,
    required this.managerApi,
    required this.contractApi,
    this.preselectedContractId,
  });

  final ManagerApi managerApi;
  final RentalContractApi contractApi;
  final String? preselectedContractId;

  static Future<bool?> open(
    BuildContext context, {
    required ManagerApi managerApi,
    required RentalContractApi contractApi,
    String? preselectedContractId,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateDeliveryTripScreen(
          managerApi: managerApi,
          contractApi: contractApi,
          preselectedContractId: preselectedContractId,
        ),
      ),
    );
  }

  @override
  State<CreateDeliveryTripScreen> createState() =>
      _CreateDeliveryTripScreenState();
}

class _CreateDeliveryTripScreenState extends State<CreateDeliveryTripScreen> {
  // true = Tạo chuyến mới, false = Ghép vào chuyến PENDING có sẵn
  bool _createNewTrip = true;
  bool _loadingInit = true;
  bool _loadingPreview = false;
  bool _submitting = false;

  List<Map<String, dynamic>> _preparingContracts = const [];
  final Set<String> _selectedContractIds = {};

  DateTime _deliveryDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);

  // Ghép chuyến
  List<Map<String, dynamic>> _mergeableTrips = const [];
  String? _selectedMergeAssignmentId;

  // Kết quả tối ưu lộ trình (Google -> OSRM)
  Map<String, dynamic>? _routePreview;

  // Đội kỹ thuật (cho chế độ tạo chuyến mới)
  List<Map<String, dynamic>> _technicians = const [];
  final Set<String> _selectedStaffIds = {};
  String? _leaderStaffId;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedContractId != null) {
      _selectedContractIds.add(widget.preselectedContractId!);
    }
    _loadInitial();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime get _scheduledStartAt => DateTime(
    _deliveryDate.year,
    _deliveryDate.month,
    _deliveryDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  bool _isWithinWorkingHours(TimeOfDay t) {
    final mins = t.hour * 60 + t.minute;
    return mins >= 8 * 60 && mins <= 18 * 60;
  }

  Future<void> _loadInitial() async {
    setState(() => _loadingInit = true);
    try {
      final results = await Future.wait([
        widget.managerApi.getUnscheduledContracts(),
        widget.managerApi.getMergeableTrips(_deliveryDate),
      ]);
      final unscheduled = results[0];
      final mergeable = results[1];
      final validIds = unscheduled.map((c) => c['id'] as String).toSet();
      if (mounted) {
        setState(() {
          _preparingContracts = unscheduled;
          _mergeableTrips = mergeable;
          _selectedContractIds.removeWhere((id) => !validIds.contains(id));
        });
      }
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingInit = false);
    }
  }

  Future<void> _reloadMergeableTrips() async {
    try {
      final mergeable = await widget.managerApi.getMergeableTrips(
        _deliveryDate,
      );
      if (mounted) {
        setState(() {
          _mergeableTrips = mergeable;
          _selectedMergeAssignmentId = null;
          _routePreview = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _previewRouteAndLoadTechs() async {
    if (_selectedContractIds.isEmpty) {
      _msg('Vui lòng chọn ít nhất 1 hợp đồng cần giao.', isError: true);
      return;
    }

    if (_createNewTrip && !_isWithinWorkingHours(_startTime)) {
      _msg(
        'Chỉ được cử đội xuất phát trong khung giờ 08:00 – 18:00.',
        isError: true,
      );
      return;
    }

    if (!_createNewTrip && _selectedMergeAssignmentId == null) {
      _msg('Vui lòng chọn chuyến đang PENDING muốn ghép vào.', isError: true);
      return;
    }

    setState(() {
      _loadingPreview = true;
      _routePreview = null;
    });

    try {
      final preview = await widget.managerApi.previewDeliveryTrip(
        contractIds: _selectedContractIds.toList(),
        scheduledStartAt: _scheduledStartAt,
        existingAssignmentId: _createNewTrip
            ? null
            : _selectedMergeAssignmentId,
      );

      List<Map<String, dynamic>> techs = const [];
      if (_createNewTrip) {
        final totalMins = (preview['totalDurationMinutes'] as num).toInt();
        techs = await widget.managerApi.getTechniciansAvailability(
          startAt: _scheduledStartAt,
          durationMinutes: totalMins,
        );
      }

      if (!mounted) return;
      setState(() {
        _routePreview = preview;
        _technicians = techs;
        _selectedStaffIds.clear();
        _leaderStaffId = null;
      });
    } catch (e) {
      if (mounted) _msg(apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _submit() async {
    if (_routePreview == null) {
      _msg('Vui lòng bấm "Tính & tối ưu lộ trình" trước.', isError: true);
      return;
    }

    if (_createNewTrip) {
      if (_selectedStaffIds.isEmpty) {
        _msg('Vui lòng chọn ít nhất 1 kỹ thuật viên.', isError: true);
        return;
      }
      if (_leaderStaffId == null ||
          !_selectedStaffIds.contains(_leaderStaffId)) {
        _msg(
          'Vui lòng chọn 1 Đội trưởng (biểu tượng ngôi sao).',
          isError: true,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      if (_createNewTrip) {
        final members = _selectedStaffIds
            .where((id) => id != _leaderStaffId)
            .toList();
        await widget.managerApi.createDeliveryTrip(
          contractIds: _selectedContractIds.toList(),
          scheduledStartAt: _scheduledStartAt,
          leaderStaffId: _leaderStaffId!,
          memberStaffIds: members,
          note: _noteCtrl.text,
        );
      } else {
        await widget.managerApi.mergeIntoDeliveryTrip(
          assignmentId: _selectedMergeAssignmentId!,
          contractIds: _selectedContractIds.toList(),
        );
      }

      if (mounted) {
        _msg(
          _createNewTrip
              ? 'Đã lập chuyến giao & gửi thông báo cho đội!'
              : 'Đã ghép điểm vào chuyến và tối ưu lại lộ trình!',
        );
        Navigator.pop(context, true);
      }
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
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Điều phối chuyến giao hàng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.add_road_rounded, size: 18),
                      label: Text('Tạo chuyến mới'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.merge_rounded, size: 18),
                      label: Text('Ghép chuyến có sẵn'),
                    ),
                  ],
                  selected: {_createNewTrip},
                  onSelectionChanged: (s) {
                    setState(() {
                      _createNewTrip = s.first;
                      _routePreview = null;
                    });
                    if (!_createNewTrip) _reloadMergeableTrips();
                  },
                ),
                const SizedBox(height: 14),
                _section(
                  title:
                      '1. Chọn hợp đồng cần giao (${_selectedContractIds.length})',
                  child: _preparingContracts.isEmpty
                      ? const Text(
                          'Hiện không có hợp đồng PREPARING nào chưa được lên lịch giao.',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      : Column(
                          children: [
                            for (final c in _preparingContracts)
                              Builder(
                                builder: (_) {
                                  final id = c['id'] as String;
                                  final startDate = DateTime.parse(
                                    c['startDate'] as String,
                                  );
                                  final address =
                                      c['deliveryAddress'] as String?;
                                  final qty =
                                      (c['totalQuantity'] as num?)?.toInt() ??
                                      0;
                                  final handoverCode =
                                      c['existingHandoverCode'] as String?;
                                  final handoverType =
                                      (c['handoverType'] as String? ?? 'INITIAL')
                                          .toUpperCase();
                                  final isSupp =
                                      handoverType == 'SUPPLEMENTARY';
                                  final isIncRepl =
                                      handoverType == 'INCIDENT_REPLACEMENT';
                                  final failedCount =
                                      (c['failedAttemptCount'] as num?)
                                          ?.toInt() ??
                                      0;
                                  final failedReason =
                                      c['lastFailedReason'] as String?;

                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.primary,
                                    value: _selectedContractIds.contains(id),
                                    title: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${c['contractCode']} • ${c['companyName'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        if (isSupp)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.warningLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Giao bù',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        if (isIncRepl)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.infoLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Đổi sự cố',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.info,
                                              ),
                                            ),
                                          ),
                                        if (failedCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.errorLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Giao lại (lỗi $failedCount lần)',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          [
                                            'Bắt đầu thuê: ${DateFormatter.date(startDate)} ($qty máy)',
                                            if (handoverCode != null)
                                              'Phiếu: $handoverCode',
                                            if (address != null &&
                                                address.trim().isNotEmpty)
                                              address.trim(),
                                          ].join(' • '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        if (failedReason != null &&
                                            failedReason.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'Lý do thất bại gần nhất: ${failedReason.trim()}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selectedContractIds.add(id);
                                      } else {
                                        _selectedContractIds.remove(id);
                                      }
                                      _routePreview = null;
                                    }),
                                  );
                                },
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: _createNewTrip
                      ? '2. Ngày & giờ xuất phát (08:00 – 18:00)'
                      : '2. Chọn ngày & chuyến PENDING muốn ghép',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                              ),
                              label: Text(DateFormatter.date(_deliveryDate)),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _deliveryDate,
                                  firstDate: DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ),
                                  lastDate: now.add(const Duration(days: 90)),
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _deliveryDate = picked;
                                    _routePreview = null;
                                  });
                                  if (!_createNewTrip) _reloadMergeableTrips();
                                }
                              },
                            ),
                          ),
                          if (_createNewTrip) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _startTime,
                                  );
                                  if (picked != null && mounted) {
                                    if (!_isWithinWorkingHours(picked)) {
                                      _msg(
                                        'Giờ xuất phát phải trong khung 08:00 – 18:00.',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setState(() {
                                      _startTime = picked;
                                      _routePreview = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!_createNewTrip) ...[
                        const SizedBox(height: 10),
                        if (_mergeableTrips.isEmpty)
                          const Text(
                            'Không có chuyến giao PENDING nào trong ngày này để ghép.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          RadioGroup<String>(
                            groupValue: _selectedMergeAssignmentId,
                            onChanged: (v) => setState(() {
                              _selectedMergeAssignmentId = v;
                              _routePreview = null;
                            }),
                            child: Column(
                              children: [
                                for (final t in _mergeableTrips)
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.primary,
                                    value: t['assignmentId'] as String,
                                    title: Text(
                                      t['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Đội trưởng: ${t['leaderName']} • Hiện ${t['currentStopCount']} điểm',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _loadingPreview
                              ? null
                              : _previewRouteAndLoadTechs,
                          icon: _loadingPreview
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_graph_rounded),
                          label: const Text('Tính & tối ưu lộ trình'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_routePreview != null) ...[
                  const SizedBox(height: 12),
                  _buildRouteTimelineCard(_routePreview!),
                ],
                if (_createNewTrip && _routePreview != null) ...[
                  const SizedBox(height: 12),
                  _section(
                    title: '4. Chọn đội kỹ thuật & 1 Đội trưởng (⭐)',
                    child: Column(
                      children: [
                        if (_technicians.isEmpty)
                          const Text(
                            'Không tìm thấy kỹ thuật viên nào đang hoạt động.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          for (final tech in _technicians) _buildTechRow(tech),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Ghi chú cho đội (không bắt buộc)',
                            filled: true,
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: (_submitting || _routePreview == null) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _createNewTrip
                        ? 'Xác nhận tạo chuyến & phân công'
                        : 'Xác nhận ghép vào chuyến',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteTimelineCard(Map<String, dynamic> preview) {
    final provider = preview['provider'] as String? ?? 'OSRM';
    final stops = (preview['stops'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final returnMins = (preview['returnTravelMinutes'] as num?)?.toInt() ?? 0;
    final returnKm = (preview['returnDistanceKm'] as num?)?.toDouble() ?? 0;
    final totalMins = (preview['totalDurationMinutes'] as num?)?.toInt() ?? 0;

    DateTime cursor = _scheduledStartAt;
    if (!_createNewTrip && _selectedMergeAssignmentId != null) {
      for (final trip in _mergeableTrips) {
        if (trip['assignmentId'] == _selectedMergeAssignmentId) {
          cursor = DateTime.parse(trip['scheduledStartAt'] as String).toLocal();
          break;
        }
      }
    }

    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final rows = <Widget>[
      _timelineRow(
        fmt(cursor),
        'Xuất phát từ Kho chính',
        'Nguồn lộ trình: $provider',
        isDepot: true,
      ),
    ];

    for (final s in stops) {
      final travel = (s['travelMinutesFromPrevious'] as num?)?.toInt() ?? 0;
      final km = (s['distanceKmFromPrevious'] as num?)?.toDouble() ?? 0;
      final install = (s['installMinutes'] as num?)?.toInt() ?? 0;
      cursor = cursor.add(Duration(minutes: travel));
      final arriveStr = fmt(cursor);
      cursor = cursor.add(Duration(minutes: install));
      rows.add(
        _timelineRow(
          arriveStr,
          'Điểm #${s['stopOrder']}: ${s['label']}',
          travel == 0 && km == 0
              ? 'Cùng địa chỉ (0km, 0p di chuyển) • Lắp đặt ~${install}p (xong ${fmt(cursor)})'
              : 'Di chuyển ${travel}p (${km}km) • Lắp đặt ~${install}p (xong ${fmt(cursor)})',
        ),
      );
    }

    cursor = cursor.add(Duration(minutes: returnMins));
    final finishStr = fmt(cursor);
    final isOvertime =
        cursor.hour > 18 || (cursor.hour == 18 && cursor.minute > 0);
    rows.add(
      _timelineRow(
        finishStr,
        'Dự kiến về tới Kho',
        'Chặng về ${returnMins}p (${returnKm}km) • Tổng cộng $totalMins phút',
        isDepot: true,
      ),
    );

    return _section(
      title: '3. Lộ trình tối ưu dự kiến',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          if (isOvertime)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lưu ý: Chuyến dự kiến kết thúc lúc $finishStr (sau 18:00), đội sẽ hoàn tất trước khi nghỉ.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineRow(
    String time,
    String title,
    String sub, {
    bool isDepot = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        Icon(
          isDepot ? Icons.warehouse_rounded : Icons.location_on_rounded,
          size: 18,
          color: isDepot ? AppColors.success : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildTechRow(Map<String, dynamic> t) {
    final staffId = t['staffId'] as String;
    final available = t['isAvailable'] as bool? ?? false;
    final selected = _selectedStaffIds.contains(staffId);
    final isLeader = _leaderStaffId == staffId;

    String? busyText;
    if (!available && t['conflictStart'] != null && t['conflictEnd'] != null) {
      final s = DateTime.parse(t['conflictStart'] as String).toLocal();
      final e = DateTime.parse(t['conflictEnd'] as String).toLocal();
      busyText =
          'Bận ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}–${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      enabled: available,
      leading: Checkbox(
        value: selected,
        activeColor: AppColors.primary,
        onChanged: available
            ? (v) => setState(() {
                if (v == true) {
                  _selectedStaffIds.add(staffId);
                  _leaderStaffId ??= staffId;
                } else {
                  _selectedStaffIds.remove(staffId);
                  if (_leaderStaffId == staffId) {
                    _leaderStaffId = _selectedStaffIds.isEmpty
                        ? null
                        : _selectedStaffIds.first;
                  }
                }
              })
            : null,
      ),
      title: Text(
        t['fullName'] as String,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: available ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
      subtitle: Text(
        available
            ? '${t['employeeCode']} • Rảnh'
            : '${t['employeeCode']} • ${busyText ?? 'Trùng lịch'}',
        style: TextStyle(
          fontSize: 12,
          color: available ? AppColors.success : AppColors.error,
        ),
      ),
      trailing: selected
          ? IconButton(
              tooltip: 'Chọn làm Đội trưởng',
              icon: Icon(
                isLeader ? Icons.star_rounded : Icons.star_border_rounded,
                color: isLeader ? AppColors.warning : AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _leaderStaffId = staffId),
            )
          : null,
    );
  }

  Widget _section({required String title, required Widget child}) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
