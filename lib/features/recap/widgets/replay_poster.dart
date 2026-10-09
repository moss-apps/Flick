import 'package:flutter/material.dart';

import '../../../data/repositories/recently_played_repository.dart';
import 'replay_artwork.dart';
import 'replay_card_options.dart';
import 'replay_card_surface.dart';
import 'replay_graphics.dart';
import 'replay_sections.dart';
import 'replay_style.dart';

enum ReplayPosterType { overview, songs, artists, album }

extension ReplayPosterTypeX on ReplayPosterType {
  String get label => switch (this) {
    ReplayPosterType.overview => 'Replay',
    ReplayPosterType.songs => 'Top songs',
    ReplayPosterType.artists => 'Top artists',
    ReplayPosterType.album => 'Top album',
  };

  ReplayCardKind get kind => switch (this) {
    ReplayPosterType.overview => ReplayCardKind.overview,
    ReplayPosterType.songs => ReplayCardKind.songs,
    ReplayPosterType.artists => ReplayCardKind.artists,
    ReplayPosterType.album => ReplayCardKind.album,
  };
}

/// The studio and PNG use the same composition. Capture explicitly disables
/// motion, rather than exporting a random frame of the living ornament.
class ReplayPoster extends StatelessWidget {
  static const size = Size(420, 760);
  final ListeningRecap recap;
  final ReplayPosterType type;
  final String? backgroundPath;
  final ReplayCardOptions options;
  final bool animated;

  const ReplayPoster({
    super.key,
    required this.recap,
    this.type = ReplayPosterType.overview,
    this.backgroundPath,
    this.options = const ReplayCardOptions(),
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReplayCardPalette.resolve(
      options,
      type.kind,
      photo: backgroundPath != null,
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
        disableAnimations: !animated || MediaQuery.disableAnimationsOf(context),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: ReplayCardSurface(
          palette: palette,
          options: options,
          backgroundPath: backgroundPath,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ReplayBrand(
                        color: palette.foreground,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      recap.period.label,
                      style: TextStyle(fontSize: 13, color: palette.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ReplayStyle.range(recap),
                  style: TextStyle(fontSize: 12, color: palette.secondary),
                ),
                const SizedBox(height: 22),
                Divider(height: 1, color: palette.rule),
                const SizedBox(height: 22),
                Expanded(
                  child: switch (type) {
                    ReplayPosterType.overview => _overview(palette),
                    ReplayPosterType.album => _album(palette),
                    ReplayPosterType.songs ||
                    ReplayPosterType.artists => _rankings(palette),
                  },
                ),
                Divider(height: 1, color: palette.rule),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        options.tagline
                            ? 'Your music. On repeat.'
                            : 'Flick Replay',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.secondary,
                        ),
                      ),
                    ),
                    ReplaySignature(color: palette.foreground),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(ReplayCardPalette palette) {
    final top = recap.topSong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${recap.totalPlays}',
            style: TextStyle(
              fontSize: 96,
              height: 1,
              letterSpacing: -2.4,
              fontWeight: FontWeight.w700,
              color: palette.foreground,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'plays in rotation',
          style: TextStyle(fontSize: 17, color: palette.secondary),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 340,
                child: ReplayArtworkStage(
                  paths: top == null
                      ? const [null]
                      : [
                          top.song.albumArt,
                          if (options.secondaryArtwork)
                            ...recap.topSongs
                                .where((entry) => entry.song.id != top.song.id)
                                .take(2)
                                .map((entry) => entry.song.albumArt),
                        ],
                  animated: animated,
                  highResolution: true,
                  layered: options.layered,
                  ornaments: options.ornaments,
                  color: palette.dark ? palette.accent : ReplayStyle.acid,
                  badge: options.badges && top != null
                      ? 'Most replayed · ${ReplayStyle.plays(top.plays)}'
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          top?.song.title ?? 'Your next favorite is waiting.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 27,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: palette.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          top?.song.artist ?? 'Keep listening with Flick',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: palette.secondary),
        ),
        const SizedBox(height: 20),
        ReplayMetrics(recap: recap, options: options, palette: palette),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _album(ReplayCardPalette palette) {
    final album = recap.topAlbum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type.label,
          style: TextStyle(
            fontSize: 44,
            height: 1.05,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w700,
            color: palette.foreground,
          ),
        ),
        const SizedBox(height: 20),
        if (album == null)
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'No album data yet',
                style: TextStyle(color: palette.secondary, fontSize: 18),
              ),
            ),
          )
        else ...[
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 340,
                  child: ReplayArtworkStage(
                    paths: [album.representativeSong.albumArt],
                    animated: animated,
                    layered: false,
                    framed: options.surfaceDetail,
                    ornaments: options.ornaments,
                    highResolution: true,
                    color: palette.accent,
                    badge: options.badges
                        ? ReplayStyle.plays(album.plays)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            album.album,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 27,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: palette.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: palette.secondary),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: palette.rule),
          const SizedBox(height: 14),
          Text(
            '${album.uniqueSongs} ${album.uniqueSongs == 1 ? 'song' : 'songs'} · ${ReplayStyle.plays(album.plays)}',
            style: TextStyle(fontSize: 13, color: palette.secondary),
          ),
        ],
      ],
    );
  }

  Widget _rankings(ReplayCardPalette palette) {
    final artists = type == ReplayPosterType.artists;
    final count = (artists ? recap.topArtists.length : recap.topSongs.length)
        .clamp(0, 5);
    final maxPlays = count == 0
        ? 0
        : artists
        ? recap.topArtists.first.plays
        : recap.topSongs.first.plays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type.label,
          style: TextStyle(
            fontSize: 44,
            height: 1.05,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w700,
            color: palette.foreground,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: size.width - 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (count == 0)
                      Text(
                        'No ranking data yet',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 18,
                        ),
                      ),
                    for (var i = 0; i < count; i++) ...[
                      _printRow(palette, i, artists, maxPlays),
                      if (i != count - 1)
                        Divider(height: 24, color: palette.rule),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _printRow(
    ReplayCardPalette palette,
    int index,
    bool artists,
    int maxPlays,
  ) {
    final plays = artists
        ? recap.topArtists[index].plays
        : recap.topSongs[index].plays;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: index == 0 ? palette.foreground.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(index == 0 ? 10 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
            ),
            if (!artists) ...[
              ReplayArtwork(
                path: recap.topSongs[index].song.albumArt,
                size: index == 0 ? 60 : 44,
                useThumbnail: false,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artists
                        ? recap.topArtists[index].artist
                        : recap.topSongs[index].song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: index == 0 ? 21 : 17,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    artists
                        ? '${recap.topArtists[index].uniqueSongs} ${recap.topArtists[index].uniqueSongs == 1 ? 'song' : 'songs'}'
                        : recap.topSongs[index].song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.secondary),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ReplayStyle.plays(plays),
                    style: TextStyle(fontSize: 12, color: palette.secondary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: index == 0 ? 4 : 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: palette.rule),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: maxPlays == 0
                                ? 0
                                : (plays / maxPlays).clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: ColoredBox(color: palette.accent),
                          ),
                        ),
                      ],
                    ),
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
