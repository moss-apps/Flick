import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/marquee_widget.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

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
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> {
  double _dragDx = 0;
  bool _queuedFlash = false;
  bool _favoriteFlash = false;
  double? _cachedCardWidth;

  @override
  Widget build(BuildContext context) {
    final artSize = widget.isSelected
        ? AppConstants.songCardArtSizeLarge
        : AppConstants.songCardArtSize;

    _cachedCardWidth ??= MediaQuery.of(context).size.width * 0.68;
    final cardWidth = _cachedCardWidth!;
    const cardHeight = 130.0;

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
      child: RepaintBoundary(
        child: Transform.scale(
          scale: widget.scale.isFinite ? widget.scale : 1.0,
          child: Opacity(
            opacity: widget.opacity.isFinite ? widget.opacity.clamp(0.0, 1.0) : 1.0,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: showSwipeOverlay
                  ? _buildSwipeStack(cardWidth, artSize)
                  : _buildCardFace(artSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(double artSize) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
      child: Stack(
        children: [
          Positioned.fill(child: _buildAlbumWithGradient(artSize)),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Color(0xD9000000),
                  ],
                  stops: [0.25, 0.70],
                ),
              ),
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

  Widget _buildSwipeStack(double cardWidth, double artSize) {
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text('Add to queue',
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
              child: _buildCardFace(artSize),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumWithGradient(double size) {
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
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
              stops: const [0.5, 1.0],
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
    final isThumbnail = artSize <= AppConstants.songCardArtSize;

    return CachedImageWidget(
      imagePath: path,
      audioSourcePath: audioSourcePath,
      fit: fit,
      placeholder: _buildPlaceholderArt(),
      errorWidget: _buildPlaceholderArt(),
      useThumbnail: isThumbnail,
      thumbnailWidth: isThumbnail
          ? (AppConstants.songCardArtSize * 2).toInt()
          : null,
      thumbnailHeight: isThumbnail
          ? (AppConstants.songCardArtSize * 2).toInt()
          : null,
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
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.textTertiary,
          size: 28,
        ),
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
            child: MarqueeWidget(
              child: Text(
                widget.song.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
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
