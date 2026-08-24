import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';

/// Compact horizontal player header used when window height is constrained
/// (split screen / freeform). Artwork left, song info right. File info and
/// action buttons stay in the default layout below.
class CompactPlayerInfoLayout extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onNavigateToArtistDetail;

  const CompactPlayerInfoLayout({
    super.key,
    required this.song,
    this.onNavigateToArtistDetail,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final albumArtSize = (size.height * 0.24).clamp(88.0, 132.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(12.0, 16.0, 20.0),
      ),
      child: Row(
        children: [
          Container(
            width: albumArtSize,
            height: albumArtSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                context.responsive(12.0, 14.0, 16.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: context.responsive(10.0, 14.0, 18.0),
                  offset: Offset(0, context.responsive(4.0, 6.0, 8.0)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                context.responsive(12.0, 14.0, 16.0),
              ),
              child: CachedImageWidget(
                imagePath: song.albumArt,
                audioSourcePath: song.filePath,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppColors.glassBackgroundStrong,
                  child: FlickArtworkPlaceholder(
                    size: context.responsive(28.0, 32.0, 36.0),
                    opacity: 0.92,
                  ),
                ),
                errorWidget: Container(
                  color: AppColors.glassBackgroundStrong,
                  child: FlickArtworkPlaceholder(
                    size: context.responsive(28.0, 32.0, 36.0),
                    opacity: 0.92,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: context.responsive(12.0, 16.0, 20.0)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsiveText(
                      context.responsive(15.0, 16.0, 17.0),
                    ),
                    fontWeight: FontWeight.bold,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
                GestureDetector(
                  onTap: onNavigateToArtistDetail == null
                      ? null
                      : () => onNavigateToArtistDetail!(song),
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsiveText(
                        context.responsive(12.0, 13.0, 13.5),
                      ),
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
