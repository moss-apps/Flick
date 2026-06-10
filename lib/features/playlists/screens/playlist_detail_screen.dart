import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/widgets/common/floating_mini_player.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  static const Color _darkBase = Color(0xFF121212);
  static const double _backgroundBlend = 0.22;
  static const double _appBarBlend = 0.30;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).setVisible(true);
      _loadSongs();
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

    if (mounted) {
      setState(() {
        _songs = playlistSongs;
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
    final topSong = mostPlayed ??
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

  void _playSong(Song song) {
    if (_songs.isEmpty) return;
    _playerService.play(song, playlist: _songs);
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'playlist_song_${song.id}',
    );
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    _playerService.play(_songs.first, playlist: _songs);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'playlist_play_all');
  }

  void _shuffleAll() {
    if (_songs.isEmpty) return;
    final shuffled = List<Song>.from(_songs)..shuffle();
    _playerService.play(shuffled.first, playlist: shuffled);
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'playlist_shuffle');
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

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: AppColors.background, end: bgColor),
      duration: AppConstants.animationSlow,
      curve: Curves.easeOut,
      builder: (context, animatedBg, _) {
        final animatedAppBar = _playlistColor == null
            ? AppColors.surface
            : Color.lerp(_darkBase, _playlistColor!, _appBarBlend)!;
        final resolvedBg = animatedBg ?? AppColors.background;
        return Stack(
          children: [
            Scaffold(
          backgroundColor: resolvedBg,
          body: AdaptiveColorProvider(
            backgroundColor: resolvedBg,
            albumDominantColor: _playlistColor,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) => true,
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
                                playlist.name,
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
                                '${_songs.length} songs${_songs.isNotEmpty ? ' • $_formattedTotalDuration' : ''}',
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
                    background: _buildAppBarBackground(
                      context,
                      playlist,
                      resolvedBg,
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
                          label: '${_songs.length} tracks',
                        ),
                        if (_songs.isNotEmpty)
                          _InfoChip(
                            icon: LucideIcons.clock,
                            label: _formattedTotalDuration,
                          ),
                        _InfoChip(
                          icon: LucideIcons.calendar,
                          label: 'Created ${_formatDate(playlist.createdAt)}',
                        ),
                        if (playlist.updatedAt != null &&
                            playlist.updatedAt != playlist.createdAt)
                          _InfoChip(
                            icon: LucideIcons.pencil,
                            label: 'Updated ${_formatDate(playlist.updatedAt)}',
                          ),
                      ],
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
                            size: context.responsiveIcon(AppConstants.iconSizeXl),
                            color: context.adaptiveTextTertiary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          Text(
                            'No songs in this playlist',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: context.adaptiveTextSecondary),
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(
                            'Add songs from the player menu',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.adaptiveTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _buildSectionTitle(context, 'Songs'),
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
                        ref.read(playlistsProvider.notifier).reorderSongs(
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
                          index: index,
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
                        separatorBuilder: (_, __) => const SizedBox(
                          width: AppConstants.spacingMd,
                        ),
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
                    child: SizedBox(height: AppConstants.navBarHeight + 120),
                  ),
                ],
              ],
              ),
              ),
            ),
            ),
            const FloatingMiniPlayer(),
          ],
        );
      },
    );
  }

  Widget _buildAppBarBackground(
    BuildContext context,
    Playlist playlist,
    Color fadeTo,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCollageBackground(),
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
                playlist.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_songs.length} songs${_songs.isNotEmpty ? ' • $_formattedTotalDuration' : ''}',
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

  Widget _buildCollageBackground() {
    if (_songs.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: Icon(
          LucideIcons.listMusic,
          size: 80,
          color: context.adaptiveTextTertiary,
        ),
      );
    }

    final firstArt = _getArt(_songs);
    final firstSource = _getSourcePath(_songs);
    if (firstArt != null) {
      return CachedImageWidget(
        imagePath: firstArt,
        audioSourcePath: firstSource,
        fit: BoxFit.cover,
        placeholder: Container(
          color: AppColors.surface,
          child: Icon(
            LucideIcons.listMusic,
            size: 80,
            color: context.adaptiveTextTertiary,
          ),
        ),
        errorWidget: Container(
          color: AppColors.surface,
          child: Icon(
            LucideIcons.listMusic,
            size: 80,
            color: context.adaptiveTextTertiary,
          ),
        ),
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
                    padding: const EdgeInsets.only(
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Icon(
                      LucideIcons.gripVertical,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ),
                ),
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
