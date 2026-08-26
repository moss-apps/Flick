import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/common/animated_album_art.dart';
import 'package:flick/widgets/common/scroll_fade_wrapper.dart';
import 'package:flick/widgets/common/detail_header.dart';
import 'package:flick/features/player/widgets/add_to_playlist_sheet.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';
import 'package:flick/providers/favorites_provider.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';

/// Detail screen for generated smart mixes (On Repeat, Heavy Rotation, etc.),
/// styled after the playlist/album/artist detail screens.
class SmartMixDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> brandColors;
  final List<Song> songs;

  const SmartMixDetailScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.brandColors,
    required this.songs,
  });

  @override
  ConsumerState<SmartMixDetailScreen> createState() =>
      _SmartMixDetailScreenState();
}

class _SmartMixDetailScreenState extends ConsumerState<SmartMixDetailScreen>
    with ArtworkExtractionScrollGate {
  static const Color _darkBase = Color(0xFF121212);
  static const double _backgroundBlend = 0.22;

  final PlayerService _playerService = PlayerService();
  final ColorExtractionService _colorService = ColorExtractionService();

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarActions = false;

  Color? _mixColor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _extractMixColor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).setVisible(true);
    });
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

  bool get _hasLossless {
    const losslessTypes = {'FLAC', 'WAV', 'ALAC', 'AIFF', 'APE', 'WV'};
    for (final song in widget.songs) {
      if (song.isDsd) return true;
      if (losslessTypes.contains(song.fileType.toUpperCase())) return true;
      if ((song.bitDepth ?? 0) >= 24) return true;
      if ((song.sampleRate ?? 0) >= 88200) return true;
    }
    return false;
  }

  String? get _metaLine {
    final parts = [
      if (widget.songs.isNotEmpty) '${widget.songs.length} songs',
      if (widget.songs.isNotEmpty) _formattedTotalDuration,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _getArt(List<Song> songs) {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  String? _getSourcePath() {
    for (final song in widget.songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        final fp = song.filePath;
        if (fp != null && fp.isNotEmpty) return fp;
      }
    }
    for (final song in widget.songs) {
      if (song.filePath != null && song.filePath!.isNotEmpty) {
        return song.filePath;
      }
    }
    return null;
  }

  Future<void> _extractMixColor() async {
    String? source = _getArt(widget.songs);
    if (source == null) {
      final sourcePath = _getSourcePath();
      if (sourcePath == null || sourcePath.isEmpty) return;
      source = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: null,
        audioSourcePath: sourcePath,
      );
      if (source == null || !mounted) return;
    }
    final color = await _colorService.extractDominantColor(source);
    if (!mounted || color == null) return;
    setState(() => _mixColor = color);
  }

  Color _tintBackground(double blend) {
    if (_mixColor == null) return AppColors.background;
    return Color.lerp(_darkBase, _mixColor!, blend)!;
  }

  PlaybackContext get _mixContext => PlaybackContext(
    source: PlaybackSource.playlist,
    sourceId: widget.title,
    sourceName: widget.title,
  );

  void _playSong(Song song) {
    if (widget.songs.isEmpty) return;
    _playerService.play(song, playlist: widget.songs, context: _mixContext);
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'smart_mix_song_${song.id}',
    );
  }

  void _playAll() {
    if (widget.songs.isEmpty) return;
    _playerService.play(
      widget.songs.first,
      playlist: widget.songs,
      context: _mixContext,
    );
    NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'smart_mix_play_all',
    );
  }

  void _shuffleAll() {
    if (widget.songs.isEmpty) return;
    final shuffled = List<Song>.from(widget.songs)..shuffle();
    _playerService.play(
      shuffled.first,
      playlist: shuffled,
      context: _mixContext,
    );
    NavigationHelper.navigateToFullPlayer(context, heroTag: 'smart_mix_shuffle');
  }

  Future<void> _queueAll() async {
    if (widget.songs.isEmpty) return;
    for (final song in widget.songs) {
      await _playerService.addToQueue(song);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued ${widget.songs.length} songs'),
        action: SnackBarAction(
          label: 'View queue',
          onPressed: () => NavigationHelper.navigateToQueue(context),
        ),
      ),
    );
  }

  bool get _isAllFavorites {
    final favs = ref.watch(favoritesProvider).value;
    if (favs == null || widget.songs.isEmpty) return false;
    return widget.songs.every((s) => favs.isFavorite(s.id));
  }

  Future<void> _toggleFavoriteAll() async {
    if (widget.songs.isEmpty) return;
    final favIds = ref.read(favoritesProvider).value?.favoriteIds ?? const <String>{};
    final notifier = ref.read(favoritesProvider.notifier);
    final isAll = widget.songs.every((s) => favIds.contains(s.id));
    if (isAll) {
      for (final song in widget.songs) {
        await notifier.removeFavorite(song.id);
      }
    } else {
      for (final song in widget.songs) {
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
              ? 'Removed ${widget.songs.length} songs from favorites'
              : 'Added ${widget.songs.length} songs to favorites',
        ),
      ),
    );
  }

  void _showMore() {
    DetailMoreSheet.show(
      context,
      items: [
        DetailMoreSheetItem(
          icon: LucideIcons.listPlus,
          label: 'Add to playlist',
          onTap: () => AddToPlaylistSheet.showSongs(context, widget.songs),
        ),
        DetailMoreSheetItem(
          icon: LucideIcons.moonStar,
          label: 'Sleep timer',
          onTap: () => SleepTimerBottomSheet.show(context, _playerService),
        ),
      ],
    );
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
          final resolvedBg = animatedBg ?? AppColors.background;
          final prefs = ref.watch(appPreferencesProvider);
          return Stack(
            children: [
              Scaffold(
                backgroundColor: resolvedBg,
                body: AdaptiveColorProvider(
                  backgroundColor: resolvedBg,
                  albumDominantColor: _mixColor,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: onScrollNotification,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        DetailHeader(
                          expanded: prefs.detailHeaderArtExpanded,
                          centeredTitle: prefs.detailHeaderCenteredTitle,
                          artBuilder: _buildArtLayer,
                          title: widget.title,
                          subtitle: widget.description,
                          subtitleMaxLines: 2,
                          meta: _metaLine,
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
                              primaryColor: _mixColor,
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
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final song = widget.songs[index];
                              return _SongTile(
                                song: song,
                                onTap: () => _playSong(song),
                              );
                            }, childCount: widget.songs.length),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildOverlayTopBar(context, resolvedBg),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverlayTopBar(BuildContext context, Color bg) {
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
                        widget.title,
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
                        '${widget.songs.length} songs${widget.songs.isNotEmpty ? ' • $_formattedTotalDuration' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.adaptiveTextSecondary),
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

  List<String> _distinctArts() {
    final arts = <String>[];
    for (final song in widget.songs) {
      final art = song.albumArt;
      if (art != null && art.isNotEmpty && !arts.contains(art)) {
        arts.add(art);
        if (arts.length == 4) break;
      }
    }
    return arts;
  }

  Widget _buildArtLayer(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.brandColors,
        ),
      ),
      child: Center(
        child: Icon(
          widget.icon,
          size: 80,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );

    final arts = _distinctArts();
    if (arts.isEmpty) return fallback;

    if (arts.length == 1) {
      final prefs = ref.watch(appPreferencesProvider);
      final animated = prefs.animatedAlbumArt && prefs.animationsEnabled;
      if (animated) {
        return ScrollFadeWrapper(
          scrollController: _scrollController,
          child: AnimatedAlbumArt(
            imagePath: arts.first,
            audioSourcePath: _getSourcePath(),
            dominantColor: _mixColor,
            placeholder: fallback,
            errorWidget: fallback,
          ),
        );
      }
      return CachedImageWidget(
        imagePath: arts.first,
        audioSourcePath: _getSourcePath(),
        fit: BoxFit.cover,
        placeholder: fallback,
        errorWidget: fallback,
      );
    }

    // ponytail: cycle the available arts to fill 2x2; proper collage layout if mixes ever need >4
    Widget cell(int index) {
      return CachedImageWidget(
        imagePath: arts[index % arts.length],
        fit: BoxFit.cover,
      );
    }

    return Column(
      children: [
        Expanded(child: Row(children: [Expanded(child: cell(0)), Expanded(child: cell(1))])),
        Expanded(child: Row(children: [Expanded(child: cell(2)), Expanded(child: cell(3))])),
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
                    placeholder: const FlickArtworkPlaceholder(size: 28, opacity: 0.9),
                    errorWidget: const FlickArtworkPlaceholder(size: 28, opacity: 0.9),
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
