import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

class LocalEvidenceFile {
  const LocalEvidenceFile({
    required this.path,
    required this.isVideo,
    required this.sizeBytes,
    required this.name,
  });

  final String path;
  final bool isVideo;
  final int sizeBytes;
  final String name;

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Khối chọn / chụp Ảnh và quay / chọn Video minh chứng (video hỗ trợ tối đa 500 MB).
/// Với máy lỗi riêng lẻ: truyền `allowVideo: false` để chỉ cho chọn/chụp Ảnh.
class EvidenceMediaPicker extends StatelessWidget {
  const EvidenceMediaPicker({
    super.key,
    required this.title,
    required this.files,
    required this.onChanged,
    this.subtitle,
    this.allowVideo = true,
    this.maxFiles = 10,
    this.required = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final List<LocalEvidenceFile> files;
  final ValueChanged<List<LocalEvidenceFile>> onChanged;
  final bool allowVideo;
  final int maxFiles;
  final bool required;
  final bool compact;

  static const int maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoBytes = 500 * 1024 * 1024; // 500 MB

  Future<void> _addFile(
    BuildContext context,
    XFile picked, {
    required bool isVideo,
  }) async {
    final file = File(picked.path);
    final size = await file.length();
    final limit = isVideo ? maxVideoBytes : maxImageBytes;
    if (size > limit) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              isVideo
                  ? 'Video vượt quá giới hạn 500 MB.'
                  : 'Ảnh vượt quá giới hạn 10 MB.',
            ),
          ),
        );
      }
      return;
    }

    onChanged([
      ...files,
      LocalEvidenceFile(
        path: picked.path,
        isVideo: isVideo,
        sizeBytes: size,
        name: picked.name,
      ),
    ]);
  }

  Future<void> _pickPhotoCamera(BuildContext context) async {
    if (files.length >= maxFiles) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (photo != null && context.mounted) {
      await _addFile(context, photo, isVideo: false);
    }
  }

  Future<void> _pickPhotoGallery(BuildContext context) async {
    final remaining = maxFiles - files.length;
    if (remaining <= 0) return;
    final photos = await ImagePicker().pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (photos.isEmpty) return;

    final next = [...files];
    for (final p in photos.take(remaining)) {
      final size = await File(p.path).length();
      if (size <= maxImageBytes) {
        next.add(
          LocalEvidenceFile(
            path: p.path,
            isVideo: false,
            sizeBytes: size,
            name: p.name,
          ),
        );
      }
    }
    onChanged(next);
  }

  Future<void> _pickVideoCamera(BuildContext context) async {
    if (!allowVideo || files.length >= maxFiles) return;
    final video = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (video != null && context.mounted) {
      await _addFile(context, video, isVideo: true);
    }
  }

  Future<void> _pickVideoGallery(BuildContext context) async {
    if (!allowVideo || files.length >= maxFiles) return;
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video != null && context.mounted) {
      await _addFile(context, video, isVideo: true);
    }
  }

  void _removeAt(int index) {
    final next = [...files]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final canAddMore = files.length < maxFiles;

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
              '${files.length}/$maxFiles tệp',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: required && files.isEmpty
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
              onPressed: canAddMore ? () => _pickPhotoCamera(context) : null,
              icon: const Icon(Icons.camera_alt_outlined, size: 17),
              label: const Text('Chụp ảnh'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
              onPressed: canAddMore ? () => _pickPhotoGallery(context) : null,
              icon: const Icon(Icons.photo_library_outlined, size: 17),
              label: const Text('Chọn ảnh'),
            ),
            if (allowVideo) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                ),
                onPressed: canAddMore ? () => _pickVideoCamera(context) : null,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Quay video'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                ),
                onPressed: canAddMore ? () => _pickVideoGallery(context) : null,
                icon: const Icon(Icons.video_library_outlined, size: 17),
                label: const Text('Chọn video'),
              ),
            ],
          ],
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: compact ? 80 : 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final item = files[idx];
                final size = compact ? 80.0 : 92.0;
                return Stack(
                  children: [
                    if (!item.isVideo)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(item.path),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: size + 26,
                        height: size,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_filled_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              item.sizeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
