import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/data/models/category.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

class CategoryWarehouseScreen extends StatefulWidget {
  const CategoryWarehouseScreen({
    super.key,
    required this.provider,
    this.initialTab = 0,
  });

  final StorekeeperEquipmentProvider provider;
  final int initialTab;

  static Future<void> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider, {
    int initialTab = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryWarehouseScreen(provider: provider),
      ),
    );
  }

  @override
  State<CategoryWarehouseScreen> createState() =>
      _CategoryWarehouseScreenState();
}

class _CategoryWarehouseScreenState extends State<CategoryWarehouseScreen> {
  Future<void> _showCategoryDialog({Category? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedStatus = existing?.status ?? 'ACTIVE';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm danh mục mới' : 'Chỉnh sửa danh mục',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Mã: ${existing.code}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên danh mục *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('Đang hoạt động (ACTIVE)'),
                    ),
                    DropdownMenuItem(
                      value: 'INACTIVE',
                      child: Text('Ngừng hoạt động (INACTIVE)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final trimmedName = nameCtrl.text.trim();
                if (trimmedName.isEmpty) return;
                final isDuplicate = widget.provider.categories.any(
                  (c) =>
                      c.id != existing?.id &&
                      c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
                );
                if (isDuplicate) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Tên danh mục đã tồn tại, vui lòng đặt tên khác.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  if (existing != null) 'status': selectedStatus,
                };
                try {
                  if (existing == null) {
                    await widget.provider.api.createCategory(payload);
                  } else {
                    await widget.provider.api.updateCategory(
                      existing.id,
                      payload,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        apiErrorMessage(e, fallback: 'Lưu danh mục thất bại.'),
                      ),
                    ),
                  );
                }
              },
              child: Text(existing == null ? 'Tạo' : 'Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await widget.provider.loadMetadata();
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleStatus(Category c) async {
    final nextStatus = c.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await widget.provider.api.updateCategoryStatus(c.id, nextStatus);
      await widget.provider.loadMetadata();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Không đổi được trạng thái.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.provider.categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục thiết bị')),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.provider.loadMetadata();
          if (mounted) setState(() {});
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final c = categories[i];
            final isActive = c.status == 'ACTIVE';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive
                      ? AppColors.primaryLight
                      : AppColors.surfaceSecondary,
                  child: Icon(
                    Icons.account_tree_rounded,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textDisabled,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${c.code} - ${c.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.successLight
                            : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(c.description ?? 'Không có mô tả'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _showCategoryDialog(existing: c);
                    if (action == 'toggle') _toggleStatus(c);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        isActive
                            ? 'Chuyển sang INACTIVE'
                            : 'Kích hoạt (ACTIVE)',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm danh mục'),
      ),
    );
  }
}
