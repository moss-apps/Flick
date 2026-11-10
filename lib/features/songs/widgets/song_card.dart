import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/models/orbit_card_background_style.dart';
import 'package:flick/models/song.dart';
import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/features/songs/widgets/orbit_card_blur.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/l10n/l10n.dart';

/// Song card widget for displaying in the orbit scroll.
class SongCard extends StatefulWidget {
  /// Song data to display
  final Song song;

  /// Scale factor based on position in orbit (0.0 - 1.0)
  final double scale;

  /// Opacity based on position in orbit (0.0 - 1.0)
  final double opacity;

  /// Whether this song is currently selected
  final bool isSelected;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Callback when the card is swiped left.
  final VoidCallback? onSwipeLeft;

  /// Callback when the card is swiped right.
  final VoidCallback? onSwipeRight;

  /// Whether swipe-to-queue and swipe-to-favorite gestures are enabled.
  final bool swipeActionsEnabled;

  /// Whether multiselect mode is active.
  final bool isSelectionMode;

  /// Whether this song is selected in multiselect mode.
  final bool isMultiSelected;

  /// Base album-art size for non-selected cards (overrides default).
  final double artSizeBase;

  /// Album-art size for the selected card (overrides default).
  final double artSizeLarge;

  /// Card width as a fraction of screen width (overrides default).
  final double cardWidthRatio;

  /// Decode-resolution multiplier applied to art size (higher = sharper, heavier).
  final double artResolutionMultiplier;
  final double? width;
  final double? height;
  final bool artworkAbove;

  /// Background treatment used by the portrait card face.
  final OrbitCardBackgroundStyle backgroundStyle;

  const SongCard({
    super.key,
    required this.song,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.isSelected = false,
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.swipeActionsEnabled = false,
    this.isSelectionMode = false,
    this.isMultiSelected = false,
    this.artSizeBase = AppConstants.songCardArtSize,
    this.artSizeLarge = AppConstants.songCardArtSizeLarge,
    this.cardWidthRatio = 0.68,
    this.artResolutionMultiplier = 2.0,
    this.width,
    this.height,
    this.artworkAbove = false,
    this.backgroundStyle = OrbitCardBackgroundStyle.blackGradient,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> {
  double _dragDx = 0;
  bool _queuedFlash = false;
  bool _favoriteFlash = false;

  /// Retained card face. Orbit motion changes only scale/opacity, so keeping
  /// this subtree identical between animation ticks avoids rebuilding the
  /// artwork, gradients and text on every frame.
  Widget? _cardFace;

  /// Resolves the per-card tint for [OrbitCardBackgroundStyle.albumColorGradient].
  /// The future is rebuilt only when the song or background style changes; the
  /// service caches extracted colors, so later resolutions are instant.
  late Future<Color?> _albumColorFuture;

  @override
  void initState() {
    super.initState();
    _albumColorFuture = _resolveAlbumColor();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets may have changed (theme, media query, etc.).
    _cardFace = null;
  }

  @override
  void didUpdateWidget(covariant SongCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Song equality compares only the id, so use identity here: metadata or
    // artwork for the same id must refresh the retained face.
    final songChanged = !identical(oldWidget.song, widget.song);
    if (songChanged ||
        oldWidget.isSelected != widget.isSelected ||
        oldWidget.isSelectionMode != widget.isSelectionMode ||
        oldWidget.isMultiSelected != widget.isMultiSelected ||
        oldWidget.artSizeBase != widget.artSizeBase ||
        oldWidget.artSizeLarge != widget.artSizeLarge ||
        oldWidget.artResolutionMultiplier != widget.artResolutionMultiplier ||
        oldWidget.artworkAbove != widget.artworkAbove ||
        oldWidget.backgroundStyle != widget.backgroundStyle) {
      _cardFace = null;
    }
    if (songChanged ||
        oldWidget.artworkAbove != widget.artworkAbove ||
        oldWidget.backgroundStyle != widget.backgroundStyle) {
      _albumColorFuture = _resolveAlbumColor();
    }
  }

  Future<Color?> _resolveAlbumColor() {
    if (widget.artworkAbove ||
        widget.backgroundStyle != OrbitCardBackgroundStyle.albumColorGradient) {
      return Future<Color?>.value(null);
    }
    final song = widget.song;
    return () async {
      // Resolve embedded or folder artwork before sampling; the service keeps
      // the expensive extraction off the layout path and caches the result.
      final path = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: song.albumArt,
        audioSourcePath: song.filePath ?? '',
      );
      if (path == null) return null;
      return ColorExtractionService().extractDominantColor(path);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final artSize =
        widget.isSelected ? widget.artSizeLarge : widget.artSizeBase;
    final cardFace = _cardFace ??= _buildCardFace(artSize);

    final cardWidth = widget.width ??
        MediaQuery.sizeOf(context).width * widget.cardWidthRatio;
    final cardHeight = widget.height ?? 130.0;

    final isSwiping = _dragDx.abs() > 0.001;
    final isFlashing = _queuedFlash || _favoriteFlash;
    final showSwipeOverlay = isSwiping || isFlashing;

    GestureDragUpdateCallback? dragUpdate;
    GestureDragEndCallback? dragEnd;
    GestureDragCancelCallback? dragCancel;
    if (widget.swipeActionsEnabled) {
      dragUpdate = (details) {
        final nextDx = (_dragDx + details.delta.dx).clamp(-120.0, 120.0);
        if (nextDx != _dragDx) {
          setState(() {
            _dragDx = nextDx;
          });
        }
      };
      dragEnd = (details) {
        unawaited(() async {
          final shouldFavorite =
              _dragDx >= 80 ||
              (details.primaryVelocity != null &&
                  details.primaryVelocity! > 400);
          final shouldQueue =
              _dragDx <= -80 ||
              (details.primaryVelocity != null &&
                  details.primaryVelocity! < -400);
          if (shouldFavorite) {
            AppHaptics.confirm();
            setState(() {
              _dragDx = 0;
              _favoriteFlash = true;
            });
            widget.onSwipeRight?.call();
            await Future<void>.delayed(const Duration(milliseconds: 180));
            if (!mounted) return;
            setState(() {
              _favoriteFlash = false;
            });
            return;
          }
          if (shouldQueue) {
            AppHaptics.confirm();
            setState(() {
              _dragDx = 0;
              _queuedFlash = true;
            });
            widget.onSwipeLeft?.call();
            await Future<void>.delayed(const Duration(milliseconds: 180));
            if (!mounted) return;
            setState(() {
              _queuedFlash = false;
            });
            return;
          }
          setState(() {
            _dragDx = 0;
          });
        }());
      };
      dragCancel = () {
        if (_dragDx != 0) {
          setState(() {
            _dragDx = 0;
          });
        }
      };
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        widget.onTap?.call();
      },
      onHorizontalDragUpdate: dragUpdate,
      onHorizontalDragEnd: dragEnd,
      onHorizontalDragCancel: dragCancel,
      // Keep the changing scale/opacity outside the retained artwork: the
      // RepaintBoundary caches the card face while the motion above it moves.
      child: Transform.scale(
        scale: widget.scale.isFinite ? widget.scale : 1.0,
        child: Opacity(
          opacity: widget.opacity.isFinite ? widget.opacity.clamp(0.0, 1.0) : 1.0,
          child: RepaintBoundary(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: showSwipeOverlay
                  ? _buildSwipeStack(cardWidth, cardFace)
                  : cardFace,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(double artSize) {
    if (widget.artworkAbove) return _buildArtworkCard(artSize);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
      child: Stack(
        children: [
          Positioned.fill(child: _buildPortraitBackground(artSize)),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  SizedBox(width: artSize + AppConstants.spacingMd),
                  Expanded(
                    child: _buildSongInfo(
                      context,
                      isSelected: widget.isSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isSelectionMode)
            Positioned(
              top: AppConstants.spacingSm,
              right: AppConstants.spacingSm,
              child: Icon(
                widget.isMultiSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: widget.isMultiSelected
                    ? AppColors.accent
                    : Colors.white54,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(double artSize) {
    return Semantics(
      selected: widget.isSelected || widget.isMultiSelected,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Short stages keep the artwork instead of collapsing to a text
            // overlay. The footer stays one line per field and scrolls only
            // when enlarged text needs more room than the card can give it.
            final footerMaxHeight = constraints.maxHeight * 0.45;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        child: _buildRawImage(
                          widget.song.albumArt ?? '',
                          audioSourcePath: widget.song.filePath,
                          artSize: math.max(
                            artSize,
                            constraints.maxWidth,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: footerMaxHeight),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlex',
                                fontFamilyFallback: AppTheme.fontFamilyFallback,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                letterSpacing: -0.1,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlex',
                                fontFamilyFallback: AppTheme.fontFamilyFallback,
                                fontSize: 12,
                                height: 1.2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isMultiSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: widget.isMultiSelected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwipeStack(double cardWidth, Widget cardFace) {
    final queueProgress = (-_dragDx / 110).clamp(0.0, 1.0);
    final favoriteProgress = (_dragDx / 110).clamp(0.0, 1.0);
    final isFlashing = _queuedFlash || _favoriteFlash;

    final glowColor = (_favoriteFlash ? Colors.redAccent : AppColors.accent)
        .withValues(alpha: 0.25);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.redAccent
                      .withValues(alpha: 0.14 + (favoriteProgress * 0.14)),
                  AppColors.surface,
                  AppColors.accent
                      .withValues(alpha: 0.14 + (queueProgress * 0.14)),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  AppColors.accent
                      .withValues(alpha: 0.18 + (queueProgress * 0.26)),
                  Colors.redAccent
                      .withValues(alpha: 0.18 + (favoriteProgress * 0.26)),
                  favoriteProgress,
                )!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg),
              child: Row(
                children: [
                  Opacity(
                    opacity: favoriteProgress,
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.redAccent, size: 22),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: queueProgress,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(l10n.addToQueue2,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSlide(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          offset: Offset(_dragDx / cardWidth, 0),
          child: AnimatedScale(
            duration: AppConstants.animationFast,
            scale: isFlashing ? 0.98 : 1,
            child: AnimatedContainer(
              duration: AppConstants.animationFast,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
                boxShadow: isFlashing
                    ? [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: cardFace,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitBackground(double size) {
    switch (widget.backgroundStyle) {
      case OrbitCardBackgroundStyle.blurGradient:
        return _buildBlurPortraitBackground(size);
      case OrbitCardBackgroundStyle.albumColorGradient:
        return FutureBuilder<Color?>(
          future: _albumColorFuture,
          builder: (context, snapshot) {
            return _buildAlbumColorPortraitBackground(size, snapshot.data);
          },
        );
      case OrbitCardBackgroundStyle.blackGradient:
        return _buildBlackPortraitBackground(size);
    }
  }

  Widget _buildBlackPortraitBackground(double size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildRawImage(
          widget.song.albumArt ?? '',
          audioSourcePath: widget.song.filePath,
          fit: BoxFit.cover,
          artSize: size,
        ),
        // Keep the original two-pass black fade for the legacy style.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.transparent, Color(0xD9000000)],
              stops: [0.25, 0.70],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlurPortraitBackground(double size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildRawImage(
          widget.song.albumArt ?? '',
          audioSourcePath: widget.song.filePath,
          fit: BoxFit.cover,
          artSize: size,
        ),
        // The blur and fade are baked once into a small cached image, so orbit
        // motion draws a plain texture instead of rerunning a live filter. The
        // sharp artwork above keeps its independent decode resolution.
        OrbitCardBlur(
          imagePath: widget.song.albumArt,
          audioSourcePath: widget.song.filePath,
        ),
        // Lighter than the black style so the blurred cover stays visible.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.56),
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: const [0.22, 0.58, 0.9],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumColorPortraitBackground(double size, Color? albumColor) {
    if (albumColor == null) return _buildBlackPortraitBackground(size);

    final tint = albumSurface(albumColor, 0.5);
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildRawImage(
          widget.song.albumArt ?? '',
          audioSourcePath: widget.song.filePath,
          fit: BoxFit.cover,
          artSize: size,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                tint.withValues(alpha: 0.55),
                tint.withValues(alpha: 0.95),
              ],
              stops: const [0.2, 0.55, 0.88],
            ),
          ),
        ),
        // Darken the tint just enough for white metadata on bright covers.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.3),
              ],
              stops: const [0.45, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawImage(
    String path, {
    String? audioSourcePath,
    BoxFit fit = BoxFit.cover,
    required double artSize,
  }) {
    // ponytail: cap decode at artSize * multiplier. Selected card used to decode
    // full-res, OOM'ing during fast orbit fling. Multiplier is now user-tunable;
    // default 2x stays soft on >2x DPR — scale up if it shows.
    final decodeDim = (artSize * widget.artResolutionMultiplier).toInt();

    return CachedImageWidget(
      imagePath: path,
      audioSourcePath: audioSourcePath,
      fit: fit,
      placeholder: _buildPlaceholderArt(),
      errorWidget: _buildPlaceholderArt(),
      useThumbnail: true,
      thumbnailWidth: decodeDim,
      thumbnailHeight: decodeDim,
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceLight, AppColors.surface],
        ),
      ),
      child: const Center(
        child: FlickArtworkPlaceholder(size: 36, opacity: 0.9),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, {bool isSelected = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected)
          SizedBox(
            height: 24,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.song.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          )
        else
          Text(
            widget.song.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: AppConstants.spacingXxs),
        Text(
          widget.song.artist,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white70,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Row(
          children: [
            _buildMetadataBadge(widget.song.fileType),
            const SizedBox(width: AppConstants.spacingXs),
            _buildMetadataText(widget.song.formattedDuration),
            if (widget.song.resolution != null &&
                widget.song.resolution != 'Unknown') ...[
              const SizedBox(width: AppConstants.spacingXs),
              _buildMetadataText('•'),
              const SizedBox(width: AppConstants.spacingXs),
              Flexible(child: _buildMetadataText(widget.song.resolution!)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
        border: Border.all(color: Colors.white30, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetadataText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Colors.white70,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
