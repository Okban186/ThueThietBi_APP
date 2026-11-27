import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

/// Khối chọn / chụp ảnh minh chứng dùng chung cho các luồng KTV (hiện trường, máy lỗi, giao thất bại, bảo trì, sự cố).
class EvidencePhotoPicker extends StatelessWidget {
  const EvidencePhotoPicker({
    super.key,
    required this.title,
    required this.filePaths,
    required this.onChanged,
    this.subtitle,
    this.maxPhotos = 10,
    this.required = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final List<String> filePaths;
  final ValueChanged<List<String>> onChanged;
  final int maxPhotos;
  final bool required;
  final bool compact;

  Future<void> _pickFromCamera(BuildContext context) async {
    if (filePaths.length >= maxPhotos) return;
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (photo != null) {
      onChanged([...filePaths, photo.path]);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final remaining = maxPhotos - filePaths.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final photos = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (photos.isEmpty) return;
    final added = photos.take(remaining).map((e) => e.path).toList();
    onChanged([...filePaths, ...added]);
  }

  void _removeAt(int index) {
    final next = [...filePaths]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final canAddMore = filePaths.length < maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                required ? '$title *' : title,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${filePaths.length}/$maxPhotos ảnh',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: required && filePaths.isEmpty
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
              onPressed: canAddMore ? () => _pickFromCamera(context) : null,
              icon: const Icon(Icons.camera_alt_outlined, size: 17),
              label: const Text('Chụp ảnh'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
              onPressed: canAddMore ? () => _pickFromGallery(context) : null,
              icon: const Icon(Icons.photo_library_outlined, size: 17),
              label: const Text('Chọn từ máy'),
            ),
          ],
        ),
        if (filePaths.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: compact ? 74 : 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final size = compact ? 74.0 : 88.0;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(filePaths[idx]),
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () => _removeAt(idx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
