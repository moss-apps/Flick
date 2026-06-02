import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

/// Artist detail screen showing songs, albums, and most played tracks.
class ArtistDetailScreen extends StatefulWidget {
  final String artistName;
  final List<Song> songs;
  final String? artistArt;
  final String? artistArtSourcePath;
  final PlayerService playerService;

  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    required this.songs,
    required this.artistArt,
    required this.artistArtSourcePath,
    required this.playerService,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final SongRepository _songRepository = SongRepository();
  final RecentlyPlayedRepository _recentlyPlayedRepository =
      RecentlyPlayedRepository();

  List<Song> _mostPlayedSongs = [];
  List<AlbumGroup> _artistAlbums = [];
  bool _isLoadingExtras = true;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final mostPlayed = await _recentlyPlayedRepository
        .getMostPlayedSongsByArtist(widget.artistName, limit: 5);

    final allAlbums = await _songRepository.getAlbumGroups();
    final artistAlbums =
        allAlbums
            .where(
              (a) =>
                  a.albumArtist.toLowerCase() ==
                      widget.artistName.toLowerCase() ||
                  a.songs.any(
                    (s) =>
                        s.artist.toLowerCase() ==
                        widget.artistName.toLowerCase(),
                  ),
            )
            .toList();

    if (mounted) {
      setState(() {
        _mostPlayedSongs = mostPlayed;
        _artistAlbums = artistAlbums;
        _isLoadingExtras = false;
      });
    }
  }

  Map<String, List<Song>> get _albumGroups {
    final groups = <String, List<Song>>{};
    for (final song in widget.songs) {
      final album = song.album ?? 'Unknown Album';
      groups.putIfAbsent(album, () => []).add(song);
    }
    for (final entry in groups.entries) {
      entry.value.sort(_compareAlbumSongs);
    }
    return groups;
  }

  static int _compareAlbumSongs(Song a, Song b) {
    final discA = (a.discNumber != null && a.discNumber! > 0) ? a.discNumber! : 1;
    final discB = (b.discNumber != null && b.discNumber! > 0) ? b.discNumber! : 1;
    final discCompare = discA.compareTo(discB);
    if (discCompare != 0) return discCompare;

    final trackA = (a.trackNumber != null && a.trackNumber! > 0) ? a.trackNumber : null;
    final trackB = (b.trackNumber != null && b.trackNumber! > 0) ? b.trackNumber : null;
    final hasTrackA = trackA != null;
    final hasTrackB = trackB != null;
    if (hasTrackA && hasTrackB) {
      final trackCompare = trackA.compareTo(trackB);
      if (trackCompare != 0) return trackCompare;
    } else if (hasTrackA != hasTrackB) {
      return hasTrackA ? -1 : 1;
    }

    return a.title.compareTo(b.title);
  }

  String? _getArt(List<Song> songs) {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  String? _getSourcePath(List<Song> songs) {
    for (final song in songs) {
      if (song.filePath != null && song.filePath!.isNotEmpty) {
        return song.filePath;
      }
    }
    return null;
  }

  Duration get _totalDuration {
    var total = Duration.zero;
    for (final song in widget.songs) {
      total += song.duration;
    }
    return total;
  }

  String get _formattedTotalDuration {
    final hours = _totalDuration.inHours;
    final minutes = _totalDuration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _openAlbum(AlbumGroup album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumDetailScreen(
          albumName: album.albumName,
          albumArtist: album.albumArtist,
          songs: album.songs,
          albumArt: _getArt(album.songs),
          albumArtSourcePath: _getSourcePath(album.songs),
          playerService: widget.playerService,
        ),
      ),
    );
  }

  void _playSong(Song song, {List<Song>? playlist}) {
    widget.playerService.play(song, playlist: playlist ?? widget.songs);
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'artist_song_${song.id}',
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    widget.playerService.play(widget.songs.first, playlist: widget.songs);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'artist_play_all');
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    widget.playerService.play(shuffled.first, playlist: shuffled);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'artist_shuffle');
  }

  @override
  Widget build(BuildContext context) {
    final albumGroups = _albumGroups;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, albumGroups.length),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.play,
                      label: 'Play All',
                      onTap: _playAll,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.shuffle,
                      label: 'Shuffle',
                      onTap: _shuffleAll,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppConstants.spacingLg),
          ),
          if (_artistAlbums.length > 1)
            _buildSectionTitle(context, 'Albums'),
          if (_artistAlbums.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _artistAlbums.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    width: AppConstants.spacingMd,
                  ),
                  itemBuilder: (context, index) {
                    final album = _artistAlbums[index];
                    return _AlbumCard(
                      albumName: album.albumName,
                      albumArtist: album.albumArtist,
                      songCount: album.songs.length,
                      albumArt: _getArt(album.songs),
                      albumArtSourcePath: _getSourcePath(album.songs),
                      onTap: () => _openAlbum(album),
                    );
                  },
                ),
              ),
            ),
          if (_artistAlbums.length > 1)
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.spacingLg),
            ),
          if (!_isLoadingExtras && _mostPlayedSongs.isNotEmpty)
            _buildSectionTitle(context, 'Most Played'),
          if (!_isLoadingExtras && _mostPlayedSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 72,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _mostPlayedSongs.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    width: AppConstants.spacingMd,
                  ),
                  itemBuilder: (context, index) {
                    final song = _mostPlayedSongs[index];
                    return _MostPlayedCard(
                      song: song,
                      onTap: () => _playSong(song),
                    );
                  },
                ),
              ),
            ),
          if (!_isLoadingExtras && _mostPlayedSongs.isNotEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.spacingLg),
            ),
          _buildSectionTitle(context, 'Songs'),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: AppConstants.navBarHeight + 120,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final albumEntry = albumGroups.entries.toList()[index];
                return _AlbumSection(
                  albumName: albumEntry.key,
                  songs: albumEntry.value,
                  onSongTap: _playSong,
                );
              }, childCount: albumGroups.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, int albumCount) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.artistArt != null || widget.artistArtSourcePath != null)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: CachedImageWidget(
                  imagePath: widget.artistArt,
                  audioSourcePath: widget.artistArtSourcePath,
                  fit: BoxFit.cover,
                  placeholder: Container(color: AppColors.surface),
                  errorWidget: Container(color: AppColors.surface),
                ),
              )
            else
              Container(color: AppColors.surface),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.9),
                    AppColors.background,
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassBackgroundStrong,
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: CachedImageWidget(
                        imagePath: widget.artistArt,
                        audioSourcePath: widget.artistArtSourcePath,
                        fit: BoxFit.cover,
                        placeholder: Icon(
                          LucideIcons.user,
                          size: 40,
                          color: context.adaptiveTextTertiary,
                        ),
                        errorWidget: Icon(
                          LucideIcons.user,
                          size: 40,
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    widget.artistName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.adaptiveTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                        icon: LucideIcons.music,
                        label: '${widget.songs.length} songs',
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      _StatChip(
                        icon: LucideIcons.disc,
                        label: '$albumCount albums',
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      _StatChip(
                        icon: LucideIcons.clock,
                        label: _formattedTotalDuration,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          0,
          AppConstants.spacingLg,
          AppConstants.spacingSm,
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassBackgroundStrong,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.adaptiveTextPrimary, size: 18),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                label,
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.adaptiveTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String albumName;
  final String albumArtist;
  final int songCount;
  final String? albumArt;
  final String? albumArtSourcePath;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.albumName,
    required this.albumArtist,
    required this.songCount,
    required this.albumArt,
    required this.albumArtSourcePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  child: CachedImageWidget(
                    imagePath: albumArt,
                    audioSourcePath: albumArtSourcePath,
                    fit: BoxFit.cover,
                    placeholder: Center(
                      child: Icon(
                        LucideIcons.disc,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                    errorWidget: Center(
                      child: Icon(
                        LucideIcons.disc,
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              albumName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$songCount songs',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MostPlayedCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _MostPlayedCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(AppConstants.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: CachedImageWidget(
                  imagePath: song.albumArt,
                  audioSourcePath: song.filePath,
                  fit: BoxFit.cover,
                  placeholder: Icon(
                    LucideIcons.music,
                    color: context.adaptiveTextTertiary,
                    size: 18,
                  ),
                  errorWidget: Icon(
                    LucideIcons.music,
                    color: context.adaptiveTextTertiary,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.album ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.play,
              color: context.adaptiveTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumSection extends StatelessWidget {
  final String albumName;
  final List<Song> songs;
  final void Function(Song song, {List<Song>? playlist}) onSongTap;

  const _AlbumSection({
    required this.albumName,
    required this.songs,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.disc,
                size: 16,
                color: context.adaptiveTextTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                albumName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...songs.map(
          (song) => _SongTile(
            song: song,
            onTap: () => onSongTap(song, playlist: songs),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    placeholder: Icon(
                      LucideIcons.music,
                      color: context.adaptiveTextTertiary,
                      size: 18,
                    ),
                    errorWidget: Icon(
                      LucideIcons.music,
                      color: context.adaptiveTextTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(
                  song.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                song.formattedDuration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
