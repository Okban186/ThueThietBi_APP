import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/models/equipment_model.dart';

/// Ảnh của model (chỉ xem): vuốt chuyển ảnh, dải ảnh nhỏ bên dưới,
/// chạm để xem toàn màn hình. Ảnh đầu tiên là ảnh đại diện.
class EquipmentImageGallery extends StatefulWidget {
  const EquipmentImageGallery({super.key, required this.images});

  final List<EquipmentModelMedia> images;

  @override
  State<EquipmentImageGallery> createState() => _EquipmentImageGalleryState();
}

class _EquipmentImageGalleryState extends State<EquipmentImageGallery> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant EquipmentImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Tải lại có thể làm số ảnh giảm.
    if (_index >= widget.images.length) {
      _index = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreen(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenGallery(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    if (images.isEmpty) {
      return Container(
        height: 240,
        width: double.infinity,
        color: AppColors.surfaceSecondary,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: 8),
            Text(
              'Chưa có hình ảnh',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(bottom: images.length > 1 ? 12 : 0),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openFullScreen(i),
                    child: EquipmentNetworkImage(
                      media: images[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (images[_index].isPrimary == true)
                  const Positioned(left: 12, top: 12, child: _PrimaryBadge()),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (images.length > 1)
            SizedBox(
              height: 68,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == _index;

                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: EquipmentNetworkImage(
                          media: images[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'Ảnh đại diện',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh model từ URL có chữ ký. URL đổi mỗi lần tải API nên lưu cache theo
/// id file, tránh tải lại cùng một ảnh.
class EquipmentNetworkImage extends StatelessWidget {
  const EquipmentNetworkImage({
    super.key,
    required this.media,
    required this.fit,
    this.placeholder,
  });

  final EquipmentModelMedia media;
  final BoxFit fit;

  /// Hiển thị khi đang tải hoặc lỗi; mặc định là vòng xoay/biểu tượng lỗi.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: media.url!,
      cacheKey: media.storageFileId,
      fit: fit,
      placeholder: (_, _) =>
          placeholder ??
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (_, _, _) =>
          placeholder ??
          const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textDisabled,
            ),
          ),
    );
  }
}

/// Xem ảnh toàn màn hình: vuốt chuyển ảnh, chụm hai ngón để phóng to.
class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<EquipmentModelMedia> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: EquipmentNetworkImage(
              media: widget.images[i],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
