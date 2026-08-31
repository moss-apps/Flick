import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/common/glass_search_bar.dart';
import 'package:flick/features/songs/widgets/song_actions_bottom_sheet.dart';
import 'package:flick/features/search/models/search_category.dart';
import 'package:flick/features/search/models/global_search_results.dart';
import 'package:flick/features/search/providers/global_search_provider.dart';
import 'package:flick/features/search/providers/search_filter_provider.dart';
import 'package:flick/features/search/widgets/search_filter_chips.dart';
import 'package:flick/features/artists/screens/artist_detail_screen.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/features/playlists/screens/playlist_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _songRepository = SongRepository();
  Timer? _debounce;
  String _debouncedQuery = '';
  final Map<SearchCategory, bool> _expanded = {};

  static const int _previewLimit = 4;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // Trigger rebuild for hasInput (clear button) immediately.
    setState(() {});
    if (value.trim().isEmpty) {
      if (_debouncedQuery.isNotEmpty) {
        setState(() => _debouncedQuery = '');
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (mounted && q != _debouncedQuery) {
        setState(() => _debouncedQuery = q);
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _debouncedQuery = '');
  }

  bool _isExpanded(SearchCategory cat) => _expanded[cat] ?? false;
  void _toggleExpanded(SearchCategory cat) {
    setState(() => _expanded[cat] = !_isExpanded(cat));
  }

  @override
  Widget build(BuildContext context) {
    final autoFocus = ref.watch(appPreferencesProvider).autoFocusSearch;

    ref.listen(navigationIndexProvider, (prev, next) {
      if (next == NavBarButton.search.pageIndex && autoFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      } else if (prev == NavBarButton.search.pageIndex) {
        _focusNode.unfocus();
      }
    });

    final enabled = ref.watch(searchFilterProvider);
    final isAllEnabled =
        enabled.length == SearchCategory.values.length;
    final repoQuery = _debouncedQuery;
    final hasInput = _controller.text.trim().isNotEmpty;
    final hasQuery = repoQuery.isNotEmpty;
    final resultsAsync =
        hasQuery ? ref.watch(globalSearchResultsProvider(repoQuery)) : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glass search bar inside gradient container (songs/artists parity).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xBF1E1E1E),
                      Color(0xD9141414),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: GlassSearchBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: autoFocus,
                  textInputAction: TextInputAction.search,
                  hintText: 'Search songs, artists, albums...',
                  showBackground: false,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
              ),
            ),
            // Poweramp-style horizontal chip shelf.
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(
                builder: (context) {
                  final counts = resultsAsync?.value?.counts;
                  return SearchFilterChips(
                    enabled: enabled,
                    isAllEnabled: isAllEnabled,
                    onToggle: (cat) =>
                        ref.read(searchFilterProvider.notifier).toggle(cat),
                    onToggleAll: () =>
                        ref.read(searchFilterProvider.notifier).toggleAll(),
                    counts: counts,
                    query: repoQuery,
                  );
                },
              ),
            ),
            Expanded(
              child: !hasInput
                  ? _buildEmptyState(context)
                  : _buildResultsArea(
                      context,
                      hasQuery: hasQuery,
                      resultsAsync: resultsAsync,
                      enabled: enabled,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea(
    BuildContext context, {
    required bool hasQuery,
    required AsyncValue<GlobalSearchResults>? resultsAsync,
    required Set<SearchCategory> enabled,
  }) {
    if (!hasQuery) {
      // Debounce in-flight – show spinner if user typed but not yet committed.
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.textTertiary,
          strokeWidth: 2,
        ),
      );
    }
    final async = resultsAsync!;
    return async.when(
      data: (results) {
        if (enabled.isEmpty) {
          return _buildFilteredEmpty(context);
        }
        // Check if no enabled category has results.
        final anyEnabledHasResults = SearchCategory.values.any(
          (c) => enabled.contains(c) && results.hasResultsFor(c),
        );
        if (!anyEnabledHasResults) {
          return _buildNoResults(context, results.query);
        }
        return _buildGroupedResults(context, results, enabled);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppColors.textTertiary,
          strokeWidth: 2,
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Text(
            'Search failed: $e',
            style: TextStyle(color: context.adaptiveTextTertiary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 48,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Search your library',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: context.adaptiveTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find songs, artists, albums, folders…',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 13,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap chips to filter categories',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 11,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 48,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: context.adaptiveTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try another keyword or enable more categories',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.slidersHorizontal,
            size: 48,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No categories selected',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: context.adaptiveTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap All or enable a chip to see results',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedResults(
    BuildContext context,
    GlobalSearchResults results,
    Set<SearchCategory> enabled,
  ) {
    final slivers = <Widget>[];
    void addSection({
      required SearchCategory cat,
      required int count,
      required List<Widget> Function() buildItems,
    }) {
      if (!enabled.contains(cat) || count == 0) return;
      final expanded = _isExpanded(cat);
      final showSeeAll = count > _previewLimit;
      slivers.add(_SectionHeader(
        category: cat,
        count: count,
        showSeeAll: showSeeAll,
        expanded: expanded,
        onToggle: () => _toggleExpanded(cat),
      ));
      slivers.addAll(buildItems());
      if (showSeeAll && !expanded) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                2,
                AppConstants.spacingLg,
                AppConstants.spacingSm,
              ),
              child: GestureDetector(
                onTap: () => _toggleExpanded(cat),
                child: Text(
                  'See all $count',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    }

    addSection(
      cat: SearchCategory.songs,
      count: results.songs.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.songs);
        final visible = expanded
            ? results.songs
            : results.songs.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) => _SongTile(
              song: visible[i],
              playlistForMode: results.songs,
              repository: _songRepository,
              onPlay: _playSong,
            ),
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.artists,
      count: results.artists.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.artists);
        final visible = expanded
            ? results.artists
            : results.artists.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) {
              final entry = visible[i];
              return _ArtistTile(
                name: entry.key,
                songs: entry.value,
                onTap: () => _openArtist(context, entry.key, entry.value),
              );
            },
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.albums,
      count: results.albums.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.albums);
        final visible = expanded
            ? results.albums
            : results.albums.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) {
              final album = visible[i];
              return _AlbumTile(
                album: album,
                onTap: () => _openAlbum(context, album),
              );
            },
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.albumArtists,
      count: results.albumArtists.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.albumArtists);
        final visible = expanded
            ? results.albumArtists
            : results.albumArtists.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) {
              final entry = visible[i];
              return _ArtistTile(
                name: entry.key,
                songs: entry.value,
                icon: LucideIcons.users,
                onTap: () => _openArtist(context, entry.key, entry.value),
              );
            },
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.folders,
      count: results.folders.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.folders);
        final visible = expanded
            ? results.folders
            : results.folders.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) {
              final folder = visible[i];
              return _FolderTile(
                folder: folder,
                onTap: () => _playSong(folder.songs.first, folder.songs),
              );
            },
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.year,
      count: results.yearMatches.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.year);
        final visible = expanded
            ? results.yearMatches
            : results.yearMatches.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) => _SongTile(
              song: visible[i],
              playlistForMode: results.yearMatches,
              repository: _songRepository,
              onPlay: _playSong,
              subtitleSuffix: visible[i].year?.toString(),
            ),
          ),
        ];
      },
    );

    addSection(
      cat: SearchCategory.playlists,
      count: results.playlists.length,
      buildItems: () {
        final expanded = _isExpanded(SearchCategory.playlists);
        final visible = expanded
            ? results.playlists
            : results.playlists.take(_previewLimit).toList();
        return [
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (c, i) => _PlaylistTile(
              playlist: visible[i],
              onTap: () => _openPlaylist(context, visible[i]),
            ),
          ),
        ];
      },
    );

    return CustomScrollView(
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Future<void> _playSong(Song song, List<Song> playlist) async {
    final notifier = ref.read(playerProvider.notifier);
    final mode = ref.read(appPreferencesProvider).searchPlaybackMode;
    if (mode == 'queue' && ref.read(playerProvider).currentSong != null) {
      final queueIndex = await notifier.addToQueue(song);
      await notifier.playFromQueueIndex(queueIndex);
    } else if (mode == 'library') {
      final library = await _songRepository.getAllSongs();
      if (!mounted) return;
      await notifier.play(song, playlist: library);
    } else {
      await notifier.play(song, playlist: playlist);
    }
  }

  void _openArtist(BuildContext context, String name, List<Song> songs) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(
          artistName: name,
          songs: songs,
          artistArt: null,
          artistArtSourcePath: null,
          playerService: PlayerService(),
        ),
      ),
    );
  }

  void _openAlbum(BuildContext context, AlbumGroup album) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          albumName: album.albumName,
          albumArtist: album.albumArtist,
          songs: album.songs,
          albumArt: album.songs.firstOrNull?.albumArt,
          albumArtSourcePath: album.songs.firstOrNull?.filePath,
          playerService: PlayerService(),
        ),
      ),
    );
  }

  void _openPlaylist(BuildContext context, dynamic playlist) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: playlist)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final SearchCategory category;
  final int count;
  final bool showSeeAll;
  final bool expanded;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.category,
    required this.count,
    required this.showSeeAll,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            Icon(category.icon, size: 14, color: context.adaptiveTextTertiary),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: context.adaptiveTextSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundStrong,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ),
            const Spacer(),
            if (showSeeAll)
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    expanded ? 'Show less' : 'See all',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends ConsumerWidget {
  final Song song;
  final List<Song> playlistForMode;
  final SongRepository repository;
  final Future<void> Function(Song, List<Song>) onPlay;
  final String? subtitleSuffix;

  const _SongTile({
    required this.song,
    required this.playlistForMode,
    required this.repository,
    required this.onPlay,
    this.subtitleSuffix,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = song.album;
    final suffix = subtitleSuffix;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: CachedImageWidget(
            imagePath: song.albumArt,
            audioSourcePath: song.filePath,
            fit: BoxFit.cover,
            useThumbnail: true,
            thumbnailWidth: 96,
            thumbnailHeight: 96,
            placeholder: const ColoredBox(
              color: AppColors.surface,
              child: FlickArtworkPlaceholder(size: 22, opacity: 0.9),
            ),
            errorWidget: const ColoredBox(
              color: AppColors.surface,
              child: FlickArtworkPlaceholder(size: 22, opacity: 0.9),
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: context.adaptiveTextPrimary,
        ),
      ),
      subtitle: Text(
        suffix != null && suffix.isNotEmpty
            ? '${song.artist}${album != null && album.isNotEmpty ? ' · $album' : ''} · $suffix'
            : '${song.artist}${album != null && album.isNotEmpty ? ' · $album' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          color: context.adaptiveTextTertiary,
        ),
      ),
      onTap: () => onPlay(song, playlistForMode),
      onLongPress: () => SongActionsBottomSheet.show(context, song),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final String name;
  final List<Song> songs;
  final IconData icon;
  final VoidCallback onTap;

  const _ArtistTile({
    required this.name,
    required this.songs,
    this.icon = LucideIcons.mic,
    required this.onTap,
  });

  String? _getArt(List<Song> list) {
    for (final s in list) {
      if (s.albumArt != null && s.albumArt!.isNotEmpty) return s.albumArt;
    }
    return null;
  }

  String? _getArtSource(List<Song> list) {
    for (final s in list) {
      final p = s.filePath;
      if (p != null && p.isNotEmpty) return p;
    }
    return null;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    if (value.trim().isNotEmpty) return value.trim()[0].toUpperCase();
    return '?';
  }

  Widget _buildInitials(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.adaptiveTextSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumCount = songs.map((s) => s.album ?? '').toSet().length;
    final art = _getArt(songs);
    final artSource = _getArtSource(songs);
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: ClipOval(
          child: CachedImageWidget(
            imagePath: art,
            audioSourcePath: artSource,
            fit: BoxFit.cover,
            placeholder: _buildInitials(context),
            errorWidget: _buildInitials(context),
          ),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.adaptiveTextPrimary,
        ),
      ),
      subtitle: Text(
        '${songs.length} songs · $albumCount albums',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          color: context.adaptiveTextTertiary,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final AlbumGroup album;
  final VoidCallback onTap;

  const _AlbumTile({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final art = album.songs.firstOrNull?.albumArt;
    final path = album.songs.firstOrNull?.filePath;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: CachedImageWidget(
            imagePath: art,
            audioSourcePath: path,
            fit: BoxFit.cover,
            useThumbnail: true,
            thumbnailWidth: 96,
            thumbnailHeight: 96,
            placeholder: const ColoredBox(
              color: AppColors.surface,
              child: FlickArtworkPlaceholder(size: 22, opacity: 0.9),
            ),
            errorWidget: const ColoredBox(
              color: AppColors.surface,
              child: FlickArtworkPlaceholder(size: 22, opacity: 0.9),
            ),
          ),
        ),
      ),
      title: Text(
        album.albumName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.adaptiveTextPrimary,
        ),
      ),
      subtitle: Text(
        '${album.albumArtist} · ${album.songs.length} tracks',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          color: context.adaptiveTextTertiary,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

class _FolderTile extends StatelessWidget {
  final dynamic folder; // FolderGroup
  final VoidCallback onTap;

  const _FolderTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = folder.name as String;
    final songs = folder.songs as List<Song>;
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(LucideIcons.folder, size: 22, color: AppColors.accent.withValues(alpha: 0.9)),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.adaptiveTextPrimary,
        ),
      ),
      subtitle: Text(
        '${songs.length} songs',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          color: context.adaptiveTextTertiary,
        ),
      ),
      trailing: Icon(
        LucideIcons.play,
        size: 16,
        color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final dynamic playlist; // Playlist
  final VoidCallback onTap;

  const _PlaylistTile({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = playlist.name as String;
    final count = (playlist.songIds as List).length;
    final songsState = ref.watch(songsProvider).value;
    Widget leading;
    if (songsState != null) {
      final ids = (playlist.songIds as List).cast<String>().toSet();
      final playlistSongs =
          songsState.songs.where((s) => ids.contains(s.id)).toList();
      final arts = playlistSongs
          .map((s) => s.albumArt)
          .where((a) => a != null && a.isNotEmpty)
          .cast<String>()
          .take(4)
          .toList();
      if (arts.isEmpty) {
        leading = Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const FlickArtworkPlaceholder(size: 22, opacity: 0.9),
        );
      } else if (arts.length == 1) {
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: CachedImageWidget(
              imagePath: arts[0],
              fit: BoxFit.cover,
              placeholder: Container(color: AppColors.surfaceLight),
              errorWidget: Container(color: AppColors.surfaceLight),
            ),
          ),
        );
      } else {
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              children: arts.take(4).map((path) {
                return CachedImageWidget(
                  imagePath: path,
                  fit: BoxFit.cover,
                  placeholder: Container(color: AppColors.surfaceLight),
                  errorWidget: Container(color: AppColors.surfaceLight),
                );
              }).toList(),
            ),
          ),
        );
      }
    } else {
      leading = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const FlickArtworkPlaceholder(size: 22, opacity: 0.9),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.adaptiveTextPrimary,
        ),
      ),
      subtitle: Text(
        '$count songs',
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          color: context.adaptiveTextTertiary,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}
