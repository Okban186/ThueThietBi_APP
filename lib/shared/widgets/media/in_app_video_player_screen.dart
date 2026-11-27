import 'package:flutter/material.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Màn hình phát video trực tiếp ngay trong ứng dụng (không mở trình duyệt).
/// Hỗ trợ phát/tạm dừng, tua thanh thời gian, tắt/bật tiếng và có nút dự phòng mở bằng trình phát ngoài.
class InAppVideoPlayerScreen extends StatefulWidget {
  const InAppVideoPlayerScreen({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InAppVideoPlayerScreen(url: url, title: title),
      ),
    );
  }

  @override
  State<InAppVideoPlayerScreen> createState() => _InAppVideoPlayerScreenState();
}

class _InAppVideoPlayerScreenState extends State<InAppVideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _muted = false;
  bool _showControls = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      await _controller.initialize();
      _controller.addListener(_onTick);
      await _controller.play();
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Không thể phát trực tiếp định dạng video này trên ứng dụng.',
        );
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_initialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      final pos = _controller.value.position;
      final dur = _controller.value.duration;
      if (dur > Duration.zero && pos >= dur) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!_initialized) return;
    _muted = !_muted;
    await _controller.setVolume(_muted ? 0.0 : 1.0);
    if (mounted) setState(() {});
  }

  Future<void> _seekBy(Duration delta) async {
    if (!_initialized) return;
    final dur = _controller.value.duration;
    var target = _controller.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    await _controller.seekTo(target);
  }

  Future<void> _openExternalFallback() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _fmt(Duration d) {
    final totalSec = d.inSeconds;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final val = _controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title?.trim().isNotEmpty == true
              ? widget.title!
              : 'Phát video minh chứng',
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Mở bằng ứng dụng khác',
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: _openExternalFallback,
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white54,
                        size: 52,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openExternalFallback,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Mở bằng trình phát ngoài'),
                      ),
                    ],
                  ),
                ),
              )
            : !_initialized
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Đang tải video...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showControls = !_showControls),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: val.aspectRatio > 0
                                  ? val.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          if (val.isBuffering)
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          if (_showControls && !val.isBuffering)
                            GestureDetector(
                              onTap: _togglePlay,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  val.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          colors: const VideoProgressColors(
                            playedColor: AppColors.primary,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${_fmt(val.position)} / ${_fmt(val.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Lùi 10 giây',
                              icon: const Icon(
                                Icons.replay_10_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _seekBy(const Duration(seconds: -10)),
                            ),
                            IconButton(
                              tooltip: val.isPlaying ? 'Tạm dừng' : 'Phát',
                              icon: Icon(
                                val.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: _togglePlay,
                            ),
                            IconButton(
                              tooltip: 'Tiến 10 giây',
                              icon: const Icon(
                                Icons.forward_10_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _seekBy(const Duration(seconds: 10)),
                            ),
                            IconButton(
                              tooltip: _muted ? 'Bật tiếng' : 'Tắt tiếng',
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _toggleMute,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
