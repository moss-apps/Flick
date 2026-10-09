import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/repositories/recently_played_repository.dart';
import 'replay_artwork.dart';
import 'replay_card_options.dart';
import 'replay_card_surface.dart';
import 'replay_graphics.dart';
import 'replay_reveal.dart';
import 'replay_style.dart';

TextStyle _display(Color color, double size) => TextStyle(
  fontSize: size,
  height: 1.06,
  letterSpacing: -size * 0.025,
  fontWeight: FontWeight.w700,
  color: color,
);

class ReplayOverview extends StatelessWidget {
  final ListeningRecap recap;
  final ScrollController scrollController;
  final ReplayCardOptions options;

  const ReplayOverview({
    super.key,
    required this.recap,
    required this.scrollController,
    this.options = const ReplayCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final song = recap.topSong;
    final palette = ReplayCardPalette.resolve(options, ReplayCardKind.overview);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReplayCardSurface(
          palette: palette,
          options: options,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReplayBrand(color: palette.foreground),
                const SizedBox(height: 8),
                Text(
                  '${recap.period.label} · ${ReplayStyle.range(recap)}',
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${recap.totalPlays}',
                    style: _display(
                      palette.foreground,
                      96,
                    ).copyWith(height: 0.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'plays in rotation',
                  style: _display(palette.foreground, 21),
                ),
                const SizedBox(height: 8),
                RepaintBoundary(
                  child: ReplayArtworkStage(
                    paths: song == null
                        ? const [null]
                        : [
                            song.song.albumArt,
                            if (options.secondaryArtwork)
                              ...recap.topSongs
                                  .where(
                                    (entry) => entry.song.id != song.song.id,
                                  )
                                  .take(2)
                                  .map((entry) => entry.song.albumArt),
                          ],
                    scrollController: scrollController,
                    color: palette.dark ? palette.accent : ReplayStyle.acid,
                    layered: options.layered,
                    ornaments: options.ornaments,
                    badge: options.badges && song != null
                        ? 'Most replayed · ${ReplayStyle.plays(song.plays)}'
                        : null,
                  ),
                ),
                if (song != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    song.song.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _display(palette.foreground, 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.song.artist,
                    style: TextStyle(fontSize: 15, color: palette.secondary),
                  ),
                  if (options.tagline) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Your most replayed track',
                      style: TextStyle(color: palette.secondary, fontSize: 12),
                    ),
                  ],
                ],
                const SizedBox(height: 26),
                Divider(height: 1, color: palette.rule),
                const SizedBox(height: 20),
                ReplayMetrics(recap: recap, options: options, palette: palette),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        options.tagline
                            ? 'Your music. On repeat.'
                            : recap.period.label,
                        style: TextStyle(
                          fontSize: 11,
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
        if (options.metrics.contains(ReplayMetric.trackTime)) ...[
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Track time sums the full duration of logged plays.',
              style: TextStyle(fontSize: 12, color: ReplayStyle.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class ReplayMetrics extends StatelessWidget {
  final ListeningRecap recap;
  final ReplayCardOptions options;
  final ReplayCardPalette palette;

  const ReplayMetrics({
    super.key,
    required this.recap,
    required this.options,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
      final width = largeText
          ? constraints.maxWidth
          : (constraints.maxWidth - 16) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 18,
        children: [
          for (final metric in options.metrics.take(3))
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value(recap),
                    style: _display(palette.foreground, 23),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metric.label,
                    style: TextStyle(fontSize: 11, color: palette.secondary),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class ReplayRankings extends StatelessWidget {
  final ListeningRecap recap;
  final ScrollController scrollController;
  final bool artists;
  final ReplayCardOptions options;

  const ReplayRankings({
    super.key,
    required this.recap,
    required this.scrollController,
    this.artists = false,
    this.options = const ReplayCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final count = math.min(
      5,
      artists ? recap.topArtists.length : recap.topSongs.length,
    );
    final maxPlays = count == 0
        ? 0
        : artists
        ? recap.topArtists.first.plays
        : recap.topSongs.first.plays;
    final palette = ReplayCardPalette.resolve(
      options,
      artists ? ReplayCardKind.artists : ReplayCardKind.songs,
    );
    return ReplayCardSurface(
      palette: palette,
      options: options,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artists ? 'Top artists' : 'Top songs',
              style: _display(palette.foreground, 34),
            ),
            const SizedBox(height: 8),
            Text(
              ReplayStyle.range(recap),
              style: TextStyle(fontSize: 12, color: palette.secondary),
            ),
            const SizedBox(height: 26),
            for (var i = 0; i < count; i++) ...[
              ReplayReveal(
                key: ValueKey(
                  '${recap.period.name}-${artists ? 'artist' : 'song'}-$i',
                ),
                scrollController: scrollController,
                order: i,
                child: ReplayRankingRow(
                  rank: i + 1,
                  title: artists
                      ? recap.topArtists[i].artist
                      : recap.topSongs[i].song.title,
                  subtitle: artists
                      ? '${recap.topArtists[i].uniqueSongs} ${recap.topArtists[i].uniqueSongs == 1 ? 'song' : 'songs'}'
                      : recap.topSongs[i].song.artist,
                  path: artists ? null : recap.topSongs[i].song.albumArt,
                  plays: artists
                      ? recap.topArtists[i].plays
                      : recap.topSongs[i].plays,
                  maxPlays: maxPlays,
                  showArtwork: !artists,
                  palette: palette,
                ),
              ),
              if (i != count - 1) Divider(height: 28, color: palette.rule),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ReplayBrand(color: palette.secondary, fontSize: 12),
                ),
                ReplaySignature(color: palette.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReplayRankingRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String? path;
  final int plays;
  final int maxPlays;
  final bool showArtwork;
  final ReplayCardPalette palette;

  const ReplayRankingRow({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.plays,
    required this.maxPlays,
    required this.palette,
    this.path,
    this.showArtwork = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxPlays == 0 ? 0.0 : (plays / maxPlays).clamp(0.0, 1.0);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rank == 1 ? palette.foreground.withValues(alpha: 0.055) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(rank == 1 ? 10 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: largeText ? 34 : 36,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Text(
                  '$rank'.padLeft(2, '0'),
                  style: _display(
                    rank == 1 ? palette.accent : palette.secondary,
                    rank == 1 ? 28 : 22,
                  ),
                ),
              ),
            ),
            if (showArtwork && !largeText) ...[
              ReplayArtwork(path: path, size: rank == 1 ? 60 : 44),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _display(palette.foreground, rank == 1 ? 19 : 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.secondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ReplayStyle.plays(plays),
                    style: TextStyle(fontSize: 12, color: palette.secondary),
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: ReplayStyle.duration(context, slow: true),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) => SizedBox(
                      height: rank == 1 ? 4 : 2,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: palette.rule),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: value,
                              heightFactor: 1,
                              child: ColoredBox(color: palette.accent),
                            ),
                          ),
                        ],
                      ),
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

class ReplayArtistFeature extends StatelessWidget {
  final RankedRecapArtist artist;
  final ListeningRecap recap;
  final ReplayCardOptions options;
  final ScrollController scrollController;

  const ReplayArtistFeature({
    super.key,
    required this.artist,
    required this.recap,
    required this.scrollController,
    this.options = const ReplayCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReplayCardPalette.resolve(options, ReplayCardKind.artists);
    // Matched from the existing recap only; no invented artist imagery.
    final covers = recap.topSongs
        .where(
          (entry) =>
              entry.song.artist.trim().toLowerCase() ==
              artist.artist.trim().toLowerCase(),
        )
        .map((entry) => entry.song.albumArt)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
    return ReplayCardSurface(
      palette: palette,
      options: options,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top artist', style: _display(palette.foreground, 34)),
            const SizedBox(height: 8),
            Text(
              ReplayStyle.range(recap),
              style: TextStyle(fontSize: 12, color: palette.secondary),
            ),
            const SizedBox(height: 18),
            RepaintBoundary(
              child: ReplayArtworkStage(
                paths: [covers.isEmpty ? null : covers.first],
                color: palette.dark ? palette.accent : palette.foreground,
                scrollController: scrollController,
                layered: false,
                framed: options.surfaceDetail,
                ornaments: options.ornaments,
                badge: options.badges ? ReplayStyle.plays(artist.plays) : null,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              artist.artist,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _display(palette.foreground, 30),
            ),
            const SizedBox(height: 8),
            Text(
              '${artist.uniqueSongs} ${artist.uniqueSongs == 1 ? 'song' : 'songs'} in your rotation',
              style: TextStyle(fontSize: 15, color: palette.secondary),
            ),
            const SizedBox(height: 24),
            Divider(height: 1, color: palette.rule),
            const SizedBox(height: 16),
            Text(
              '${options.badges ? '#1 · ' : ''}${ReplayStyle.plays(artist.plays)}',
              style: TextStyle(fontSize: 13, color: palette.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class ReplayAlbumFeature extends StatelessWidget {
  final RankedRecapAlbum album;
  final ListeningRecap recap;
  final ReplayCardOptions options;
  final ScrollController scrollController;

  const ReplayAlbumFeature({
    super.key,
    required this.album,
    required this.recap,
    required this.scrollController,
    this.options = const ReplayCardOptions(),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReplayCardPalette.resolve(options, ReplayCardKind.album);
    return ReplayCardSurface(
      palette: palette,
      options: options,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top album', style: _display(palette.foreground, 34)),
            const SizedBox(height: 8),
            Text(
              ReplayStyle.range(recap),
              style: TextStyle(fontSize: 12, color: palette.secondary),
            ),
            const SizedBox(height: 18),
            RepaintBoundary(
              child: ReplayArtworkStage(
                paths: [album.representativeSong.albumArt],
                color: palette.accent,
                scrollController: scrollController,
                layered: false,
                framed: options.surfaceDetail,
                ornaments: options.ornaments,
                badge: options.badges ? ReplayStyle.plays(album.plays) : null,
              ),
            ),
            const SizedBox(height: 18),
            Text(album.album, style: _display(palette.foreground, 30)),
            const SizedBox(height: 8),
            Text(
              album.artist,
              style: TextStyle(fontSize: 15, color: palette.secondary),
            ),
            const SizedBox(height: 24),
            Divider(height: 1, color: palette.rule),
            const SizedBox(height: 16),
            Text(
              '${album.uniqueSongs} ${album.uniqueSongs == 1 ? 'song' : 'songs'} · ${ReplayStyle.plays(album.plays)}',
              style: TextStyle(fontSize: 13, color: palette.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
