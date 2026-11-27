import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/core/widgets/app_empty_view.dart';
import 'package:thuethietbi_app/core/widgets/app_filter_chip.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

import 'equipment_history_screen.dart';
import 'equipment_unit_form_screen.dart';

class ModelEquipmentListScreen extends StatefulWidget {
  const ModelEquipmentListScreen({
    super.key,
    required this.provider,
    required this.modelId,
    required this.modelName,
  });

  final StorekeeperEquipmentProvider provider;
  final String modelId;
  final String modelName;

  static Future<void> open(
    BuildContext context, {
    required StorekeeperEquipmentProvider provider,
    required String modelId,
    required String modelName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelEquipmentListScreen(
          provider: provider,
          modelId: modelId,
          modelName: modelName,
        ),
      ),
    );
  }

  @override
  State<ModelEquipmentListScreen> createState() =>
      _ModelEquipmentListScreenState();
}

class _ModelEquipmentListScreenState extends State<ModelEquipmentListScreen> {
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  final List<dynamic> _items = [];
  int _page = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String _keyword = '';
  String? _statusFilter;

  static const _statuses = <(String?, String)>[
    (null, 'Tất cả'),
    ('AVAILABLE', 'Khả dụng'),
    ('RENTED', 'Đang thuê'),
    ('RESERVED', 'Giữ chỗ'),
    ('MAINTENANCE', 'Bảo trì'),
    ('DAMAGED', 'Hỏng'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final res = await widget.provider.api.getEquipmentsPaged(
        modelId: widget.modelId,
        keyword: _keyword,
        status: _statusFilter,
        page: 1,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _totalCount = res.totalCount;
        _hasMore = res.hasMore;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: 'Không tải được danh sách thiết bị.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await widget.provider.api.getEquipmentsPaged(
        modelId: widget.modelId,
        keyword: _keyword,
        status: _statusFilter,
        page: nextPage,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(res.items);
        _totalCount = res.totalCount;
        _hasMore = res.hasMore;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.modelName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '$_totalCount thiết bị',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) {
                    _keyword = v;
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      _loadFirstPage,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm theo số Serial...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final (val, label) = _statuses[i];
                      return AppFilterChip(
                        label: label,
                        selected: _statusFilter == val,
                        onTap: () {
                          setState(() => _statusFilter = val);
                          _loadFirstPage();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const AppEmptyView(
                      icon: Icons.inventory_2_outlined,
                      title: 'Không có thiết bị',
                      message: 'Không tìm thấy thiết bị nào khớp bộ lọc.',
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      itemCount: _items.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        if (i == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final eq = _items[i];
                        final st = eq['status'] as String;
                        final canEdit =
                            widget.provider.isLeadStorekeeper &&
                            st != 'RENTED' &&
                            st != 'RESERVED';

                        return Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => EquipmentHistoryScreen.open(
                              ctx,
                              api: widget.provider.api,
                              equipmentId: eq['id'] as String,
                              serialHint: eq['serialNumber'] as String?,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Icon(
                                      Icons.qr_code_2_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          eq['serialNumber'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        Text(
                                          '${eq['warehouseName']} • Tình trạng: ${eq['condition']} • Chạm xem lịch sử',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    st,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: st == 'AVAILABLE'
                                          ? AppColors.success
                                          : (st == 'DAMAGED'
                                                ? AppColors.error
                                                : AppColors.warning),
                                    ),
                                  ),
                                  if (canEdit)
                                    IconButton(
                                      tooltip: 'Sửa thiết bị',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final ok =
                                            await EquipmentUnitFormScreen.open(
                                              ctx,
                                              widget.provider,
                                              existingEquipment: eq,
                                            );
                                        if (ok == true) _loadFirstPage();
                                      },
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
      ),
    );
  }
}
