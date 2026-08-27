import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/song_tile_thumbnail_mode.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';

/// Song row thumbnail for detail screens, driven by the
/// songTileThumbnailMode preference: album art, track number, or track
/// number over dimmed/blurred art.
class SongTileThumbnail extends ConsumerWidget {
  const SongTileThumbnail({super.key, required this.song, this.trackNumber});

  final Song song;
  final int? trackNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = SongTileThumbnailModeX.fromStorageValue(
      ref.watch(appPreferencesProvider).songTileThumbnailMode,
    );

    return Container(
      width: context.scaleSize(AppConstants.containerSizeMd),
      height: context.scaleSize(AppConstants.containerSizeMd),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: _buildContent(context, mode),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SongTileThumbnailMode mode) {
    switch (mode) {
      case SongTileThumbnailMode.artwork:
        return _artwork;
      case SongTileThumbnailMode.trackNumber:
        if (trackNumber == null) {
          return const Center(
            child: FlickArtworkPlaceholder(size: 28, opacity: 0.9),
          );
        }
        return Center(
          child: Text(
            '$trackNumber',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case SongTileThumbnailMode.trackNumberOnArt:
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 3.0,
                sigmaY: 3.0,
                tileMode: TileMode.clamp,
              ),
              child: _artwork,
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            if (trackNumber != null)
              Center(
                child: Text(
                  '$trackNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Center(
                child: FlickArtworkPlaceholder(size: 28, opacity: 0.9),
              ),
          ],
        );
    }
  }

  Widget get _artwork => CachedImageWidget(
    imagePath: song.albumArt,
    audioSourcePath: song.filePath,
    fit: BoxFit.cover,
    placeholder: const FlickArtworkPlaceholder(size: 28, opacity: 0.9),
    errorWidget: const FlickArtworkPlaceholder(size: 28, opacity: 0.9),
  );
}
