// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/artwork_gate.dart';

export 'package:flick/services/artwork_gate.dart';

/// A cached image widget that handles both file and network images with caching,
/// placeholders, and optional thumbnail support.
class CachedImageWidget extends StatefulWidget {
  /// Image path (file path or network URL)
  final String? imagePath;

  /// Audio source path used to lazily resolve embedded artwork on demand.
  final String? audioSourcePath;

  /// BoxFit for the image
  final BoxFit fit;

  /// Placeholder widget to show while loading or on error
  final Widget? placeholder;

  /// Error widget to show if image fails to load
  final Widget? errorWidget;

  /// Optional width constraint
  final double? width;

  /// Optional height constraint
  final double? height;

  /// Whether to use thumbnail (lower resolution) for better performance
  final bool useThumbnail;

  /// Target width for thumbnail (if useThumbnail is true)
  final int? thumbnailWidth;

  /// Target height for thumbnail (if useThumbnail is true)
  final int? thumbnailHeight;

  const CachedImageWidget({
    super.key,
    this.imagePath,
    this.audioSourcePath,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.useThumbnail = false,
    this.thumbnailWidth,
    this.thumbnailHeight,
  });

  /// Default placeholder widget
  static Widget defaultPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceLight, AppColors.surface],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }

  /// Default error widget
  static Widget defaultErrorWidget() {
    return defaultPlaceholder();
  }

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}



class _CachedImageWidgetState extends State<CachedImageWidget> {
  // ponytail: cache only confirmed-existing paths to keep fast-scroll stat()
  // O(1). Misses are NOT cached so async extraction can populate the path
  // later — caching false would permanently hide art whose file appears
  // after the first check.
  static final Set<String> _knownExistingPaths = {};

  String? _resolvedImagePath;
  bool _hasPendingResolve = false;
  // ponytail: one recovery attempt per failed path — a decode failure means
  // the cache file is corrupt or was pruned/cleared mid-session, so drop it
  // from _knownExistingPaths and re-extract instead of failing forever.
  final Set<String> _recoveryAttempted = {};

  @override
  void initState() {
    super.initState();
    _resolvedImagePath = _usablePath(widget.imagePath);
    _resolveEmbeddedArtwork();
  }

  @override
  void didUpdateWidget(covariant CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.audioSourcePath != widget.audioSourcePath) {
      _resolvedImagePath = _usablePath(widget.imagePath);
      _resolveEmbeddedArtwork();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _resolvedImagePath ?? _usablePath(widget.imagePath);
    if (imagePath == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? CachedImageWidget.defaultErrorWidget(),
      );
    }

    // For file paths, use FileImage with caching
    if (!imagePath.startsWith('http')) {
      return _buildFileImage(imagePath);
    }

    // For network URLs, use cached network image
    return _buildNetworkImage(imagePath);
  }

  Future<void> _resolveEmbeddedArtwork() async {
    final directPath = _usablePath(widget.imagePath);
    if (directPath != null) {
      if (_resolvedImagePath != directPath && mounted) {
        setState(() {
          _resolvedImagePath = directPath;
        });
      }
      return;
    }

    final audioSourcePath = widget.audioSourcePath;
    if (audioSourcePath == null || audioSourcePath.isEmpty) {
      if (_resolvedImagePath != null && mounted) {
        setState(() {
          _resolvedImagePath = null;
        });
      }
      return;
    }

    if (artworkExtractionPaused) {
      _enqueueDeferredResolution(audioSourcePath);
      return;
    }

    final resolvedPath = await AlbumArtService.instance.resolveArtworkPath(
      existingPath: widget.imagePath,
      audioSourcePath: audioSourcePath,
    );

    if (!mounted || audioSourcePath != widget.audioSourcePath) {
      return;
    }

    final usablePath = _usablePath(resolvedPath);
    if (_resolvedImagePath != usablePath) {
      setState(() {
        _resolvedImagePath = usablePath;
      });
    }
  }

  void _enqueueDeferredResolution(String audioSourcePath) {
    if (_hasPendingResolve) return;
    _hasPendingResolve = true;
    final imagePath = widget.imagePath;
    enqueueArtworkResolver(() {
      _hasPendingResolve = false;
      if (!mounted ||
          widget.audioSourcePath != audioSourcePath ||
          widget.imagePath != imagePath) {
        return;
      }
      _resolveEmbeddedArtwork();
    });
  }

  String? _usablePath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (path.startsWith('http')) {
      return path;
    }

    if (_knownExistingPaths.contains(path)) {
      return path;
    }

    if (File(path).existsSync()) {
      _knownExistingPaths.add(path);
      return path;
    }

    return null;
  }

  Widget _buildFileImage(String imagePath) {
    final file = File(imagePath);

    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ?? CachedImageWidget.defaultPlaceholder(),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        _recoverFailedFile(imagePath);
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget ?? CachedImageWidget.defaultErrorWidget(),
        );
      },
      // Use lower resolution for thumbnails
      cacheWidth: widget.useThumbnail && widget.thumbnailWidth != null
          ? widget.thumbnailWidth
          : null,
      cacheHeight: widget.useThumbnail && widget.thumbnailHeight != null
          ? widget.thumbnailHeight
          : null,
    );
  }

  void _recoverFailedFile(String failedPath) {
    if (failedPath.startsWith('http') ||
        _recoveryAttempted.contains(failedPath)) {
      return;
    }
    _recoveryAttempted.add(failedPath);
    _knownExistingPaths.remove(failedPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final file = File(failedPath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      if (_resolvedImagePath == failedPath) {
        setState(() {
          _resolvedImagePath = null;
        });
      }
      _resolveEmbeddedArtwork();
    });
  }

  Widget _buildNetworkImage(String imagePath) {
    return Image.network(
      imagePath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ?? CachedImageWidget.defaultPlaceholder(),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget ?? CachedImageWidget.defaultErrorWidget(),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ?? CachedImageWidget.defaultPlaceholder(),
        );
      },
      // Use lower resolution for thumbnails
      cacheWidth: widget.useThumbnail && widget.thumbnailWidth != null
          ? widget.thumbnailWidth
          : null,
      cacheHeight: widget.useThumbnail && widget.thumbnailHeight != null
          ? widget.thumbnailHeight
          : null,
    );
  }
}

/// Helper class for preloading images
class ImagePreloader {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  static Future<void> preloadFile(
    String filePath,
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    // Check if widget is still mounted before using context
    if (!isMounted()) {
      return;
    }

    try {
      // Decode the image to cache it in memory
      final imageProvider = FileImage(file);
      // Check again before precaching (context might be invalid)
      if (isMounted()) {
        await precacheImage(imageProvider, context);
      }
    } catch (e) {
      // Ignore errors during preloading (context might be invalid)
    }
  }

  static Future<void> preloadNetwork(
    String url,
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    try {
      // First cache the file
      await _cacheManager.getSingleFile(url);

      // Check if widget is still mounted before using context
      if (!isMounted()) {
        return;
      }

      // Then decode it into memory
      final imageProvider = NetworkImage(url);
      // Check again before precaching (context might be invalid)
      if (isMounted()) {
        await precacheImage(imageProvider, context);
      }
    } catch (e) {
      // Ignore errors during preloading (context might be invalid)
    }
  }

  /// Preload multiple images
  ///
  /// [isMounted] callback should return true if the widget is still mounted.
  /// This prevents using BuildContext across async gaps.
  ///
  /// Usage:
  /// ```dart
  /// ImagePreloader.preloadImages(['path1.jpg', 'path2.jpg'], context, isMounted: () => mounted);
  /// ```
  static Future<void> preloadImages(
    List<String> imagePaths,
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    final futures = imagePaths.map((path) {
      if (path.startsWith('http')) {
        return preloadNetwork(path, context, isMounted: isMounted);
      } else {
        return preloadFile(path, context, isMounted: isMounted);
      }
    });
    await Future.wait(futures);
  }
}
