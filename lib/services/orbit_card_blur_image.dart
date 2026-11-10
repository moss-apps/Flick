import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flick/services/album_art_service.dart';

/// Shares resolved local covers between lookahead loading and visible cards.
/// Only successful paths are retained; missing artwork can be retried later.
class OrbitCardBlurArtwork {
  static final Map<(String?, String?), String> _paths = {};
  static const _maxPaths = 256;

  static String? cachedPath({String? imagePath, String? audioSourcePath}) {
    final key = (imagePath, audioSourcePath);
    final path = _paths.remove(key);
    if (path != null) _paths[key] = path;
    return path;
  }

  static Future<String?> resolveLocalPath({
    String? imagePath,
    String? audioSourcePath,
  }) async {
    final cached = cachedPath(
      imagePath: imagePath,
      audioSourcePath: audioSourcePath,
    );
    if (cached != null) return cached;
    if (imagePath == null ||
        imagePath.isEmpty ||
        imagePath.contains('://') ||
        !await File(imagePath).exists()) {
      return null;
    }
    _remember(imagePath, audioSourcePath, imagePath);
    return imagePath;
  }

  static Future<String?> resolvePath({
    String? imagePath,
    String? audioSourcePath,
  }) async {
    final local = await resolveLocalPath(
      imagePath: imagePath,
      audioSourcePath: audioSourcePath,
    );
    if (local != null) return local;
    if (audioSourcePath == null || audioSourcePath.isEmpty) return null;
    final path = await AlbumArtService.instance.resolveArtworkPath(
      existingPath: imagePath,
      audioSourcePath: audioSourcePath,
    );
    if (path == null || path.contains('://')) return null;
    _remember(imagePath, audioSourcePath, path);
    return path;
  }

  static void forget({String? imagePath, String? audioSourcePath}) {
    _paths.remove((imagePath, audioSourcePath));
  }

  static void _remember(
    String? imagePath,
    String? audioSourcePath,
    String path,
  ) {
    final key = (imagePath, audioSourcePath);
    _paths.remove(key);
    _paths[key] = path;
    while (_paths.length > _maxPaths) {
      _paths.remove(_paths.keys.first);
    }
  }
}

/// A low-resolution, pre-blurred and gradient-masked portrait card overlay.
///
/// Flutter's bounded [ImageCache] shares both pending work and completed images
/// across cards with the same artwork and size, and owns their disposal. Unlike
/// a live ImageFilter/ShaderMask, displaying the result needs only an image draw.
@immutable
class OrbitCardBlurImage extends ImageProvider<OrbitCardBlurImage> {
  const OrbitCardBlurImage({required this.path, required this.cardSize});

  final String path;
  final Size cardSize;

  // The overlay is deliberately soft; the sharp artwork still uses the user's
  // art-resolution preference. Keep temporary rasters small even on tablets.
  static const int _maxDimension = 192;
  static const double _blurSigma = 16;

  @override
  Future<OrbitCardBlurImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<OrbitCardBlurImage>(this);

  @override
  ImageStreamCompleter loadImage(
    OrbitCardBlurImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(key._render());

  Future<ImageInfo> _render() async {
    try {
      final image = await renderBlurredCardImage(
        path: path,
        cardSize: cardSize,
      );
      return ImageInfo(image: image);
    } catch (_) {
      // Do not retain a failed entry: artwork can be extracted/repaired later.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  /// Draws the cover blurred and fade-masked into a small raster.
  ///
  /// Exposed separately so the raster pass can be tested without driving the
  /// image cache.
  @visibleForTesting
  static Future<ui.Image> renderBlurredCardImage({
    required String path,
    required Size cardSize,
  }) async {
    if (!cardSize.isFinite || cardSize.isEmpty) {
      throw ArgumentError.value(
        cardSize,
        'cardSize',
        'must be finite and non-empty',
      );
    }

    ui.Codec? codec;
    ui.Image? source;
    ui.Picture? picture;
    try {
      // Decode straight from the file so the source bytes never enter the Dart
      // heap; the small target size keeps this cheap for full-resolution covers.
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final scale = math.min(1.0, _maxDimension / math.max(width, height));
          return ui.TargetImageSize(
            width: math.max(1, (width * scale).round()),
            height: math.max(1, (height * scale).round()),
          );
        },
      );
      source = (await codec.getNextFrame()).image;

      final scale = _maxDimension / math.max(cardSize.width, cardSize.height);
      final width = math.max(1, (cardSize.width * scale).round());
      final height = math.max(1, (cardSize.height * scale).round());
      final bounds = Offset.zero & Size(width.toDouble(), height.toDouble());
      final sourceSize = Size(
        source.width.toDouble(),
        source.height.toDouble(),
      );
      final fitted = applyBoxFit(BoxFit.cover, sourceSize, bounds.size);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Bake the horizontal fade into the alpha channel too, so moving cards
      // never need a ShaderMask saveLayer on the live rendering path.
      canvas.saveLayer(bounds, Paint());
      canvas.drawImageRect(
        source,
        Alignment.center.inscribe(fitted.source, Offset.zero & sourceSize),
        bounds,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: _blurSigma * scale,
            sigmaY: _blurSigma * scale,
            tileMode: TileMode.clamp,
          ),
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0xFFFFFFFF)],
            stops: [0.0, 0.26, 0.68],
          ).createShader(bounds),
      );
      canvas.restore();
      picture = recorder.endRecording();
      return await picture.toImage(width, height);
    } finally {
      picture?.dispose();
      source?.dispose();
      codec?.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OrbitCardBlurImage &&
      other.path == path &&
      other.cardSize == cardSize;

  @override
  int get hashCode => Object.hash(path, cardSize);
}
