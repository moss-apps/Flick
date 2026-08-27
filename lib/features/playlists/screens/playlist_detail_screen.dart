import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/animated_album_art.dart';
import 'package:flick/widgets/common/scroll_fade_wrapper.dart';
import 'package:flick/widgets/common/song_tile_thumbnail.dart';
import 'package:flick/widgets/common/detail_header.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';
import 'package:flick/providers/favorites_provider.dart';
import 'package:flick/widgets/common/surface_icon_button.dart';
import 'package:flick/features/playlists/widgets/playlist_sort_bottom_sheet.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen>
    with ArtworkExtractionScrollGate {
  static const Color _darkBase = Color(0xFF121212);
  static const double _backgroundBlend = 0.22;
  static const String _sortPrefsKeyPrefix = 'playlist_sort_';

  final PlayerService _playerService = PlayerService();
  final SongRepository _songRepository = SongRepository();
  final RecentlyPlayedRepository _recentlyPlayedRepository =
      RecentlyPlayedRepository();
  final ColorExtractionService _colorService = ColorExtractionService();

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarActions = false;

  List<Song> _songs = [];
  bool _isLoading = true;
  Color? _playlistColor;
  PlaylistSortOption _sortOption = PlaylistSortOption.manual;

  String get _sortPrefsKey => '$_sortPrefsKeyPrefix${widget.playlist.id}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).setVisible(true);
      unawaited(_init());
    });
  }

  Future<void> _init() async {
    await _loadSortOption();
    await _loadSongs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    disposeArtworkGate();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 250;
    if (show != _showAppBarActions) {
      setState(() => _showAppBarActions = show);
    }
  }

  Playlist get _currentPlaylist {
    return ref.watch(playlistProvider(widget.playlist.id)) ?? widget.playlist;
  }

  Duration get _totalDuration {
    var total = Duration.zero;
    for (final song in _songs) {
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool get _hasLossless {
    const losslessTypes = {'FLAC', 'WAV', 'ALAC', 'AIFF', 'APE', 'WV'};
    for (final song in _songs) {
      if (song.isDsd) return true;
      if (losslessTypes.contains(song.fileType.toUpperCase())) return true;
      if ((song.bitDepth ?? 0) >= 24) return true;
      if ((song.sampleRate ?? 0) >= 88200) return true;
    }
    return false;
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sortPrefsKey);
    if (value == null) return;
    final option = PlaylistSortOption.values.firstWhere(
      (o) => o.name == value,
      orElse: () => PlaylistSortOption.manual,
    );
    if (mounted && option != _sortOption) {
      setState(() => _sortOption = option);
    }
  }

  void _setSortOption(PlaylistSortOption option) {
    if (option == _sortOption) return;
    final playlist = _currentPlaylist;
    final byId = {for (final song in _songs) song.id: song};
    final baseSongs = <Song>[
      for (final id in playlist.songIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    final reorderedSongs = sortPlaylistSongs(
      songs: baseSongs,
      playlist: playlist,
      option: option,
    );
    setState(() {
      _sortOption = option;
      _songs = reorderedSongs;
    });
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_sortPrefsKey, option.name),
      ),
    );
  }

  Future<void> _loadSongs() async {
    final playlist = _currentPlaylist;
    if (playlist.songIds.isEmpty) {
      if (mounted) {
        setState(() {
          _songs = [];
          _isLoading = false;
        });
      }
      return;
    }

    final allSongs = await _songRepository.getAllSongs();
    final playlistSongs = allSongs
        .where((song) => playlist.songIds.contains(song.id))
        .toList();

    playlistSongs.sort((a, b) {
      final indexA = playlist.songIds.indexOf(a.id);
      final indexB = playlist.songIds.indexOf(b.id);
      return indexA.compareTo(indexB);
    });

    final sortedSongs = sortPlaylistSongs(
      songs: playlistSongs,
      playlist: playlist,
      option: _sortOption,
    );

    if (mounted) {
      setState(() {
        _songs = sortedSongs;
        _isLoading = false;
      });
    }

    unawaited(_extractPlaylistColor(playlist.songIds));
  }

  Future<void> _extractPlaylistColor(List<String> songIds) async {
    if (songIds.isEmpty) return;

    final mostPlayed = await _recentlyPlayedRepository.getMostPlayedSongAmong(
      songIds,
    );
    final topSong =
        mostPlayed ??
        _songs.firstWhere(
          (s) => s.albumArt != null && s.albumArt!.isNotEmpty,
          orElse: () => _songs.isEmpty
              ? throw StateError('empty playlist')
              : _songs.first,
        );

    String? source = topSong.albumArt;
    if (source == null || source.isEmpty) {
      final sourcePath = topSong.filePath;
      if (sourcePath == null || sourcePath.isEmpty) return;
      source = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: null,
        audioSourcePath: sourcePath,
      );
      if (source == null || !mounted) return;
    }
    final color = await _colorService.extractDominantColor(source);
    if (!mounted || color == null) return;
    setState(() => _playlistColor = color);
  }

  Color _tintBackground(double blend) {
    if (_playlistColor == null) return AppColors.background;
    return Color.lerp(_darkBase, _playlistColor!, blend)!;
  }

  PlaybackContext get _playlistContext => PlaybackContext(
    source: PlaybackSource.playlist,
    sourceId: widget.playlist.id,
    sourceName: widget.playlist.name,
  );

  void _playSong(Song song) {
    if (_songs.isEmpty) return;
    _playerService.play(song, playlist: _songs, context: _playlistContext);
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'playlist_song_${song.id}',
    );
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    _playerService.play(
      _songs.first,
      playlist: _songs,
      context: _playlistContext,
    );
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'playlist_play_all',
    );
  }

  void _shuffleAll() {
    if (_songs.isEmpty) return;
    final shuffled = List<Song>.from(_songs)..shuffle();
    _playerService.play(
      shuffled.first,
      playlist: shuffled,
      context: _playlistContext,
    );
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'playlist_shuffle');
  }

  Future<void> _queueAll() async {
    if (_songs.isEmpty) return;
    for (final song in _songs) {
      await _playerService.addToQueue(song);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued ${_songs.length} songs'),
        action: SnackBarAction(
          label: 'View queue',
          onPressed: () => NavigationHelper.navigateToQueue(context),
        ),
      ),
    );
  }

  bool get _isAllFavorites {
    final favs = ref.watch(favoritesProvider).value;
    if (favs == null || _songs.isEmpty) return false;
    return _songs.every((s) => favs.isFavorite(s.id));
  }

  Future<void> _toggleFavoriteAll() async {
    if (_songs.isEmpty) return;
    final favIds = ref.read(favoritesProvider).value?.favoriteIds ?? const <String>{};
    final notifier = ref.read(favoritesProvider.notifier);
    final isAll = _songs.every((s) => favIds.contains(s.id));
    if (isAll) {
      for (final song in _songs) {
        await notifier.removeFavorite(song.id);
      }
    } else {
      for (final song in _songs) {
        if (!favIds.contains(song.id)) {
          await notifier.addFavorite(song.id);
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAll
              ? 'Removed ${_songs.length} songs from favorites'
              : 'Added ${_songs.length} songs to favorites',
        ),
      ),
    );
  }

  void _showMore() {
    DetailMoreSheet.show(
      context,
      items: [
        DetailMoreSheetItem(
          icon: LucideIcons.arrowDownAZ,
          label: 'Sort songs',
          onTap: () => PlaylistSortBottomSheet.show(
            context,
            currentSort: _sortOption,
            onSortChanged: _setSortOption,
          ),
        ),
        DetailMoreSheetItem(
          icon: LucideIcons.moonStar,
          label: 'Sleep timer',
          onTap: () => SleepTimerBottomSheet.show(context, _playerService),
        ),
      ],
    );
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _currentPlaylist;
    final allPlaylists =
        ref.watch(playlistsProvider).value?.playlists ?? const <Playlist>[];
    final otherPlaylists = allPlaylists
        .where((p) => p.id != playlist.id)
        .toList();
    final bgColor = _tintBackground(_backgroundBlend);
    final meta = [
      if (_songs.isNotEmpty) '${_songs.length} songs',
      if (_songs.isNotEmpty) _formattedTotalDuration,
      'Created ${_formatDate(playlist.createdAt)}',
      if (playlist.updatedAt != null &&
          playlist.updatedAt != playlist.createdAt)
        'Updated ${_formatDate(playlist.updatedAt)}',
    ].join(' · ');

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: AppColors.background, end: bgColor),
      duration: AppConstants.animationSlow,
      curve: Curves.easeOut,
      builder: (context, animatedBg, _) {
        final resolvedBg = animatedBg ?? AppColors.background;
        final prefs = ref.watch(appPreferencesProvider);
        return Stack(
          children: [
            Scaffold(
              backgroundColor: resolvedBg,
              body: AdaptiveColorProvider(
                backgroundColor: resolvedBg,
                albumDominantColor: _playlistColor,
                child: NotificationListener<ScrollNotification>(
                  onNotification: onScrollNotification,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      DetailHeader(
                        expanded: prefs.detailHeaderArtExpanded,
                        centeredTitle: prefs.detailHeaderCenteredTitle,
                        artBuilder: (_) => _buildCollageBackground(),
                        title: playlist.name,
                        subtitle: null,
                        meta: meta,
                        lossless: _hasLossless,
                        fadeTo: resolvedBg,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppConstants.spacingMd),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingLg,
                            vertical: AppConstants.spacingXxs,
                          ),
                          child: DetailActionCapsule(
                            isFavorite: _isAllFavorites,
                            onToggleFavorite: _toggleFavoriteAll,
                            onShuffle: _shuffleAll,
                            onPlay: _playAll,
                            onQueue: _queueAll,
                            onMore: _showMore,
                            primaryColor: _playlistColor,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppConstants.spacingLg),
                      ),
                      if (_isLoading)
                        SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: context.adaptiveTextSecondary,
                            ),
                          ),
                        )
                      else if (_songs.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.music,
                                  size: context.responsiveIcon(
                                    AppConstants.iconSizeXl,
                                  ),
                                  color: context.adaptiveTextTertiary
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: AppConstants.spacingMd),
                                Text(
                                  'No songs in this playlist',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: context.adaptiveTextSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppConstants.spacingSm),
                                Text(
                                  'Add songs from the player menu',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.adaptiveTextTertiary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        _buildSectionTitle(
                          context,
                          'Songs',
                          trailing: _buildSortButton(context),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.only(
                            bottom: AppConstants.navBarHeight + 80,
                          ),
                          sliver: SliverReorderableList(
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                elevation: 4,
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                                child: child,
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              if (_sortOption != PlaylistSortOption.manual) {
                                return;
                              }
                              ref
                                  .read(playlistsProvider.notifier)
                                  .reorderSongs(
                                    widget.playlist.id,
                                    oldIndex,
                                    newIndex,
                                  );
                              setState(() {
                                var adjustedNew = newIndex;
                                if (oldIndex < adjustedNew) adjustedNew -= 1;
                                final item = _songs.removeAt(oldIndex);
                                _songs.insert(adjustedNew, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              return _SongTile(
                                key: ValueKey(song.id),
                                song: song,
                                index: _sortOption == PlaylistSortOption.manual
                                    ? index
                                    : null,
                                onTap: () => _playSong(song),
                                onRemove: () async {
                                  await ref
                                      .read(playlistsProvider.notifier)
                                      .removeSongFromPlaylist(
                                        widget.playlist.id,
                                        song.id,
                                      );
                                  _loadSongs();
                                },
                              );
                            },
                            itemCount: _songs.length,
                          ),
                        ),
                      ],
                      if (otherPlaylists.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Other Playlists'),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 180,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingLg,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: otherPlaylists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppConstants.spacingMd),
                              itemBuilder: (context, index) {
                                final other = otherPlaylists[index];
                                return _PlaylistCard(
                                  playlist: other,
                                  onTap: () => _openPlaylist(other),
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: AppConstants.navBarHeight + 120,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildOverlayTopBar(context, resolvedBg),
          ],
        );
      },
    );
  }

  Widget _buildOverlayTopBar(BuildContext context, Color bg) {
    final playlist = _currentPlaylist;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: AppConstants.animationFast,
        opacity: _showAppBarActions ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showAppBarActions,
          child: Container(
            color: bg,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    LucideIcons.chevronLeft,
                    color: context.adaptiveTextPrimary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.adaptiveTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_songs.length} songs${_songs.isNotEmpty ? ' • $_formattedTotalDuration' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.play,
                    color: context.adaptiveTextPrimary,
                    size: 20,
                  ),
                  onPressed: _playAll,
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.shuffle,
                    color: context.adaptiveTextPrimary,
                    size: 20,
                  ),
                  onPressed: _shuffleAll,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollageBackground() {
    final fallback = Container(
      color: AppColors.surface,
      child: Icon(
        LucideIcons.listMusic,
        size: 80,
        color: context.adaptiveTextTertiary,
      ),
    );
    if (_songs.isEmpty) {
      return fallback;
    }

    final firstArt = _getArt(_songs);
    final firstSource = _getSourcePath(_songs);
    if (firstArt != null) {
      final prefs = ref.watch(appPreferencesProvider);
      final animated = prefs.animatedAlbumArt && prefs.animationsEnabled;
      if (animated) {
        return ScrollFadeWrapper(
          scrollController: _scrollController,
          child: AnimatedAlbumArt(
            imagePath: firstArt,
            audioSourcePath: firstSource,
            dominantColor: _playlistColor,
            placeholder: fallback,
            errorWidget: fallback,
          ),
        );
      }
      return CachedImageWidget(
        imagePath: firstArt,
        audioSourcePath: firstSource,
        fit: BoxFit.cover,
        placeholder: fallback,
        errorWidget: fallback,
      );
    }

    return Container(
      color: AppColors.surface,
      child: Icon(
        LucideIcons.listMusic,
        size: 80,
        color: context.adaptiveTextTertiary,
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          0,
          AppConstants.spacingLg,
          AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    final isSorted = _sortOption != PlaylistSortOption.manual;
    return SurfaceIconButton.icon(
      icon: LucideIcons.arrowDownAZ,
      compact: true,
      iconColor: isSorted ? AppColors.accent : context.adaptiveTextSecondary,
      onPressed: () {
        PlaylistSortBottomSheet.show(
          context,
          currentSort: _sortOption,
          onSortChanged: _setSortOption,
        );
      },
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int? index;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SongTile({
    super.key,
    required this.song,
    this.index,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingMd,
          ),
          child: Row(
            children: [
              if (index != null)
                ReorderableDragStartListener(
                  index: index!,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                    child: Icon(
                      LucideIcons.gripVertical,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ),
                ),
              SongTileThumbnail(
                song: song,
                trackNumber: index != null ? index! + 1 : null,
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
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  LucideIcons.ellipsisVertical,
                  color: context.adaptiveTextTertiary,
                  size: context.responsiveIcon(AppConstants.iconSizeSm),
                ),
                color: AppColors.surface,
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Remove from playlist',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

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
                  child: Icon(
                    LucideIcons.listMusic,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              playlist.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${playlist.songIds.length} songs',
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
