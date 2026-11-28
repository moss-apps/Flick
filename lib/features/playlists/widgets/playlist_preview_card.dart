import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PlaylistPreviewCard extends StatelessWidget {
  final PlaylistPreview preview;
  final VoidCallback onTap;
  final Widget? actions;
  final String? serverLabel;
  final int? songCount;
  final double artworkHeight;

  const PlaylistPreviewCard({
    super.key,
    required this.preview,
    required this.onTap,
    this.actions,
    this.serverLabel,
    this.songCount,
    this.artworkHeight = defaultArtworkHeight,
  });

  static const defaultArtworkHeight = 136.0;

  static double heightFor(BuildContext context, double artworkHeight) {
    final theme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textScaler: textScaler,
        textDirection: textDirection,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // Reserve a second footer line when the count and date cannot fit together.
    return artworkHeight +
        2 * AppConstants.spacingMd +
        AppConstants.spacingSm +
        2 *
            lineHeight(
              theme.titleSmall?.copyWith(
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ) +
        AppConstants.spacingXxs +
        lineHeight(theme.bodySmall) +
        2 *
            lineHeight(
              theme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ) +
        12 +
        AppConstants.spacingXxs +
        AppConstants.spacingXs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.englishForFilipino;
    final count = songCount;
    final badge = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: actions == null
          ? const Icon(LucideIcons.play, color: Colors.white, size: 16)
          : null,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: 188,
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _PlaylistArtworkGrid(
                    key: PageStorageKey(
                      'playlist-artwork-${preview.playlist.id}',
                    ),
                    artPaths: preview.coverArtPaths,
                    height: artworkHeight,
                  ),
                  Positioned(
                    top: actions == null ? 10 : 3,
                    right: actions == null ? 10 : 3,
                    child: actions == null
                        ? badge
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              badge,
                              SizedBox.square(dimension: 48, child: actions),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                preview.playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxs),
              Text(
                serverLabel ?? preview.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppConstants.spacingXxs,
                  runSpacing: AppConstants.spacingXxs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingXs,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackgroundStrong,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        count == null
                            ? l10n.songs3(preview.songCount)
                            : l10n.song2(count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.adaptiveTextSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      preview.relativeUpdatedLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistArtworkGrid extends StatelessWidget {
  final List<String> artPaths;
  final double height;

  const _PlaylistArtworkGrid({
    super.key,
    required this.artPaths,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const collageSpacing = 2.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: artPaths.isEmpty
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF26313A), Color(0xFF141B20)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.listMusic,
                    color: context.adaptiveTextSecondary,
                    size: 28,
                  ),
                ),
              )
            : artPaths.length == 1
            ? CachedImageWidget(
                imagePath: artPaths.first,
                fit: BoxFit.cover,
                useThumbnail: true,
                thumbnailWidth: 260,
                thumbnailHeight: 260,
              )
            : GridView.builder(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: collageSpacing,
                  crossAxisSpacing: collageSpacing,
                  mainAxisExtent: ((height - collageSpacing) / 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                itemCount: artPaths.length.clamp(0, 4),
                itemBuilder: (context, index) {
                  return CachedImageWidget(
                    imagePath: artPaths[index],
                    fit: BoxFit.cover,
                    useThumbnail: true,
                    thumbnailWidth: 140,
                    thumbnailHeight: 140,
                  );
                },
              ),
      ),
    );
  }
}

class PlaylistPreview {
  final Playlist playlist;
  final String? coverArtPath;
  final List<String> coverArtPaths;
  final String subtitle;
  final int songCount;
  final DateTime updatedAt;

  const PlaylistPreview._({
    required this.playlist,
    required this.coverArtPath,
    required this.coverArtPaths,
    required this.subtitle,
    required this.songCount,
    required this.updatedAt,
  });

  factory PlaylistPreview.fromPlaylist(
    Playlist playlist,
    Map<String, Song> songById,
    AppLocalizations l10n,
  ) {
    final songs = playlist.songIds
        .map((id) => songById[id])
        .whereType<Song>()
        .toList();
    final coverPath = playlist.coverPath;

    return PlaylistPreview._(
      playlist: playlist,
      coverArtPath: coverPath ?? songs.firstOrNull?.albumArt,
      coverArtPaths: coverPath != null
          ? [coverPath]
          : songs
                .map((song) => song.albumArt)
                .whereType<String>()
                .where((path) => path.isNotEmpty)
                .toSet()
                .take(4)
                .toList(),
      subtitle: _subtitle(songs, l10n),
      songCount: songs.length,
      updatedAt: playlist.updatedAt ?? playlist.createdAt,
    );
  }

  static String _subtitle(List<Song> songs, AppLocalizations l10n) {
    final artists = songs.map((song) {
      final name = song.artist.trim();
      return name.isEmpty ? l10n.unknownArtist : name;
    }).toSet();

    return switch (artists.length) {
      0 => l10n.personalPlaylist,
      1 => artists.first,
      _ => l10n.more2(artists.first, artists.length - 1),
    };
  }

  String relativeUpdatedLabel(AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inDays <= 0) {
      return l10n.today;
    }
    if (difference.inDays == 1) {
      return l10n.yesterday;
    }
    if (difference.inDays < 7) {
      return l10n.dAgo(difference.inDays);
    }
    if (difference.inDays < 30) {
      return l10n.wAgo((difference.inDays / 7).floor());
    }
    if (difference.inDays < 365) {
      return l10n.moAgo((difference.inDays / 30).floor());
    }
    return l10n.yAgo((difference.inDays / 365).floor());
  }
}
