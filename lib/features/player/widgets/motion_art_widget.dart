import 'dart:async';

import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/motion_art/animated_artwork_service.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Renders Apple Music Motion Art for an album while falling back to [fallback]
/// (typically the Ken Burns [AnimatedAlbumArt] or a static artwork widget).
///
/// Controllers are always created with [VideoPlayerOptions.mixWithOthers] so
/// ExoPlayer never requests audio focus and playback of the actual music via
/// just_audio is not interrupted.
class MotionArtView extends StatefulWidget {
  const MotionArtView({
    super.key,
    required this.title,
    required this.artist,
    required this.fallback,
    this.album,
    this.duration,
    this.enabled = true,
    this.albumMode = false,
    this.representativeSongTitle,
    this.preferVertical = false,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// Song title, or the album name when [albumMode] is true.
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;

  /// Always rendered when no video is available or [enabled] is false.
  final Widget fallback;

  final bool enabled;

  /// Resolve by album (edition-aware) rather than by song.
  final bool albumMode;
  final String? representativeSongTitle;

  /// Prefer the portrait motion-art variant (full-bleed backgrounds).
  final bool preferVertical;

  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<MotionArtView> createState() => _MotionArtViewState();
}

class _MotionArtViewState extends State<MotionArtView> {
  static const Duration _debounce = Duration(milliseconds: 120);
  static const Duration _retryDelay = Duration(seconds: 35);
  static const int _maxAttempts = 4;

  VideoPlayerController? _controller;
  bool _hasVideo = false;
  Timer? _timer;
  Timer? _retryTimer;
  int _generation = 0;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant MotionArtView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.title != widget.title ||
        oldWidget.artist != widget.artist ||
        oldWidget.album != widget.album ||
        oldWidget.albumMode != widget.albumMode ||
        oldWidget.representativeSongTitle != widget.representativeSongTitle ||
        oldWidget.preferVertical != widget.preferVertical ||
        oldWidget.enabled != widget.enabled;
    if (changed) _restart();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _hasVideo = false;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  void _restart() {
    _teardown();
    _attempt = 0;
    _beginLoad();
  }

  void _beginLoad() {
    if (!widget.enabled) return;
    final generation = _generation;
    _timer = Timer(_debounce, () => _loadOnce(generation));
  }

  void _scheduleRetry() {
    if (!widget.enabled || _attempt >= _maxAttempts) return;
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (!mounted) return;
      _beginLoad();
    });
  }

  Future<void> _loadOnce(int generation) async {
    AnimatedArtwork? artwork;
    try {
      final service = AnimatedArtworkService.instance;
      if (widget.albumMode) {
        artwork = await service.getAnimatedArtworkForAlbum(
          albumName: widget.album ?? widget.title,
          artist: widget.artist,
          representativeSongTitle: widget.representativeSongTitle,
        );
      } else {
        artwork = await service.getAnimatedArtwork(
          songTitle: widget.title,
          artist: widget.artist,
          albumName: widget.album,
          duration: widget.duration,
        );
      }
    } catch (error) {
      devLog('[MotionArt] lookup failed: $error');
    }

    if (!mounted || generation != _generation) return;
    final url = widget.preferVertical
        ? artwork?.verticalPlaybackUrl
        : artwork?.playbackUrl;
    if (url == null) {
      // Could be a definitive "no motion art" (cache hit, no network) or a
      // transient boidu 503; a bounded retry covers the transient case and is
      // cheap for the definitive case because the negative is cached.
      _scheduleRetry();
      return;
    }

    VideoPlayerController? controller;
    try {
      final uri = Uri.parse(url);
      controller = VideoPlayerController.networkUrl(
        uri,
        // boidu's `animated` field is an Apple HLS playlist; hinting the format
        // is more robust than relying on ExoPlayer's URI-extension sniffing.
        formatHint: uri.path.toLowerCase().endsWith('.m3u8')
            ? VideoFormat.hls
            : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      await controller.play();
    } catch (error) {
      devLog('[MotionArt] video init failed: $error');
      await controller?.dispose();
      _scheduleRetry();
      return;
    }

    if (!mounted || generation != _generation) {
      await controller.dispose();
      return;
    }

    final previous = _controller;
    setState(() {
      _controller = controller;
      _hasVideo = true;
    });
    _attempt = 0;
    await previous?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_hasVideo || controller == null || !controller.value.isInitialized) {
      return widget.fallback;
    }

    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return widget.fallback;

    Widget video = SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
    final radius = widget.borderRadius;
    if (radius != null) {
      video = ClipRRect(borderRadius: radius, child: video);
    }
    return video;
  }
}
