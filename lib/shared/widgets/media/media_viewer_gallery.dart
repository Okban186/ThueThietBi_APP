import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

import 'in_app_video_player_screen.dart';

class GalleryMediaItem {
  const GalleryMediaItem({
    required this.url,
    this.isVideo = false,
    this.fileName,
    this.sizeBytes,
    this.cacheKey,
  });

  final String url;
  final bool isVideo;
  final String? fileName;
  final int? sizeBytes;
  final String? cacheKey;
}

/// Hiển thị danh sách ảnh (chạm để phóng to toàn màn hình, vuốt chuyển ảnh, không bao giờ lỗi overflow với ảnh dài)
/// & video (chạm để phát trực tiếp ngay trong ứng dụng).
class MediaViewerGallery extends StatelessWidget {
  const MediaViewerGallery({
    super.key,
    required this.items,
    this.thumbSize = 86,
  });

  final List<GalleryMediaItem> items;
  final double thumbSize;

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Mở phát video ngay trong ứng dụng (InAppVideoPlayerScreen).
  static Future<void> openVideo(
    BuildContext context,
    String url, {
    String? title,
  }) {
    return InAppVideoPlayerScreen.open(context, url: url, title: title);
  }

  /// Mở 1 ảnh toàn màn hình (hỗ trợ pinch-to-zoom, chống tràn màn hình tuyệt đối với ảnh dài).
  static void openImageViewer(
    BuildContext context,
    String url, {
    String? title,
    String? cacheKey,
  }) {
    openImageGallery(
      context,
      [GalleryMediaItem(url: url, fileName: title, cacheKey: cacheKey)],
      initialIndex: 0,
    );
  }

  /// Mở bộ sưu tập nhiều ảnh toàn màn hình (vuốt trái/phải, phóng to thu nhỏ mượt, không overflow).
  static void openImageGallery(
    BuildContext context,
    List<GalleryMediaItem> images, {
    int initialIndex = 0,
  }) {
    if (images.isEmpty) return;
    final safeIndex = initialIndex.clamp(0, images.length - 1);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImageGalleryScreen(
          images: images,
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final images = items.where((e) => !e.isVideo).toList();
    final videos = items.where((e) => e.isVideo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: thumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final img = images[idx];
                return GestureDetector(
                  onTap: () =>
                      openImageGallery(context, images, initialIndex: idx),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: img.url,
                          cacheKey: img.cacheKey,
                          width: thumbSize,
                          height: thumbSize,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: thumbSize,
                            height: thumbSize,
                            color: AppColors.surfaceSecondary,
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: thumbSize,
                            height: thumbSize,
                            color: AppColors.surfaceSecondary,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (videos.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 8),
          for (var i = 0; i < videos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openVideo(
                    context,
                    videos[i].url,
                    title: videos[i].fileName ?? 'Video minh chứng #${i + 1}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                videos[i].fileName?.trim().isNotEmpty == true
                                    ? videos[i].fileName!
                                    : 'Video minh chứng #${i + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                [
                                  'Chạm để phát trực tiếp trong ứng dụng',
                                  if (formatBytes(videos[i].sizeBytes)
                                      .isNotEmpty)
                                    formatBytes(videos[i].sizeBytes),
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _FullscreenImageGalleryScreen extends StatefulWidget {
  const _FullscreenImageGalleryScreen({
    required this.images,
    required this.initialIndex,
  });

  final List<GalleryMediaItem> images;
  final int initialIndex;

  @override
  State<_FullscreenImageGalleryScreen> createState() =>
      _FullscreenImageGalleryScreenState();
}

class _FullscreenImageGalleryScreenState
    extends State<_FullscreenImageGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_currentIndex];
    final title = current.fileName?.trim().isNotEmpty == true
        ? current.fileName!
        : widget.images.length > 1
        ? 'Ảnh ${_currentIndex + 1}/${widget.images.length}'
        : 'Xem ảnh';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.images.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1}/${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (idx) => setState(() => _currentIndex = idx),
          itemBuilder: (_, idx) {
            final item = widget.images[idx];
            // SizedBox.expand + BoxFit.contain đảm bảo ảnh rất dài/cao luôn vừa khung màn hình,
            // tuyệt đối không bao giờ xảy ra RenderFlex overflow!
            return SizedBox.expand(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                clipBehavior: Clip.none,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: item.url,
                    cacheKey: item.cacheKey,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
