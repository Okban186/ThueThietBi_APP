import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thuethietbi_app/core/network/api_error_message.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:thuethietbi_app/features/equipment/presentation/providers/storekeeper_equipment_provider.dart';

class ModelExcelImportSheet extends StatefulWidget {
  const ModelExcelImportSheet({super.key, required this.provider});

  final StorekeeperEquipmentProvider provider;

  static Future<bool?> open(
    BuildContext context,
    StorekeeperEquipmentProvider provider,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => ModelExcelImportSheet(provider: provider),
    );
  }

  @override
  State<ModelExcelImportSheet> createState() => _ModelExcelImportSheetState();
}

class _ModelExcelImportSheetState extends State<ModelExcelImportSheet> {
  bool _downloading = false;
  bool _uploading = false;
  String? _savedTemplateInfo;
  String? _savedTemplatePath;
  Map<String, dynamic>? _result;

  Future<void> _downloadTemplate() async {
    setState(() {
      _downloading = true;
      _savedTemplateInfo = null;
      _savedTemplatePath = null;
    });

    try {
      final bytes = await widget.provider.api.downloadModelImportTemplate();
      if (bytes.isEmpty) {
        throw Exception('File Excel mẫu trả về rỗng.');
      }

      const fileName = 'MauNhap_EquipmentModel.xlsx';
      String? savedPath;

      // Ưu tiên hộp thoại Lưu file của hệ điều hành (chọn thư mục Downloads / Documents...)
      try {
        final savedUri = await FilePicker.saveFile(
          dialogTitle: 'Lưu file Excel mẫu',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['xlsx'],
          bytes: bytes,
        );
        savedPath = savedUri?.toString();

        // Người dùng bấm Hủy trên hộp thoại lưu
        if (savedPath == null) {
          if (mounted) {
            setState(() => _savedTemplateInfo = 'Bạn đã hủy lưu file mẫu.');
          }
          return;
        }

        // Trên Desktop (Linux/Windows/macOS), saveFile chỉ trả về đường dẫn nên cần ghi bytes ra file
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          final targetFile = File(savedPath);
          await targetFile.writeAsBytes(bytes, flush: true);
        }
      } catch (_) {
        // Fallback nếu thiết bị không hỗ trợ saveFile dialog: lưu vào thư mục tài liệu của app
        final dir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${dir.path}/$fileName');
        await fallbackFile.writeAsBytes(bytes, flush: true);
        savedPath = fallbackFile.path;
      }

      if (!mounted) return;

      String openMsg = 'Đã lưu file mẫu thành công tại:\n$savedPath';
      if (savedPath.isNotEmpty && File(savedPath).existsSync()) {
        final openRes = await OpenFilex.open(savedPath);
        if (openRes.type != ResultType.done) {
          openMsg =
              'Đã lưu file mẫu tại:\n$savedPath\n(Thiết bị chưa có ứng dụng đọc .xlsx, bạn có thể mở trực tiếp từ thư mục trên.)';
        }
      }

      if (mounted) {
        setState(() {
          _savedTemplatePath = savedPath;
          _savedTemplateInfo = openMsg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Không tải được file Excel mẫu.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickAndImport() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );

    if (file == null) return;
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không đọc được nội dung file Excel đã chọn.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _uploading = true;
      _result = null;
    });

    try {
      final res = await widget.provider.api.importModelsFromExcel(
        filePath: kIsWeb ? null : file.path,
        bytes: bytes,
        fileName: file.name,
      );
      await widget.provider.loadModels();
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Import file Excel thất bại.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdCount = (_result?['createdCount'] as num?)?.toInt() ?? 0;
    final failedCount = (_result?['failedCount'] as num?)?.toInt() ?? 0;
    final errors = (_result?['errors'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Import Model thiết bị từ Excel (.xlsx)',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, createdCount > 0),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'File mẫu có đủ 11 cột như form nhập tay (trừ ảnh). Cột Mã Model để trống sẽ tự sinh theo Hãng + Số hiệu + số ngẫu nhiên; cột Thông số kỹ thuật nhập dạng JSON.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _downloading || _uploading
                    ? null
                    : _downloadTemplate,
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text('Bước 1: Tải & Lưu file Excel mẫu (.xlsx)'),
              ),
              if (_savedTemplateInfo != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _savedTemplateInfo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_savedTemplatePath != null &&
                          File(_savedTemplatePath!).existsSync())
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                OpenFilex.open(_savedTemplatePath!),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                            ),
                            label: const Text('Mở lại file mẫu'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _uploading || _downloading ? null : _pickAndImport,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: const Text('Bước 2: Chọn file .xlsx & Import ngay'),
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: failedCount == 0
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết quả: Đã tạo thành công $createdCount model • Lỗi $failedCount dòng',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: failedCount == 0
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      if (errors.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: errors.length,
                            itemBuilder: (_, i) {
                              final err = errors[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• Dòng ${err['rowNumber']} (${err['name'] ?? err['code'] ?? 'Trống'}): ${err['message']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(context, createdCount > 0),
                  child: const Text('Hoàn tất'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
