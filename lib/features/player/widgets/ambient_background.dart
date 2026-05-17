import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_service.dart';

// ---------------------------------------------------------------------------
// AmbientBackground
//
// Strategy: decode + blur the album art **once** per song change using
// dart:ui APIs on the main isolate (async — does not block the UI thread).
// The result is cached as a plain [ui.Image] and displayed with [RawImage].
//
// This eliminates the per-frame GPU cost of BackdropFilter (sigma=25).
// dart:ui APIs MUST run on the main isolate — they cannot be passed to
// compute() because they require Flutter engine bindings.
//
// A module-level cache avoids re-computation when multiple widgets share
// the same album art (e.g. MainShell + Settings sub-pages). The old image
// is kept visible while the new one decodes so the background never flashes
// black during navigation.
// ---------------------------------------------------------------------------

/// Shared cache so parallel [AmbientBackground] instances don't recompute.
final Map<String, ui.Image> _blurCache = {};

class AmbientBackground extends StatefulWidget {
  final Song? song;

  const AmbientBackground({super.key, this.song});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> {
  /// Blur sigma. Lower sigma on the already-downscaled image (~300px wide)
  /// produces the same perceived softness as sigma=25 on a full-res image.
  static const double _blurSigma = 12.0;

  /// Max dimension to decode the source image into (saves memory + decode time).
  static const int _targetDimension = 300;

  ui.Image? _blurredImage;
  String? _currentPath; // resolved path of the image currently shown
  String? _loadingPath; // path we're currently computing for
  bool _computing = false;

  @override
  void initState() {
    super.initState();
    _syncInitFromCache();
    _updateBlur(widget.song?.albumArt, widget.song?.filePath);
  }

  @override
  void didUpdateWidget(AmbientBackground old) {
    super.didUpdateWidget(old);
    final newPath = widget.song?.albumArt;
    final newSourcePath = widget.song?.filePath;
    if (newPath != old.song?.albumArt || newSourcePath != old.song?.filePath) {
      _syncInitFromCache();
      _updateBlur(newPath, newSourcePath);
    }
  }

  /// Seeded synchronously so [build] never starts with a null image
  /// when the artwork is already cached.
  void _syncInitFromCache() {
    final albumArt = widget.song?.albumArt;
    if (albumArt != null && albumArt.isNotEmpty && _blurCache.containsKey(albumArt)) {
      _blurredImage = _blurCache[albumArt];
      _currentPath = albumArt;
    }
  }

  @override
  void dispose() {
    // Don't dispose cached images — they're shared across instances.
    _blurredImage = null;
    super.dispose();
  }

  Future<void> _updateBlur(String? path, String? audioSourcePath) async {
    final resolvedPath = await _resolveArtworkPath(path, audioSourcePath);
    if (resolvedPath == null) {
      if (mounted) {
        setState(() {
          _blurredImage = null;
          _currentPath = null;
          _loadingPath = null;
        });
      }
      return;
    }

    // If another widget already blurred this path, reuse it instantly.
    if (_blurCache.containsKey(resolvedPath)) {
      if (mounted) {
        setState(() {
          _blurredImage = _blurCache[resolvedPath];
          _currentPath = resolvedPath;
        });
      }
      return;
    }

    // Debounce: already computing for this exact path
    if (_computing && _loadingPath == resolvedPath) return;

    _loadingPath = resolvedPath;
    _computing = true;

    try {
      // 1. Read raw bytes from disk (async IO — does not block UI thread)
      final file = File(resolvedPath);
      if (!await file.exists()) {
        _computing = false;
        return;
      }
      final bytes = await file.readAsBytes();

      // Bail if widget disposed or song changed while we were reading
      if (!mounted || resolvedPath != _loadingPath) {
        _computing = false;
        return;
      }

      // 2. Decode at reduced resolution (codec handles downscale on raster thread)
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _targetDimension,
        targetHeight: _targetDimension,
      );
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;

      if (!mounted || resolvedPath != _loadingPath) {
        srcImage.dispose();
        _computing = false;
        return;
      }

      // 3. Draw with blur ImageFilter into a Picture, then rasterise.
      //    picture.toImage() runs on Flutter's raster thread — non-blocking.
      // Capture dimensions before disposal.
      final int imgW = srcImage.width;
      final int imgH = srcImage.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(
        srcImage,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.clamp,
          ),
      );
      final picture = recorder.endRecording();
      srcImage.dispose();

      final blurred = await picture.toImage(imgW, imgH);
      picture.dispose();

      if (!mounted || resolvedPath != _loadingPath) {
        blurred.dispose();
        _computing = false;
        return;
      }

      _blurCache[resolvedPath] = blurred;
      setState(() {
        _blurredImage = blurred;
        _currentPath = resolvedPath;
      });
    } catch (e) {
      debugPrint('[AmbientBackground] blur failed: $e');
    } finally {
      _computing = false;
    }
  }

  Future<String?> _resolveArtworkPath(
    String? path,
    String? audioSourcePath,
  ) async {
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      return path;
    }

    if (audioSourcePath == null || audioSourcePath.isEmpty) {
      return null;
    }

    return AlbumArtService.instance.resolveArtworkPath(
      existingPath: path,
      audioSourcePath: audioSourcePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.song?.albumArt == null && widget.song?.filePath == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: AppConstants.animationSlow,
        child: _blurredImage != null
            ? SizedBox.expand(
                key: ValueKey(_currentPath),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Pre-blurred raster — zero GPU filter cost per frame
                    RawImage(
                      image: _blurredImage,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.6),
                    ),
                    // Dark scrim for readability
                    ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
              )
            : const SizedBox.expand(key: ValueKey('placeholder')),
      ),
    );
  }
}
