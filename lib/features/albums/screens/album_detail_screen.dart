import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/artists/screens/artist_detail_screen.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

/// Album detail screen showing songs, album info, and more from the artist.
class AlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumName;
  final String albumArtist;
  final List<Song> songs;
  final String? albumArt;
  final String? albumArtSourcePath;
  final PlayerService playerService;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.albumArtist,
    required this.songs,
    required this.albumArt,
    required this.albumArtSourcePath,
    required this.playerService,
  });

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  static const Color _darkBase = Color(0xFF121212);
  static const double _backgroundBlend = 0.22;
  static const double _appBarBlend = 0.30;

  final SongRepository _songRepository = SongRepository();
  final ColorExtractionService _colorService = ColorExtractionService();

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarActions = false;

  List<AlbumGroup> _moreAlbums = [];
  Map<String, List<Song>> _moreArtists = {};
  Color? _albumColor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExtras();
    _extractAlbumColor();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 250;
    if (show != _showAppBarActions) {
      setState(() => _showAppBarActions = show);
    }
  }

  Future<void> _loadExtras() async {
    final allAlbums = await _songRepository.getAlbumGroups();
    final allArtists = await _songRepository.getSongsByArtist();

    final moreAlbums =
        allAlbums
            .where(
              (a) =>
                  a.key != _albumKey(widget.albumName) &&
                  (a.albumArtist.toLowerCase() ==
                      widget.albumArtist.toLowerCase()),
            )
            .toList();

    final moreArtists =
        Map<String, List<Song>>.from(allArtists)
          ..remove(widget.albumArtist);

    if (mounted) {
      setState(() {
        _moreAlbums = moreAlbums;
        _moreArtists = moreArtists;
      });
    }
  }

  String _albumKey(String albumName) {
    return albumName;
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

  int? get _albumYear {
    for (final song in widget.songs) {
      if (song.year != null && song.year! > 0) {
        return song.year;
      }
    }
    return null;
  }

  String? get _albumGenre {
    for (final song in widget.songs) {
      final genre = song.genre?.trim();
      if (genre != null && genre.isNotEmpty) {
        return genre;
      }
    }
    return null;
  }

  Future<void> _extractAlbumColor() async {
    String? source = widget.albumArt;
    if (source == null || source.isEmpty) {
      final sourcePath = widget.albumArtSourcePath;
      if (sourcePath == null || sourcePath.isEmpty) return;
      source = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: null,
        audioSourcePath: sourcePath,
      );
      if (source == null || !mounted) return;
    }
    final color = await _colorService.extractDominantColor(source);
    if (!mounted || color == null) return;
    setState(() => _albumColor = color);
  }

  Color _tintBackground(double blend) {
    if (_albumColor == null) return AppColors.background;
    return Color.lerp(_darkBase, _albumColor!, blend)!;
  }

  void _playSong(Song song) {
    widget.playerService.play(song, playlist: widget.songs);
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'album_song_${song.id}',
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    widget.playerService.play(widget.songs.first, playlist: widget.songs);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'album_play_all');
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    widget.playerService.play(shuffled.first, playlist: shuffled);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'album_shuffle');
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

  void _openArtist(String artistName, List<Song> songs) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistDetailScreen(
          artistName: artistName,
          songs: songs,
          artistArt: _getArt(songs),
          artistArtSourcePath: _getSourcePath(songs),
          playerService: widget.playerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _tintBackground(_backgroundBlend);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: AppColors.background, end: bgColor),
      duration: AppConstants.animationSlow,
      curve: Curves.easeOut,
      builder: (context, animatedBg, _) {
        final animatedAppBar = _albumColor == null
            ? AppColors.surface
            : Color.lerp(_darkBase, _albumColor!, _appBarBlend)!;
        final resolvedBg = animatedBg ?? AppColors.background;
        return Scaffold(
          backgroundColor: resolvedBg,
          body: AdaptiveColorProvider(
            backgroundColor: resolvedBg,
            albumDominantColor: _albumColor,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: animatedAppBar,
                  leading: AnimatedOpacity(
                    duration: AppConstants.animationFast,
                    opacity: _showAppBarActions ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_showAppBarActions,
                      child: IconButton(
                        icon: Icon(
                          LucideIcons.arrowLeft,
                          color: context.adaptiveTextPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  titleSpacing: 0,
                  title: Row(
                    children: [
                      Expanded(
                        child: AnimatedOpacity(
                          duration: AppConstants.animationFast,
                          opacity: _showAppBarActions ? 1.0 : 0.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.albumName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: context.adaptiveTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.albumArtist} • ${widget.songs.length} songs',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: context.adaptiveTextSecondary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: AppConstants.animationFast,
                        opacity: _showAppBarActions ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_showAppBarActions,
                          child: IconButton(
                            icon: Icon(
                              LucideIcons.play,
                              color: context.adaptiveTextPrimary,
                              size: 20,
                            ),
                            onPressed: _playAll,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: AppConstants.animationFast,
                        opacity: _showAppBarActions ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_showAppBarActions,
                          child: IconButton(
                            icon: Icon(
                              LucideIcons.shuffle,
                              color: context.adaptiveTextPrimary,
                              size: 20,
                            ),
                            onPressed: _shuffleAll,
                          ),
                        ),
                      ),
                    ],
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildAppBarBackground(context, resolvedBg),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppConstants.spacingMd),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: resolvedBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppConstants.radiusXl),
                        topRight: Radius.circular(AppConstants.radiusXl),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingLg,
                      vertical: AppConstants.spacingMd,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: LucideIcons.play,
                            label: 'Play All',
                            onTap: _playAll,
                            backgroundColor: AppColors.accent,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingLg,
                    ),
                    child: Wrap(
                      spacing: AppConstants.spacingSm,
                      runSpacing: AppConstants.spacingSm,
                      children: [
                        _InfoChip(
                          icon: LucideIcons.music,
                          label: '${widget.songs.length} tracks',
                        ),
                        _InfoChip(
                          icon: LucideIcons.clock,
                          label: _formattedTotalDuration,
                        ),
                        if (_albumYear != null)
                          _InfoChip(
                            icon: LucideIcons.calendar,
                            label: '${_albumYear!}',
                          ),
                        if (_albumGenre != null)
                          _InfoChip(
                            icon: LucideIcons.tags,
                            label: _albumGenre!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppConstants.spacingLg),
                ),
                _buildSectionTitle(context, 'Songs'),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: AppConstants.navBarHeight + 80,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = widget.songs[index];
                      return _SongTile(
                        song: song,
                        onTap: () => _playSong(song),
                      );
                    }, childCount: widget.songs.length),
                  ),
                ),
                if (_moreAlbums.isNotEmpty) ...[
                  _buildSectionTitle(
                    context,
                    'More from ${widget.albumArtist}',
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingLg,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: _moreAlbums.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          width: AppConstants.spacingMd,
                        ),
                        itemBuilder: (context, index) {
                          final album = _moreAlbums[index];
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
                ],
                if (_moreArtists.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppConstants.spacingLg),
                  ),
                  _buildSectionTitle(context, 'More Artists'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingLg,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: _moreArtists.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          width: AppConstants.spacingMd,
                        ),
                        itemBuilder: (context, index) {
                          final entry = _moreArtists.entries.toList()[index];
                          return _ArtistCard(
                            artistName: entry.key,
                            songs: entry.value,
                            onTap: () => _openArtist(entry.key, entry.value),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppConstants.navBarHeight + 120),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBarBackground(BuildContext context, Color fadeTo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedImageWidget(
          imagePath: widget.albumArt,
          audioSourcePath: widget.albumArtSourcePath,
          fit: BoxFit.cover,
          placeholder: Container(
            color: AppColors.surface,
            child: Icon(
              LucideIcons.disc,
              size: 80,
              color: context.adaptiveTextTertiary,
            ),
          ),
          errorWidget: Container(
            color: AppColors.surface,
            child: Icon(
              LucideIcons.disc,
              size: 80,
              color: context.adaptiveTextTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                fadeTo.withValues(alpha: 0.8),
                fadeTo,
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 16,
          child: IconButton(
            icon: Icon(
              LucideIcons.arrowLeft,
              color: context.adaptiveTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: AppConstants.spacingLg,
          right: AppConstants.spacingLg,
          bottom: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.albumName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.albumArtist} • ${widget.songs.length} songs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
  final Color? backgroundColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.glassBackgroundStrong;
    final fg = backgroundColor != null ? AppColors.background : context.adaptiveTextPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                label,
                style: TextStyle(
                  color: fg,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.adaptiveTextSecondary),
          const SizedBox(width: 6),
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
                width: context.scaleSize(AppConstants.containerSizeMd),
                height: context.scaleSize(AppConstants.containerSizeMd),
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
                      size: context.responsiveIcon(AppConstants.iconSizeMd),
                    ),
                    errorWidget: Icon(
                      LucideIcons.music,
                      color: context.adaptiveTextTertiary,
                      size: context.responsiveIcon(AppConstants.iconSizeMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
        width: 150,
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

class _ArtistCard extends StatelessWidget {
  final String artistName;
  final List<Song> songs;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.artistName,
    required this.songs,
    required this.onTap,
  });

  String? _getArt() {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  String? _getSourcePath() {
    for (final song in songs) {
      if (song.filePath != null && song.filePath!.isNotEmpty) {
        return song.filePath;
      }
    }
    return null;
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final uniqueAlbums = songs.map((s) => s.album ?? 'Unknown').toSet().length;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLight,
                border: Border.all(color: AppColors.surfaceDark, width: 2),
              ),
              child: ClipOval(
                child: CachedImageWidget(
                  imagePath: _getArt(),
                  audioSourcePath: _getSourcePath(),
                  fit: BoxFit.cover,
                  placeholder: Center(
                    child: Text(
                      _getInitials(artistName),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  errorWidget: Center(
                    child: Text(
                      _getInitials(artistName),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              artistName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '${songs.length} songs • $uniqueAlbums albums',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
