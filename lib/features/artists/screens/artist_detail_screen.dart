import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/widgets/common/floating_mini_player.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/repositories/artist_repository.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/animated_album_art.dart';
import 'package:flick/widgets/common/scroll_fade_wrapper.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';

/// Artist detail screen showing songs, albums, and most played tracks.
class ArtistDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  static const Color _darkBase = Color(0xFF121212);
  static const double _backgroundBlend = 0.22;
  static const double _appBarBlend = 0.30;

  final SongRepository _songRepository = SongRepository();
  final RecentlyPlayedRepository _recentlyPlayedRepository =
      RecentlyPlayedRepository();
  final ArtistRepository _artistRepository = ArtistRepository();
  final ColorExtractionService _colorService = ColorExtractionService();

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarActions = false;

  List<Song> _mostPlayedSongs = [];
  List<AlbumGroup> _artistAlbums = [];
  bool _isLoadingExtras = true;
  String? _artistArt;
  String? _artistArtSourcePath;
  Color? _artistColor;

  @override
  void initState() {
    super.initState();
    _artistArt = widget.artistArt;
    _artistArtSourcePath = widget.artistArtSourcePath;
    _scrollController.addListener(_onScroll);
    _buildAlbumGroups();
    _loadExtras();
    _resolveAndSaveArtistArt();
    _extractArtistColor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(navBarVisibleProvider.notifier).setVisible(true);
    });
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
    final mostPlayed = await _recentlyPlayedRepository
        .getMostPlayedSongsByArtist(widget.artistName, limit: 5);

    final allAlbums = await _songRepository.getAlbumGroups();
    final artistAlbums = allAlbums
        .where(
          (a) => a.albumArtist.toLowerCase() == widget.artistName.toLowerCase(),
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

  Future<void> _resolveAndSaveArtistArt() async {
    final saved = await _artistRepository.getByName(widget.artistName);
    if (!mounted) return;

    if (saved?.artPath != null && saved!.artPath!.isNotEmpty) {
      if (saved.artPath != _artistArt && mounted) {
        setState(() => _artistArt = saved.artPath);
      }
      return;
    }

    if (_artistArt != null && _artistArt!.isNotEmpty) {
      await _artistRepository.setArt(widget.artistName, _artistArt);
      return;
    }

    final sourcePath = _artistArtSourcePath;
    if (sourcePath == null || sourcePath.isEmpty) return;

    final resolved = await AlbumArtService.instance.resolveArtworkPath(
      existingPath: null,
      audioSourcePath: sourcePath,
    );
    if (!mounted || resolved == null || resolved.isEmpty) return;

    setState(() => _artistArt = resolved);
    await _artistRepository.setArt(widget.artistName, resolved);
  }

  Future<void> _extractArtistColor() async {
    final source = _artistArt;
    if (source == null || source.isEmpty) return;
    final color = await _colorService.extractDominantColor(source);
    if (!mounted || color == null) return;
    setState(() => _artistColor = color);
  }

  Color _tintBackground(double blend) {
    if (_artistColor == null) return AppColors.background;
    return Color.lerp(_darkBase, _artistColor!, blend)!;
  }

  late final List<MapEntry<String, List<Song>>> _albumGroups;

  void _buildAlbumGroups() {
    final groups = <String, List<Song>>{};
    for (final song in widget.songs) {
      final album = song.album ?? 'Unknown Album';
      groups.putIfAbsent(album, () => []).add(song);
    }
    for (final entry in groups.entries) {
      entry.value.sort(_compareAlbumSongs);
    }
    _albumGroups = groups.entries.toList();
  }

  static int _compareAlbumSongs(Song a, Song b) {
    final discA = (a.discNumber != null && a.discNumber! > 0)
        ? a.discNumber!
        : 1;
    final discB = (b.discNumber != null && b.discNumber! > 0)
        ? b.discNumber!
        : 1;
    final discCompare = discA.compareTo(discB);
    if (discCompare != 0) return discCompare;

    final trackA = (a.trackNumber != null && a.trackNumber! > 0)
        ? a.trackNumber
        : null;
    final trackB = (b.trackNumber != null && b.trackNumber! > 0)
        ? b.trackNumber
        : null;
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

  PlaybackContext get _artistContext => PlaybackContext(
    source: PlaybackSource.artist,
    sourceId: widget.artistName,
    sourceName: widget.artistName,
  );

  void _playSong(Song song, {List<Song>? playlist}) {
    widget.playerService.play(
      song,
      playlist: playlist ?? widget.songs,
      context: _artistContext,
    );
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'artist_song_${song.id}',
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    widget.playerService.play(
      widget.songs.first,
      playlist: widget.songs,
      context: _artistContext,
    );
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'artist_play_all');
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    widget.playerService.play(
      shuffled.first,
      playlist: shuffled,
      context: _artistContext,
    );
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'artist_shuffle');
  }

  int? get _artistYear {
    int? earliest;
    for (final song in widget.songs) {
      if (song.year != null && song.year! > 0) {
        if (earliest == null || song.year! < earliest) {
          earliest = song.year;
        }
      }
    }
    return earliest;
  }

  String? get _artistGenre {
    for (final song in widget.songs) {
      final genre = song.genre?.trim();
      if (genre != null && genre.isNotEmpty) {
        return genre;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _tintBackground(_backgroundBlend);

    return DisplayModeWrapper(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: AppColors.background, end: bgColor),
        duration: AppConstants.animationSlow,
        curve: Curves.easeOut,
        builder: (context, animatedBg, _) {
          final animatedAppBar = _artistColor == null
              ? AppColors.surface
              : Color.lerp(_darkBase, _artistColor!, _appBarBlend)!;
          final resolvedBg = animatedBg ?? AppColors.background;
          return Stack(
            children: [
              Scaffold(
                backgroundColor: resolvedBg,
                body: AdaptiveColorProvider(
                  backgroundColor: resolvedBg,
                  albumDominantColor: _artistColor,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) => true,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverAppBar(
                          expandedHeight:
                              ref.watch(appPreferencesProvider).detailHeaderArtExpanded
                                  ? 360
                                  : 280,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.artistName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color:
                                                  context.adaptiveTextPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${_albumGroups.length} albums • ${widget.songs.length} songs',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  context.adaptiveTextSecondary,
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
                            background: _buildAppBarBackground(
                              context,
                              resolvedBg,
                              _albumGroups.length,
                            ),
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
                                topRight: Radius.circular(
                                  AppConstants.radiusXl,
                                ),
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
                                  label: '${widget.songs.length} songs',
                                ),
                                _InfoChip(
                                  icon: LucideIcons.clock,
                                  label: _formattedTotalDuration,
                                ),
                                if (_artistYear != null)
                                  _InfoChip(
                                    icon: LucideIcons.calendar,
                                    label: '${_artistYear!}',
                                  ),
                                if (_artistGenre != null)
                                  _InfoChip(
                                    icon: LucideIcons.tags,
                                    label: _artistGenre!,
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
                              height: 200,
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
                                    albumArtSourcePath: _getSourcePath(
                                      album.songs,
                                    ),
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
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final albumEntry = _albumGroups[index];
                              return _AlbumSection(
                                albumName: albumEntry.key,
                                songs: albumEntry.value,
                                onSongTap: _playSong,
                              );
                            }, childCount: _albumGroups.length),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const FloatingMiniPlayer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildArtLayer(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final animated = prefs.animatedAlbumArt && prefs.animationsEnabled;
    final fallback = Container(
      color: AppColors.surface,
      child: Icon(
        LucideIcons.user,
        size: 80,
        color: context.adaptiveTextTertiary,
      ),
    );
    if (!animated) {
      return CachedImageWidget(
        imagePath: _artistArt,
        audioSourcePath: _artistArtSourcePath,
        fit: BoxFit.cover,
        placeholder: fallback,
        errorWidget: fallback,
      );
    }
    return ScrollFadeWrapper(
      scrollController: _scrollController,
      child: AnimatedAlbumArt(
        imagePath: _artistArt,
        audioSourcePath: _artistArtSourcePath,
        dominantColor: _artistColor,
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }

  Widget _buildAppBarBackground(
    BuildContext context,
    Color fadeTo,
    int albumCount,
  ) {
    final prefs = ref.watch(appPreferencesProvider);
    final gradientColors = prefs.detailHeaderArtExpanded
        ? [
            Colors.transparent,
            Colors.transparent,
            fadeTo.withValues(alpha: 0.9),
            fadeTo,
          ]
        : [
            Colors.transparent,
            fadeTo.withValues(alpha: 0.8),
            fadeTo,
          ];
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildArtLayer(context),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: prefs.detailHeaderArtExpanded
                  ? const [0.0, 0.7, 0.92, 1.0]
                  : null,
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
            crossAxisAlignment: prefs.detailHeaderCenteredTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                widget.artistName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$albumCount albums • ${widget.songs.length} songs',
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
    final fg = backgroundColor != null
        ? AppColors.background
        : context.adaptiveTextPrimary;

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

class _AlbumCard extends StatefulWidget {
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
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
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
                      imagePath: widget.albumArt,
                      audioSourcePath: widget.albumArtSourcePath,
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
                widget.albumName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.songCount} songs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MostPlayedCard extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _MostPlayedCard({required this.song, required this.onTap});

  @override
  State<_MostPlayedCard> createState() => _MostPlayedCardState();
}

class _MostPlayedCardState extends State<_MostPlayedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
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
                    imagePath: widget.song.albumArt,
                    audioSourcePath: widget.song.filePath,
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
                      widget.song.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.album ?? '',
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
