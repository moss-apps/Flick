import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/song_view_mode.dart';
import 'package:flick/features/songs/widgets/orbit_scroll.dart';
import 'package:flick/features/songs/widgets/song_fast_index_overlay.dart';
import 'package:flick/features/songs/widgets/song_actions_bottom_sheet.dart';
import 'package:flick/features/songs/widgets/sort_filter_bottom_sheet.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/widgets/common/glass_search_bar.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/utils/dev_log.dart';

enum _AlbumGridSortOption { name, artist, tracks }

/// Main songs screen with orbital scrolling.
class SongsScreen extends ConsumerStatefulWidget {
  /// Callback when navigation to a different tab is requested from full player
  final ValueChanged<int>? onNavigationRequested;

  const SongsScreen({super.key, this.onNavigationRequested});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen>
    with SingleTickerProviderStateMixin {
  static const double _listItemExtent = 80;

  static const int _defaultAlbumGridPageSize = 8;
  static const int _minAlbumGridPageSize = 1;
  static const int _maxAlbumGridPageSize = 30;
  static const int _listPageSize = 50;
  static const double _listLoadMoreThreshold = 320;
  static const double _minAlbumGridScale = 0.5;
  static const double _maxAlbumGridScale = 3.0;
  static const int _minAlbumGridColumns = 1;
  static const int _maxAlbumGridColumns = 4;

  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _albumGridScrollController = ScrollController();
  final OrbitScrollController _orbitScrollController = OrbitScrollController();
  String _searchQuery = '';
  List<Song> _cachedSongs = [];
  List<Song> _cachedDisplaySongs = [];
  String _selectedFastToken = 'A';
  late final ProviderSubscription<Song?> _currentSongSubscription;
  bool _alignedCurrentSongAfterLoad = false;
  Timer? _fastIndexTimer;
  bool _fastIndexVisible = true;
  int _visibleAlbumCount = _defaultAlbumGridPageSize;
  int _totalAlbumCount = 0;
  String _albumPaginationSignature = '';
  bool _wasInAlbumMode = false;
  int _visibleListCount = _listPageSize;
  String _listPaginationSignature = '';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  _AlbumGridSortOption _albumSortOption = _AlbumGridSortOption.name;
  bool _albumIsListView = false;
  double _albumGridScale = 1.0;
  double _albumGridTargetScale = 1.0;
  Ticker? _albumGridTicker;
  final Map<int, Offset> _albumGridPointers = {};
  double? _albumGridPinchStartDistance;
  double _albumGridPinchStartScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentSongSubscription = ref.listenManual<Song?>(currentSongProvider, (
      previous,
      next,
    ) {
      _syncInterfaceToCurrentSong(next);
    });
    _listScrollController.addListener(_onListScroll);
    _albumGridScrollController.addListener(_onAlbumGridScroll);
    _loadAlbumSortOption();
    _loadAlbumViewMode();
  }

  @override
  void dispose() {
    _currentSongSubscription.close();
    _listScrollController.removeListener(_onListScroll);
    _albumGridScrollController.removeListener(_onAlbumGridScroll);
    _listScrollController.dispose();
    _albumGridScrollController.dispose();
    _searchController.dispose();
    _fastIndexTimer?.cancel();
    _albumGridTicker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final viewMode = ref.watch(songsViewModeProvider);
    final navBarVisible = ref.watch(navBarVisibleProvider);
    final swipeActionsEnabled = ref
        .watch(appPreferencesProvider)
        .swipeActionsEnabled;
    final navBarConfig = ref.watch(navBarConfigProvider);
    final searchInNavBar = navBarConfig.orderedButtons.contains(
      NavBarButton.search,
    );

    final sortOption =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;
    final isAlbumMode = sortOption == SongSortOption.album;
    final shouldReserveOrbitBottomSpace =
        viewMode != SongViewMode.list && navBarVisible && !isAlbumMode;

    return DisplayModeWrapper(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header with sort option
                AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _selectionMode
                      ? KeyedSubtree(
                          key: const ValueKey('selection_header'),
                          child: _buildSelectionHeader(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('normal_header'),
                          child: _buildHeader(songsAsync),
                        ),
                ),

                // Search Bar (hidden when Search tab is in the nav bar)
                if (!searchInNavBar) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingLg,
                    ),
                    child: TutorialTargetAnchor(
                      target: TutorialTarget.songsSearchBar,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.surfaceLight.withValues(alpha: 0.75),
                              AppColors.surface.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusXl,
                          ),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GlassSearchBar(
                          controller: _searchController,
                          hintText: 'Search songs, artists...',
                          showBackground: false,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                              _selectedIndex = 0;
                              _lastSyncedSong = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                ],

                // Content based on async state
                Expanded(
                  child: songsAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (error, stack) => _buildErrorState(error),
                    data: (songsState) {
                      final isAlbumMode =
                          songsState.sortOption == SongSortOption.album;
                      final allSongs = songsState.sortedSongs;
                      var songs = allSongs;
                      if (_cachedSongs != songsState.songs) {
                        _cachedSongs = songsState.songs;
                        _lastSyncedSong = null;
                      }

                      if (_searchQuery.isNotEmpty) {
                        songs = songs.where((song) {
                          return song.title.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              song.artist.toLowerCase().contains(_searchQuery);
                        }).toList();
                      }
                      _cachedDisplaySongs = songs;

                      if (!isAlbumMode) {
                        _wasInAlbumMode = false;
                        final sig =
                            '${songs.length}:${songs.isNotEmpty ? songs.first.id : ''}';
                        if (sig != _listPaginationSignature) {
                          _listPaginationSignature = sig;
                          _resetListPagination();
                        }
                      }

                      if (songs.isEmpty && _searchQuery.isEmpty) {
                        return _buildEmptyState();
                      }

                      if (songs.isEmpty && _searchQuery.isNotEmpty) {
                        return _buildNoSearchResultsState();
                      }

                      if (isAlbumMode) {
                        if (!_wasInAlbumMode) {
                          _wasInAlbumMode = true;
                          _visibleAlbumCount = _getAlbumPageSize();
                          _albumPaginationSignature = '';
                        }
                        final albumGroups = songsState.albumGroups;
                        if (_searchQuery.isNotEmpty) {
                          final filteredGroups = <AlbumGroup>[];
                          for (final group in albumGroups) {
                            final filtered = group.songs.where((song) {
                              return song.title.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  song.artist.toLowerCase().contains(
                                    _searchQuery,
                                  );
                            }).toList();
                            if (filtered.isNotEmpty) {
                              filteredGroups.add(
                                AlbumGroup(
                                  key: group.key,
                                  albumName: group.albumName,
                                  albumArtist: group.albumArtist,
                                  songs: filtered,
                                ),
                              );
                            }
                          }
                          if (filteredGroups.isEmpty) {
                            return _buildNoSearchResultsState();
                          }
                          return _buildAlbumGridView(filteredGroups);
                        }
                        if (albumGroups.isEmpty) {
                          return _buildEmptyState();
                        }
                        return _buildAlbumGridView(albumGroups);
                      }

                      _alignCurrentSongAfterSongsLoad(songs);

                      if (_selectedIndex >= songs.length) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _selectedIndex = 0);
                          }
                        });
                      }

                      _syncSelectedTokenForIndex(songs, _selectedIndex);

                      final tokenToIndexMap = _buildFastIndexMap(songs);
                      final appPrefs = ref.watch(appPreferencesProvider);

                      return _buildSongsView(
                        songs,
                        viewMode,
                        tokenToIndexMap,
                        navBarVisible,
                        swipeActionsEnabled,
                        appPrefs.fastIndexEnabled,
                      );
                    },
                  ),
                ),

                // Reserve space only when needed for orbit view.
                // List view handles its own bottom padding.
                AnimatedContainer(
                  duration: AppConstants.animationNormal,
                  curve: Curves.easeOutCubic,
                  height: shouldReserveOrbitBottomSpace
                      ? AppConstants.navBarHeight + AppConstants.spacingLg
                      : 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsView(
    List<Song> songs,
    SongViewMode viewMode,
    Map<String, int> tokenToIndexMap,
    bool isBottomBarVisible,
    bool swipeActionsEnabled,
    bool fastIndexEnabled,
  ) {
    final overlayRailVisible = fastIndexEnabled && _fastIndexVisible;
    final content = viewMode == SongViewMode.list
        ? _buildListView(songs, swipeActionsEnabled, overlayRailVisible)
        : _buildOrbitView(songs, swipeActionsEnabled);

    if (tokenToIndexMap.isEmpty) {
      return content;
    }

    final songsAsync = ref.read(songsProvider);
    final sortOption =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;

    // Get appropriate tokens based on sort option
    List<String> tokens = _getFastIndexTokens(sortOption);

    // For date sorting, generate tokens from actual years in the data
    if (sortOption == SongSortOption.dateAdded) {
      final years = tokenToIndexMap.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      tokens = years;
    }

    // If tokens list is empty or we need to use actual data, use the keys from the map
    if (tokens.isEmpty || sortOption == SongSortOption.fileType) {
      tokens = tokenToIndexMap.keys.toList()..sort();
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final railTopInset = AppConstants.spacingSm;
    final railBottomInset = viewMode == SongViewMode.list && isBottomBarVisible
        ? AppConstants.navBarHeight + 90 + AppConstants.spacingSm
        : AppConstants.spacingSm;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        AnimatedPositioned(
          duration: AppConstants.animationNormal,
          curve: Curves.easeOutCubic,
          right: overlayRailVisible ? AppConstants.spacingSm : -40,
          top: railTopInset,
          bottom: railBottomInset - keyboardInset,
          child: IgnorePointer(
            ignoring: !overlayRailVisible,
            child: AnimatedOpacity(
              duration: AppConstants.animationNormal,
              opacity: overlayRailVisible ? 1.0 : 0.0,
              child: SongFastIndexOverlay(
                tokenToIndex: tokenToIndexMap,
                selectedToken: _selectedFastToken,
                tokens: tokens,
                onSelect: (token, animate) {
                  _resetFastIndexTimer();
                  _onFastIndexSelected(
                    songs: songs,
                    tokenToIndexMap: tokenToIndexMap,
                    token: token,
                    animate: animate,
                    viewMode: viewMode,
                    tokens: tokens,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrbitView(List<Song> songs, bool swipeActionsEnabled) {
    return GestureDetector(
      onLongPress: () {
        if (_selectionMode) return;
        if (songs.isNotEmpty && _selectedIndex < songs.length) {
          SongActionsBottomSheet.show(
            context,
            songs[_selectedIndex],
            onSelect: () => _enterSelectionMode(songs[_selectedIndex].id),
          );
        }
      },
      child: OrbitScroll(
        controller: _orbitScrollController,
        songs: songs,
        selectedIndex: _selectedIndex.clamp(0, songs.length - 1).toInt(),
        swipeActionsEnabled: swipeActionsEnabled && !_selectionMode,
        isSelectionMode: _selectionMode,
        selectedIds: _selectedIds,
        onSelectedIndexChanged: (index) {
          if (!mounted) return;
          _showFastIndexOverlay();
          setState(() {
            _selectedIndex = index;
          });
          _syncSelectedTokenForIndex(songs, index);
        },
        onSongSelected: (index) async {
          if (_selectionMode) {
            _toggleSelection(songs[index].id);
            return;
          }
          await _playSongAndOpenPlayer(songs: songs, index: index);
        },
        onSongSwipedLeft: (index) async {
          await _queueSong(songs[index]);
        },
        onSongSwipedRight: (index) async {
          await _favoriteSong(songs[index]);
        },
      ),
    );
  }

  Widget _buildListView(
    List<Song> songs,
    bool swipeActionsEnabled,
    bool overlayRailVisible,
  ) {
    final rightPadding = overlayRailVisible
        ? AppConstants.spacingXl + 30
        : AppConstants.spacingXl;
    return AnimatedPadding(
      duration: AppConstants.animationNormal,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(right: rightPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalItemHeight = songs.length * _listItemExtent;
          final needsScroll = totalItemHeight > constraints.maxHeight;
          final bottomPadding = needsScroll
              ? AppConstants.navBarHeight + 120
              : AppConstants.navBarHeight + AppConstants.spacingLg;
          return ListView.builder(
            controller: _listScrollController,
            itemExtent: _listItemExtent,
            addAutomaticKeepAlives: false,
            padding: EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              0,
              0,
              bottomPadding,
            ),
            itemCount: _visibleListCount,
            itemBuilder: (context, index) {
              if (index >= songs.length) return const SizedBox.shrink();
              final song = songs[index];
              final isSelected = index == _selectedIndex;
              final isMultiSelected = _selectedIds.contains(song.id);

              return Padding(
                key: ValueKey(song.id),
                padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                child: _QueueSwipeListItem(
                  swipeActionsEnabled: swipeActionsEnabled && !_selectionMode,
                  onQueued: () async {
                    await _queueSong(song);
                  },
                  onFavorited: () async {
                    await _favoriteSong(song);
                  },
                  child: _SongListTile(
                    song: song,
                    isSelected: isSelected,
                    isSelectionMode: _selectionMode,
                    isMultiSelected: isMultiSelected,
                    onTap: () async {
                      if (_selectionMode) {
                        _toggleSelection(song.id);
                        return;
                      }
                      setState(() {
                        _selectedIndex = index;
                      });
                      _syncSelectedTokenForIndex(songs, index);
                      await _playSongAndOpenPlayer(songs: songs, index: index);
                    },
                    onLongPress: () {
                      if (_selectionMode) {
                        _toggleSelection(song.id);
                      } else {
                        SongActionsBottomSheet.show(
                          context,
                          song,
                          onSelect: () => _enterSelectionMode(song.id),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<AlbumGroup> _sortedAlbumGroups(List<AlbumGroup> albums) {
    final sorted = List<AlbumGroup>.from(albums);
    switch (_albumSortOption) {
      case _AlbumGridSortOption.name:
        sorted.sort((a, b) => a.albumName.compareTo(b.albumName));
      case _AlbumGridSortOption.artist:
        sorted.sort((a, b) {
          final c = a.albumArtist.compareTo(b.albumArtist);
          return c != 0 ? c : a.albumName.compareTo(b.albumName);
        });
      case _AlbumGridSortOption.tracks:
        sorted.sort((a, b) {
          final c = b.songs.length.compareTo(a.songs.length);
          return c != 0 ? c : a.albumName.compareTo(b.albumName);
        });
    }
    return sorted;
  }

  Widget _buildAlbumGridView(List<AlbumGroup> albums) {
    final sortedAlbums = _sortedAlbumGroups(albums);
    _syncAlbumPagination(sortedAlbums);

    if (_albumIsListView) {
      return _buildAlbumListView(sortedAlbums);
    }

    final visibleCount = min(_visibleAlbumCount, sortedAlbums.length);
    final visibleAlbums = sortedAlbums
        .take(visibleCount)
        .toList(growable: false);
    final hasMore = visibleCount < sortedAlbums.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final baseColumns = context.gridColumns(
          compact: 2,
          phone: 2,
          tablet: 3,
        );
        final columns = (baseColumns * _albumGridScale).round().clamp(
          _minAlbumGridColumns,
          _maxAlbumGridColumns,
        );

        final totalSpacing = AppConstants.spacingMd * (columns - 1);
        final itemWidth = (availableWidth - totalSpacing) / columns;

        const textSectionHeight = 58.0;
        final aspectRatio = itemWidth / (itemWidth + textSectionHeight);

        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            _PinchGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_PinchGestureRecognizer>(
                  () => _PinchGestureRecognizer(),
                  (instance) {
                    instance.onPointerDown = _onAlbumGridPointerDown;
                    instance.onPointerMove = _onAlbumGridPointerMove;
                    instance.onPointerUp = _onAlbumGridPointerEnd;
                  },
                ),
          },
          child: CustomScrollView(
            controller: _albumGridScrollController,
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey('album_grid_$columns'),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingLg,
                        0,
                        AppConstants.spacingLg,
                        AppConstants.spacingLg,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: AppConstants.spacingMd,
                        mainAxisSpacing: AppConstants.spacingLg,
                      ),
                      itemCount: visibleAlbums.length,
                      itemBuilder: (context, index) {
                        final album = visibleAlbums[index];
                        final pinchDelta = (1.0 - _albumGridScale).clamp(
                          -1.0,
                          1.0,
                        );
                        return RepaintBoundary(
                          child: Transform.scale(
                            scale: 1.0 + pinchDelta * 0.04,
                            child: _AlbumCard(
                              album: album,
                              onTap: () => _openAlbumDetail(album),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: hasMore || visibleCount > _getAlbumPageSize()
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingLg,
                          0,
                          AppConstants.spacingLg,
                          AppConstants.navBarHeight + 120,
                        ),
                        child: _AlbumLoadMoreIndicator(
                          visibleCount: visibleCount,
                          totalCount: sortedAlbums.length,
                          isComplete:
                              !hasMore && visibleCount > _getAlbumPageSize(),
                          onLoadMore: hasMore ? _loadMoreAlbums : null,
                        ),
                      )
                    : const SizedBox(
                        height:
                            AppConstants.navBarHeight + AppConstants.spacingLg,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumListView(List<AlbumGroup> albums) {
    final visibleCount = min(_visibleAlbumCount, albums.length);
    final visibleAlbums = albums
        .take(visibleCount)
        .toList(growable: false);
    final hasMore = visibleCount < albums.length;

    return ListView.builder(
      controller: _albumGridScrollController,
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.navBarHeight + 120,
      ),
      itemCount: visibleAlbums.length + 1,
      itemBuilder: (context, index) {
        if (index == visibleAlbums.length) {
          if (!(hasMore || visibleCount > _getAlbumPageSize())) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: _AlbumLoadMoreIndicator(
              visibleCount: visibleCount,
              totalCount: albums.length,
              isComplete: !hasMore && visibleCount > _getAlbumPageSize(),
              onLoadMore: hasMore ? _loadMoreAlbums : null,
            ),
          );
        }
        final album = visibleAlbums[index];
        return Padding(
          key: ValueKey(album.key),
          padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
          child: _AlbumListTile(
            album: album,
            onTap: () => _openAlbumDetail(album),
          ),
        );
      },
    );
  }

  void _openAlbumDetail(AlbumGroup album) {
    final artPath = _findAlbumArt(album.songs);
    final sourcePath = album.songs
        .firstWhere(
          (s) => s.albumArt != null && s.albumArt!.isNotEmpty,
          orElse: () => album.songs.first,
        )
        .filePath;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumDetailScreen(
          albumName: album.albumName,
          albumArtist: album.albumArtist,
          songs: album.songs,
          albumArt: artPath,
          albumArtSourcePath: sourcePath,
          playerService: PlayerService(),
        ),
      ),
    );
  }

  String? _findAlbumArt(List<Song> songs) {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  int _getAlbumPageSize() {
    return ref
        .read(appPreferencesProvider)
        .folderGridPageSize
        .clamp(_minAlbumGridPageSize, _maxAlbumGridPageSize)
        .toInt();
  }

  void _syncAlbumPagination(List<AlbumGroup> albums) {
    final totalSongCount = albums.fold<int>(
      0,
      (sum, album) => sum + album.songs.length,
    );
    final signature =
        '$_searchQuery|${albums.length}|$totalSongCount|${albums.isNotEmpty ? albums.first.key : ''}|${albums.isNotEmpty ? albums.last.key : ''}';

    _totalAlbumCount = albums.length;

    if (_albumPaginationSignature != signature) {
      _albumPaginationSignature = signature;
      _visibleAlbumCount = min(_getAlbumPageSize(), albums.length);

      if (_albumGridScrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_albumGridScrollController.hasClients) return;
          _albumGridScrollController.jumpTo(0);
        });
      }
      return;
    }

    if (_visibleAlbumCount > albums.length) {
      _visibleAlbumCount = albums.length;
    } else if (_visibleAlbumCount == 0 && albums.isNotEmpty) {
      _visibleAlbumCount = min(_getAlbumPageSize(), albums.length);
    }
  }

  Map<String, int> _buildFastIndexMap(List<Song> songs) {
    final songsAsync = ref.read(songsProvider);
    final sortOption =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;

    final map = <String, int>{};
    for (var i = 0; i < songs.length; i++) {
      final token = _tokenForSong(songs[i], sortOption);
      map.putIfAbsent(token, () => i);
    }
    return map;
  }

  String _tokenForSong(Song song, SongSortOption sortOption) {
    String text;

    switch (sortOption) {
      case SongSortOption.albumArtist:
        text = song.albumArtist ?? song.artist;
      case SongSortOption.artist:
        text = song.artist;
      case SongSortOption.title:
        text = song.title;
      case SongSortOption.dateAdded:
        // For date sorting, group by year
        final year = song.dateAdded?.year;
        if (year == null) return '#';
        return year.toString();
      case SongSortOption.fileType:
        return song.fileType.toUpperCase();
      case SongSortOption.album:
        text = song.album ?? 'Unknown Album';
      case SongSortOption.year:
        final year = song.year;
        if (year == null || year == 0) return '#';
        return year.toString();
      case SongSortOption.genre:
        text = song.genre ?? '';
    }

    return _extractToken(text);
  }

  String _extractToken(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return '#';

    final code = normalized.codeUnitAt(0);
    if (_isAsciiUpper(code)) {
      return String.fromCharCode(code);
    }

    if (_isDigit(code)) {
      return '0-9';
    }

    final upperCode = code >= 97 && code <= 122 ? code - 32 : code;
    if (_isAsciiUpper(upperCode)) {
      return String.fromCharCode(upperCode);
    }

    return '#';
  }

  bool _isAsciiUpper(int codeUnit) => codeUnit >= 65 && codeUnit <= 90;
  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  List<String> _getFastIndexTokens(SongSortOption sortOption) {
    switch (sortOption) {
      case SongSortOption.dateAdded:
        return [];
      case SongSortOption.year:
        return [];
      case SongSortOption.genre:
        return [];
      case SongSortOption.fileType:
        return ['FLAC', 'MP3', 'WAV', 'AAC', 'OGG', 'OGX', 'OPUS', 'ALAC', '#'];
      default:
        return SongFastIndexOverlay.defaultTokens;
    }
  }

  String _nearestIndexedToken(
    String token,
    Map<String, int> tokenToIndexMap,
    List<String> tokens,
  ) {
    if (tokenToIndexMap.containsKey(token)) {
      return token;
    }

    final start = tokens.indexOf(token);
    if (start == -1) return tokenToIndexMap.keys.first;

    for (var i = start + 1; i < tokens.length; i++) {
      final candidate = tokens[i];
      if (tokenToIndexMap.containsKey(candidate)) {
        return candidate;
      }
    }

    for (var i = start - 1; i >= 0; i--) {
      final candidate = tokens[i];
      if (tokenToIndexMap.containsKey(candidate)) {
        return candidate;
      }
    }

    return tokenToIndexMap.keys.first;
  }

  void _onFastIndexSelected({
    required List<Song> songs,
    required Map<String, int> tokenToIndexMap,
    required String token,
    required bool animate,
    required SongViewMode viewMode,
    required List<String> tokens,
  }) {
    if (songs.isEmpty || tokenToIndexMap.isEmpty) return;

    final resolvedToken = _nearestIndexedToken(token, tokenToIndexMap, tokens);
    final targetIndex = tokenToIndexMap[resolvedToken];
    if (targetIndex == null) return;

    _selectedFastToken = resolvedToken;

    if (mounted && targetIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = targetIndex;
      });
    }

    if (viewMode == SongViewMode.list) {
      _jumpInList(targetIndex, animate);
      return;
    }

    _orbitScrollController.jumpToIndex(targetIndex, animate: animate);
  }

  void _jumpInList(int targetIndex, bool animate) {
    if (!_listScrollController.hasClients) return;

    final targetOffset = targetIndex * _listItemExtent;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _listScrollController.position.maxScrollExtent,
    );

    if (animate && AppConstants.animationNormal != Duration.zero) {
      _listScrollController.animateTo(
        clampedOffset,
        duration: AppConstants.animationNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _listScrollController.jumpTo(clampedOffset);
    }
  }

  List<Song> _visibleSongsFromCache() {
    return _cachedDisplaySongs;
  }

  Song? _lastSyncedSong;

  void _syncInterfaceToCurrentSong(Song? song, {bool animate = true}) {
    if (!mounted || song == null || _cachedDisplaySongs.isEmpty) {
      return;
    }

    if (_lastSyncedSong != null && _lastSyncedSong!.id == song.id) {
      return;
    }
    _lastSyncedSong = song;

    final visibleSongs = _visibleSongsFromCache();
    final targetIndex = visibleSongs.indexWhere((candidate) {
      return candidate.id == song.id;
    });
    if (targetIndex == -1) return;

    _syncSelectedTokenForIndex(visibleSongs, targetIndex);

    if (targetIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = targetIndex;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final viewMode = ref.read(songsViewModeProvider);
      if (viewMode == SongViewMode.list) {
        _jumpInList(targetIndex, animate);
        return;
      }

      _orbitScrollController.jumpToIndex(targetIndex, animate: animate);
    });
  }

  void _alignCurrentSongAfterSongsLoad(List<Song> visibleSongs) {
    if (_alignedCurrentSongAfterLoad || visibleSongs.isEmpty) {
      return;
    }

    final currentSong = ref.read(currentSongProvider);
    if (currentSong == null) return;

    final targetIndex = visibleSongs.indexWhere(
      (song) => song.id == currentSong.id,
    );
    if (targetIndex == -1) return;

    _alignedCurrentSongAfterLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncInterfaceToCurrentSong(currentSong, animate: false);
    });
  }

  void _syncSelectedTokenForIndex(List<Song> songs, int index) {
    if (songs.isEmpty || index < 0 || index >= songs.length) {
      return;
    }
    final songsAsync = ref.read(songsProvider);
    final sortOption =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;
    _selectedFastToken = _tokenForSong(songs[index], sortOption);
  }

  void _showFastIndexOverlay() {
    if (!mounted) return;
    if (!_fastIndexVisible) {
      setState(() => _fastIndexVisible = true);
    }
    _resetFastIndexTimer();
  }

  void _resetFastIndexTimer() {
    final timeout = ref.read(appPreferencesProvider).fastIndexTimeoutSeconds;
    _fastIndexTimer?.cancel();
    if (timeout > 0) {
      _fastIndexTimer = Timer(Duration(seconds: timeout), () {
        if (mounted) {
          setState(() => _fastIndexVisible = false);
        }
      });
    }
  }

  void _onListScroll() {
    _showFastIndexOverlay();
    if (!_listScrollController.hasClients) return;
    final position = _listScrollController.position;
    if (position.pixels >= position.maxScrollExtent - _listLoadMoreThreshold) {
      _loadMoreListSongs();
    }
  }

  void _onAlbumGridScroll() {}

  void _onAlbumGridPointerDown(PointerDownEvent event) {
    _albumGridPointers[event.pointer] = event.position;
    _syncAlbumGridPinch();
  }

  void _onAlbumGridPointerMove(PointerMoveEvent event) {
    if (!_albumGridPointers.containsKey(event.pointer)) return;
    _albumGridPointers[event.pointer] = event.position;
    _syncAlbumGridPinch();
  }

  void _onAlbumGridPointerEnd(PointerEvent event) {
    _albumGridPointers.remove(event.pointer);
    if (_albumGridPointers.length < 2) {
      _albumGridPinchStartDistance = null;
    }
    _syncAlbumGridPinch();
  }

  void _syncAlbumGridPinch() {
    if (_albumGridPointers.length != 2) return;
    final positions = _albumGridPointers.values.toList();
    final distance = (positions[0] - positions[1]).distance;
    if (distance <= 0) return;

    if (_albumGridPinchStartDistance == null) {
      _albumGridPinchStartDistance = distance;
      _albumGridPinchStartScale = _albumGridTargetScale;
      return;
    }

    final ratio = distance / _albumGridPinchStartDistance!;
    final newScale = (_albumGridPinchStartScale / ratio).clamp(
      _minAlbumGridScale,
      _maxAlbumGridScale,
    );
    if ((newScale - _albumGridTargetScale).abs() > 0.001) {
      setState(() {
        _albumGridTargetScale = newScale;
      });
    }
    _ensureAlbumGridTicker();
  }

  void _ensureAlbumGridTicker() {
    _albumGridTicker ??= createTicker(_onAlbumGridTick)..start();
  }

  void _onAlbumGridTick(Duration elapsed) {
    final diff = _albumGridTargetScale - _albumGridScale;
    if (diff.abs() < 0.001) {
      _albumGridTicker?.stop();
      _albumGridTicker?.dispose();
      _albumGridTicker = null;
      return;
    }
    setState(() {
      _albumGridScale += diff * 0.35;
    });
  }

  Future<void> _loadAlbumSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('songs_album_sort_option');
    if (!mounted) return;
    final option = _AlbumGridSortOption.values.firstWhere(
      (v) => v.name == value,
      orElse: () => _AlbumGridSortOption.name,
    );
    if (option != _albumSortOption) {
      setState(() => _albumSortOption = option);
    }
  }

  Future<void> _setAlbumSortOption(_AlbumGridSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songs_album_sort_option', option.name);
    if (mounted) {
      setState(() => _albumSortOption = option);
    }
  }

  Future<void> _loadAlbumViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('songs_album_view_mode_list') ?? false;
    if (!mounted) return;
    if (value != _albumIsListView) {
      setState(() => _albumIsListView = value);
    }
  }

  Future<void> _setAlbumViewMode(bool isList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('songs_album_view_mode_list', isList);
    if (mounted) {
      setState(() {
        _albumIsListView = isList;
        _albumPaginationSignature = '';
      });
    }
  }

  void _loadMoreAlbums() {
    if (!mounted || _visibleAlbumCount >= _totalAlbumCount) {
      return;
    }

    setState(() {
      _visibleAlbumCount = min(
        _visibleAlbumCount + _getAlbumPageSize(),
        _totalAlbumCount,
      );
    });
  }

  void _loadMoreListSongs() {
    if (!mounted || _visibleListCount >= _cachedDisplaySongs.length) {
      return;
    }
    setState(() {
      _visibleListCount = min(
        _visibleListCount + _listPageSize,
        _cachedDisplaySongs.length,
      );
    });
  }

  void _resetListPagination() {
    final target = _listPageSize;
    if (_visibleListCount != target ||
        _visibleListCount > _cachedDisplaySongs.length) {
      _visibleListCount = _cachedDisplaySongs.length < target
          ? _cachedDisplaySongs.length
          : target;
    }
  }

  Future<void> _playSongAndOpenPlayer({
    required List<Song> songs,
    required int index,
  }) async {
    // Play just the selected song — no playlist context so the queue stays empty
    final songToPlay = songs[index];
    await ref.read(playerProvider.notifier).play(songToPlay, playlist: songs);

    if (!mounted) return;

    // Navigate to full player screen using helper to prevent duplicates
    final result = await NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'song_art_${songToPlay.id}',
    );

    // If a navigation index was returned and it's not Songs (1), notify parent to switch tabs
    if (result != null && result != 1 && widget.onNavigationRequested != null) {
      widget.onNavigationRequested!(result);
    }
  }

  Future<void> _queueSong(Song song) async {
    final index = await ref.read(playerProvider.notifier).addToQueue(song);
    if (!mounted) return;
    _showSongActionSnackBar(
      'Queued "${song.title}"',
      onUndo: () => ref.read(playerProvider.notifier).removeFromQueue(index),
    );
  }

  Future<void> _favoriteSong(Song song) async {
    unawaited(() async {
      try {
        await ref.read(favoritesServiceProvider).addFavorite(song.id);
      } catch (error, stackTrace) {
        devLog('Failed to add favorite for ${song.id}: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        _showSongActionSnackBar('Failed to add "${song.title}" to favorites');
        return;
      }

      ref.invalidate(favoritesProvider);
      PlayerService().refreshNotificationState();
    }());
    _showSongActionSnackBar(
      'Added "${song.title}" to favorites',
      onUndo: () =>
          ref.read(favoritesServiceProvider).removeFavorite(song.id).then((_) {
            ref.invalidate(favoritesProvider);
            PlayerService().refreshNotificationState();
          }),
    );
  }

  void _enterSelectionMode(String? songId) {
    setState(() {
      _selectionMode = true;
      if (songId != null) _selectedIds.add(songId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  void _selectAll(List<Song> songs) {
    setState(() {
      _selectedIds.addAll(songs.map((s) => s.id));
    });
  }

  Future<void> _queueSelected() async {
    final toQueue = _cachedDisplaySongs
        .where((s) => _selectedIds.contains(s.id))
        .toList();
    for (final song in toQueue) {
      await ref.read(playerProvider.notifier).addToQueue(song);
    }
    if (mounted) {
      _showSongActionSnackBar('Queued ${toQueue.length} songs');
      _exitSelectionMode();
    }
  }

  Future<void> _favoriteSelected() async {
    final toFavorite = _cachedDisplaySongs
        .where((s) => _selectedIds.contains(s.id))
        .toList();
    for (final song in toFavorite) {
      try {
        await ref.read(favoritesServiceProvider).addFavorite(song.id);
      } catch (_) {}
    }
    ref.invalidate(favoritesProvider);
    PlayerService().refreshNotificationState();
    if (mounted) {
      _showSongActionSnackBar(
        'Added ${toFavorite.length} songs to favorites',
        onUndo: () async {
          for (final song in toFavorite) {
            await ref.read(favoritesServiceProvider).removeFavorite(song.id);
          }
          ref.invalidate(favoritesProvider);
          PlayerService().refreshNotificationState();
        },
      );
      _exitSelectionMode();
    }
  }

  List<Song> _selectedSongs() {
    final ids = _selectedIds;
    return _cachedDisplaySongs.where((s) => ids.contains(s.id)).toList();
  }

  Future<void> _addSelectedToPlaylist() async {
    final songs = _selectedSongs();
    if (songs.isEmpty || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        maxHeightRatio: 0.72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetDragHandle(),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Icon(
                  LucideIcons.listMusic,
                  color: sheetContext.adaptiveTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    'Add ${songs.length} songs to playlist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: sheetContext.adaptiveTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Flexible(
              fit: FlexFit.loose,
              child: Consumer(
                builder: (context, ref, _) {
                  final playlistsAsync = ref.watch(playlistsProvider);
                  return playlistsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppConstants.spacingXl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(AppConstants.spacingXl),
                      child: Text('Error loading playlists: $error'),
                    ),
                    data: (state) => ListView(
                      shrinkWrap: true,
                      children: [
                        _selectionSheetTile(
                          icon: LucideIcons.plus,
                          label: 'Create new playlist',
                          onTap: () {
                            Navigator.pop(context);
                            _createPlaylistWithSelected();
                          },
                        ),
                        const Divider(
                          height: 1,
                          color: AppColors.glassBorderStrong,
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        ...state.playlists.map(
                          (playlist) => _selectionSheetTile(
                            icon: LucideIcons.listMusic,
                            label: playlist.name,
                            onTap: () {
                              Navigator.pop(context);
                              _addSongsToPlaylist(
                                playlist.id,
                                playlist.name,
                                songs,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSongsToPlaylist(
    String playlistId,
    String playlistName,
    List<Song> songs,
  ) async {
    final notifier = ref.read(playlistsProvider.notifier);
    for (final song in songs) {
      await notifier.addSongToPlaylist(playlistId, song.id);
    }
    if (!mounted) return;
    _showSongActionSnackBar('Added ${songs.length} songs to $playlistName');
    _exitSelectionMode();
  }

  Future<void> _createPlaylistWithSelected() async {
    final songs = _selectedSongs();
    if (songs.isEmpty || !mounted) return;

    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Future<void> create(String value) async {
          final name = value.trim();
          if (name.isEmpty) return;

          final playlist = await ref
              .read(playlistsProvider.notifier)
              .createPlaylist(name);

          if (playlist == null) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('A playlist with this name already exists'),
                ),
              );
            }
            return;
          }

          for (final song in songs) {
            await ref
                .read(playlistsProvider.notifier)
                .addSongToPlaylist(playlist.id, song.id);
          }

          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          if (mounted) {
            _showSongActionSnackBar(
              'Created $name and added ${songs.length} songs',
            );
            _exitSelectionMode();
          }
        }

        return AlertDialog(
          title: const Text('Create Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: create,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => create(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showMoreActions() async {
    final allSelected = _selectedIds.length == _cachedDisplaySongs.length &&
        _cachedDisplaySongs.isNotEmpty;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        maxHeightRatio: 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetDragHandle(),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Icon(
                  LucideIcons.ellipsisVertical,
                  color: sheetContext.adaptiveTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Text(
                  'More actions',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.adaptiveTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Flexible(
              fit: FlexFit.loose,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _selectionSheetTile(
                    icon:
                        allSelected ? LucideIcons.x : LucideIcons.checkCheck,
                    label: allSelected ? 'Deselect all' : 'Select all',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (allSelected) {
                        _exitSelectionMode();
                      } else {
                        _selectAll(_cachedDisplaySongs);
                      }
                    },
                  ),
                  _selectionSheetTile(
                    icon: LucideIcons.circlePlus,
                    label: 'Create playlist from selected',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _createPlaylistWithSelected();
                    },
                  ),
                  _selectionSheetTile(
                    icon: LucideIcons.trash2,
                    label: 'Delete selected',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deleteSelected();
                    },
                    destructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final songs = _selectedSongs();
    if (songs.isEmpty || !mounted) return;

    final canDeleteFiles = songs.any(
      (s) => s.filePath != null && s.filePath!.isNotEmpty && !s.isExternal,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${songs.length} songs?'),
        content: Text(
          canDeleteFiles
              ? 'Remove the database entries or delete the files from your device. This cannot be undone.'
              : 'Remove these songs from your library. The files on your device will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteSelectedSongs(songs, deleteFiles: false);
            },
            child: const Text('Remove from Library'),
          ),
          if (canDeleteFiles)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteSelectedSongs(songs, deleteFiles: true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete Files'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedSongs(
    List<Song> songs, {
    required bool deleteFiles,
  }) async {
    final repository = ref.read(songRepositoryProvider);
    final rootContext = context;
    if (!mounted) return;

    showDialog<void>(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    for (final song in songs) {
      final songId = int.tryParse(song.id);
      if (songId == null) continue;
      try {
        await repository.deleteSong(songId);
      } catch (_) {}
      if (deleteFiles &&
          song.filePath != null &&
          song.filePath!.isNotEmpty &&
          !song.isExternal) {
        var deleted = false;
        try {
          deleted = await MusicFolderService.deleteDocument(
            folderTreeUri: song.folderUri ?? song.filePath!,
            filePath: song.filePath!,
          );
        } catch (_) {}
        if (!deleted) {
          try {
            final file = File(song.filePath!);
            if (await file.exists()) {
              await file.delete();
              deleted = true;
            }
          } catch (_) {}
        }
        if (deleted) {
          try {
            await MusicFolderService.removeFromMediaStore(song.filePath!);
          } catch (_) {}
        }
      }
    }

    ref.invalidate(songsProvider);
    if (rootContext.mounted) Navigator.of(rootContext).pop();
    if (mounted) {
      _exitSelectionMode();
      _showSongActionSnackBar(
        deleteFiles
            ? 'Deleted ${songs.length} songs'
            : 'Removed ${songs.length} songs from library',
      );
    }
  }

  Widget _sheetDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorderStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
      ),
    );
  }

  Widget _selectionSheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: destructive
                      ? Colors.redAccent.withValues(alpha: 0.16)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: destructive
                      ? Colors.redAccent
                      : context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: destructive
                        ? Colors.redAccent
                        : context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: context.adaptiveTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongActionSnackBar(String message, {VoidCallback? onUndo}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(child: Text(message)),
              if (onUndo != null)
                TextButton(
                  onPressed: onUndo,
                  child: Text(
                    'Undo',
                    style: TextStyle(
                      color: AppColors.accentDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ),
      );
    });
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: context.adaptiveTextSecondary),
    );
  }

  Widget _buildErrorState(Object error) {
    return _ContentStateWidget(
      icon: LucideIcons.circleX,
      title: 'Error loading songs',
      subtitle: error.toString(),
      action: TextButton(
        onPressed: () => ref.invalidate(songsProvider),
        child: const Text('Retry'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const _ContentStateWidget(
      icon: LucideIcons.music4,
      title: 'No Music Yet',
      subtitle: 'Add a music folder in Settings',
    );
  }

  Widget _buildNoSearchResultsState() {
    return const _ContentStateWidget(
      icon: LucideIcons.searchX,
      title: 'No matches found',
      subtitle: 'Try adjusting your search query',
    );
  }

  Widget _buildHeader(AsyncValue<SongsState> songsAsync) {
    final songCount = songsAsync.value?.songs.length ?? 0;
    final currentSort =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;
    final currentFilter =
        songsAsync.value?.fileTypeFilter ?? SongFileTypeFilter.all;
    final isAlbumMode = currentSort == SongSortOption.album;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Library',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxs),
              Text(
                '$songCount songs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),

          Row(
            children: [
              if (isAlbumMode) ...[
                _buildHeaderIconButton(
                  context: context,
                  icon: _albumIsListView
                      ? LucideIcons.layoutGrid
                      : LucideIcons.list,
                  onTap: () => _setAlbumViewMode(!_albumIsListView),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                _buildHeaderIconButton(
                  context: context,
                  icon: LucideIcons.listFilter,
                  onTap: () => _showAlbumFilterPopup(context, currentFilter),
                ),
              ] else
                _buildHeaderIconButton(
                  context: context,
                  icon: LucideIcons.checkCheck,
                  onTap: () => _enterSelectionMode(null),
                ),
              const SizedBox(width: AppConstants.spacingSm),
              _buildHeaderIconButton(
                context: context,
                icon: LucideIcons.shuffle,
                onTap: () => _shufflePlayFromLibrary(songsAsync),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              TutorialTargetAnchor(
                target: TutorialTarget.songsSortButton,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceLight.withValues(alpha: 0.75),
                        AppColors.surface.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border:
                        Border.all(color: AppColors.glassBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      SortFilterBottomSheet.show(
                        context,
                        currentSort: currentSort,
                        currentFilter: currentFilter,
                        onSortChanged: (option) {
                          ref
                              .read(songsProvider.notifier)
                              .setSortOption(option);
                          setState(() {
                            _selectedIndex = 0;
                            _lastSyncedSong = null;
                          });
                        },
                        onFilterChanged: (filter) {
                          ref
                              .read(songsProvider.notifier)
                              .setFileTypeFilter(filter);
                          setState(() {
                            _selectedIndex = 0;
                            _lastSyncedSong = null;
                          });
                        },
                      );
                    },
                    icon: Icon(
                      Icons.sort_rounded,
                      color: context.adaptiveTextSecondary,
                      size: context.responsiveIcon(AppConstants.iconSizeMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader() {
    final count = _selectedIds.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x),
            color: context.adaptiveTextPrimary,
            onPressed: _exitSelectionMode,
          ),
          Expanded(
            child: Text(
              '$count selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.listPlus,
              color: AppColors.accent.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? () => _queueSelected() : null,
            tooltip: 'Add to queue',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.heart,
              color: Colors.red.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? () => _favoriteSelected() : null,
            tooltip: 'Add to favorites',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.listMusic,
              color: AppColors.accent.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? _addSelectedToPlaylist : null,
            tooltip: 'Add to playlist',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              color: context.adaptiveTextPrimary,
            ),
            onPressed: count > 0 ? _showMoreActions : null,
            tooltip: 'More actions',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.75),
            AppColors.surface.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: context.adaptiveTextSecondary,
          size: context.responsiveIcon(AppConstants.iconSizeMd),
        ),
      ),
    );
  }

  void _showAlbumFilterPopup(
    BuildContext context,
    SongFileTypeFilter currentFilter,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        return _AlbumFilterSheet(
          currentSort: _albumSortOption,
          currentFilter: currentFilter,
          albumGridPageSize: _getAlbumPageSize(),
          onSortChanged: (option) {
            _setAlbumSortOption(option);
            setState(() {
              _visibleAlbumCount = min(_getAlbumPageSize(), _totalAlbumCount);
              _albumPaginationSignature = '';
            });
          },
          onFilterChanged: (filter) {
            ref.read(songsProvider.notifier).setFileTypeFilter(filter);
            setState(() {
              _selectedIndex = 0;
              _lastSyncedSong = null;
            });
          },
          onPageSizeChanged: (value) {
            ref
                .read(appPreferencesProvider.notifier)
                .setFolderGridPageSize(value);
            setState(() {
              _visibleAlbumCount = min(value, _totalAlbumCount);
              _albumPaginationSignature = '';
            });
          },
        );
      },
    );
  }

  Future<void> _shufflePlayFromLibrary(
    AsyncValue<SongsState> songsAsync,
  ) async {
    final sourceSongs = songsAsync.value?.songs ?? const <Song>[];
    if (sourceSongs.isEmpty) return;

    final shuffledPlaylist = List<Song>.from(sourceSongs)..shuffle(Random());
    final randomSong = shuffledPlaylist.first;

    await ref
        .read(playerProvider.notifier)
        .play(randomSong, playlist: shuffledPlaylist);

    if (!mounted) return;

    final result = await NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: 'song_art_${randomSong.id}',
    );

    if (result != null && result != 1 && widget.onNavigationRequested != null) {
      widget.onNavigationRequested!(result);
    }
  }
}

class _QueueSwipeListItem extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onQueued;
  final Future<void> Function() onFavorited;
  final bool swipeActionsEnabled;

  const _QueueSwipeListItem({
    required this.child,
    required this.onQueued,
    required this.onFavorited,
    this.swipeActionsEnabled = false,
  });

  @override
  State<_QueueSwipeListItem> createState() => _QueueSwipeListItemState();
}

class _SongListTile extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isMultiSelected;
  final Future<void> Function() onTap;
  final VoidCallback onLongPress;

  const _SongListTile({
    required this.song,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isMultiSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: context.adaptiveTextPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.adaptiveTextSecondary);
    final durationStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.adaptiveTextTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: () async {
          AppHaptics.tap();
          await onTap();
        },
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: (isSelected || isMultiSelected)
                  ? [
                      AppColors.surfaceLight.withValues(alpha: 0.9),
                      AppColors.surface.withValues(alpha: 0.95),
                    ]
                  : [
                      AppColors.surfaceLight.withValues(alpha: 0.65),
                      AppColors.surface.withValues(alpha: 0.78),
                    ],
            ),
            border: Border.all(
              color: (isSelected || isMultiSelected)
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Icon(
                  isMultiSelected ? LucideIcons.check : LucideIcons.circle,
                  color: isMultiSelected
                      ? AppColors.accent
                      : context.adaptiveTextTertiary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                const SizedBox(width: AppConstants.spacingMd),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    useThumbnail: true,
                    thumbnailWidth: 92,
                    thumbnailHeight: 92,
                    placeholder: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.music,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                    errorWidget: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.music,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} • ${song.fileType.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(song.formattedDuration, style: durationStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueSwipeListItemState extends State<_QueueSwipeListItem> {
  double _dragDx = 0;
  bool _queuedFlash = false;
  bool _favoriteFlash = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.swipeActionsEnabled) return widget.child;

    final queueRevealProgress = (-_dragDx / 120).clamp(0.0, 1.0);
    final favoriteRevealProgress = (_dragDx / 120).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.redAccent.withValues(
                    alpha: 0.14 + (favoriteRevealProgress * 0.14),
                  ),
                  AppColors.surface,
                  AppColors.accent.withValues(
                    alpha: 0.14 + (queueRevealProgress * 0.14),
                  ),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  AppColors.accent.withValues(
                    alpha: 0.18 + (queueRevealProgress * 0.24),
                  ),
                  Colors.redAccent.withValues(
                    alpha: 0.18 + (favoriteRevealProgress * 0.24),
                  ),
                  favoriteRevealProgress,
                )!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: favoriteRevealProgress,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: queueRevealProgress,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add to queue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final nextDx = (_dragDx + details.delta.dx).clamp(-132.0, 132.0);
            if (nextDx != _dragDx) {
              setState(() {
                _dragDx = nextDx;
              });
            }
          },
          onHorizontalDragEnd: (details) async {
            final shouldFavorite =
                _dragDx >= 84 ||
                (details.primaryVelocity != null &&
                    details.primaryVelocity! > 400);
            final shouldQueue =
                _dragDx <= -84 ||
                (details.primaryVelocity != null &&
                    details.primaryVelocity! < -400);
            if (shouldFavorite) {
              setState(() {
                _dragDx = 0;
                _favoriteFlash = true;
              });
              await widget.onFavorited();
              if (!mounted) return;
              await Future<void>.delayed(const Duration(milliseconds: 180));
              if (!mounted) return;
              setState(() {
                _favoriteFlash = false;
              });
              return;
            }
            if (shouldQueue) {
              setState(() {
                _dragDx = 0;
                _queuedFlash = true;
              });
              await widget.onQueued();
              if (!mounted) return;
              await Future<void>.delayed(const Duration(milliseconds: 180));
              if (!mounted) return;
              setState(() {
                _queuedFlash = false;
              });
              return;
            }
            setState(() {
              _dragDx = 0;
            });
          },
          onHorizontalDragCancel: () {
            if (_dragDx != 0) {
              setState(() {
                _dragDx = 0;
              });
            }
          },
          behavior: HitTestBehavior.translucent,
          child: AnimatedSlide(
            duration: AppConstants.animationFast,
            curve: Curves.easeOutCubic,
            offset: Offset(_dragDx / 360, 0),
            child: AnimatedScale(
              duration: AppConstants.animationFast,
              scale: (_queuedFlash || _favoriteFlash) ? 0.985 : 1,
              child: AnimatedContainer(
                duration: AppConstants.animationFast,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  boxShadow: (_queuedFlash || _favoriteFlash)
                      ? [
                          BoxShadow(
                            color:
                                (_favoriteFlash
                                        ? Colors.redAccent
                                        : AppColors.accent)
                                    .withValues(alpha: 0.22),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatefulWidget {
  final AlbumGroup album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;
  List<_ArtEntry> _cachedArtworks = const [];

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
    _tiltAnimation = Tween<double>(
      begin: 0.0,
      end: 0.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _cachedArtworks = _computeArtworks(widget.album.songs);
  }

  @override
  void didUpdateWidget(covariant _AlbumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.album.songs, widget.album.songs)) {
      _cachedArtworks = _computeArtworks(widget.album.songs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_ArtEntry> _computeArtworks(List<Song> songs) {
    final seen = <String>{};
    final result = <_ArtEntry>[];
    for (final song in songs) {
      final art = song.albumArt;
      if (art != null && art.isNotEmpty && seen.add(art)) {
        result.add(_ArtEntry(art, song.filePath));
      }
      if (result.length >= 4) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final artworks = _cachedArtworks;
    final padded = List<_ArtEntry>.from(artworks);
    while (padded.length < 4) {
      padded.add(const _ArtEntry(null, null));
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _scaleAnimation.value,
              _scaleAnimation.value,
              1.0,
            )..rotateZ(_tiltAnimation.value),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artworkTargetWidth =
                        (constraints.maxWidth * devicePixelRatio).round();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppConstants.radiusLg),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppConstants.radiusLg),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildArtGrid(
                                    padded,
                                    artworkTargetWidth,
                                    context,
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.1),
                                            Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: AppConstants.spacingSm,
                                    bottom: AppConstants.spacingSm,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppConstants.spacingSm,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '${widget.album.songs.length} tracks',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.spacingSm,
                            AppConstants.spacingMd,
                            AppConstants.spacingSm,
                            AppConstants.spacingSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.album.albumName,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: context.adaptiveTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.album.albumArtist,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.adaptiveTextSecondary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtGrid(
    List<_ArtEntry> artworks,
    int targetWidth,
    BuildContext context,
  ) {
    final cellSize = targetWidth ~/ 2;
    final cellRadius = AppConstants.radiusSm;
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(cellRadius)),
            child: CachedImageWidget(
              imagePath: entry.art,
              audioSourcePath: entry.source,
              fit: BoxFit.cover,
              useThumbnail: true,
              thumbnailWidth: cellSize,
              thumbnailHeight: cellSize,
              placeholder: _buildGridPlaceholder(context),
              errorWidget: _buildGridPlaceholder(context),
            ),
          );
        }
        return _buildGridPlaceholder(context);
      }).toList(),
    );
  }

  Widget _buildGridPlaceholder(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
      child: Container(
        color: AppColors.surfaceLight,
        child: const Icon(
          LucideIcons.music,
          color: AppColors.textTertiary,
          size: 18,
        ),
      ),
    );
  }
}

class _AlbumListTile extends StatelessWidget {
  final AlbumGroup album;
  final VoidCallback onTap;

  const _AlbumListTile({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Song? artSong;
    for (final s in album.songs) {
      if (s.albumArt != null && s.albumArt!.isNotEmpty) {
        artSong = s;
        break;
      }
    }
    final artPath = artSong?.albumArt;
    final sourcePath = artSong?.filePath ?? album.songs.first.filePath;
    final trackCount = album.songs.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight.withValues(alpha: 0.65),
                AppColors.surface.withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CachedImageWidget(
                    imagePath: artPath,
                    audioSourcePath: sourcePath,
                    fit: BoxFit.cover,
                    useThumbnail: true,
                    thumbnailWidth: 104,
                    thumbnailHeight: 104,
                    placeholder: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.disc,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                    errorWidget: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.disc,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.albumName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$trackCount tracks • ${album.albumArtist}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Icon(
                LucideIcons.chevronRight,
                color: context.adaptiveTextTertiary,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtEntry {
  final String? art;
  final String? source;

  const _ArtEntry(this.art, this.source);
}

class _AlbumFilterSheet extends StatefulWidget {
  final _AlbumGridSortOption currentSort;
  final SongFileTypeFilter currentFilter;
  final int albumGridPageSize;
  final ValueChanged<_AlbumGridSortOption> onSortChanged;
  final ValueChanged<SongFileTypeFilter> onFilterChanged;
  final ValueChanged<int> onPageSizeChanged;

  const _AlbumFilterSheet({
    required this.currentSort,
    required this.currentFilter,
    required this.albumGridPageSize,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onPageSizeChanged,
  });

  @override
  State<_AlbumFilterSheet> createState() => _AlbumFilterSheetState();
}

class _AlbumFilterSheetState extends State<_AlbumFilterSheet> {
  late SongFileTypeFilter _selectedFilter;
  late double _pageSize;

  static const double _minPageSize = 1;
  static const double _maxPageSize = 30;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.currentFilter;
    _pageSize = widget.albumGridPageSize.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetSurface(
      maxHeightRatio: 0.7,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'SORT BY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            ..._AlbumGridSortOption.values.map(
              (option) => _buildAlbumSortTile(context, option),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'FILTER BY FORMAT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SongFileTypeFilter.values.map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    widget.onFilterChanged(filter);
                  },
                  child: AnimatedContainer(
                    duration: AppConstants.animationFast,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.glassBorder,
                        width: 1,
                      ),
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                    child: Text(
                      filter.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.accent
                            : context.adaptiveTextPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALBUM LIMIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.adaptiveTextTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Albums shown per page',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackgroundStrong,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_pageSize.round()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.textPrimary.withValues(alpha: 0.9),
                inactiveTrackColor: AppColors.glassBackgroundStrong,
                thumbColor: AppColors.textPrimary,
                overlayColor: AppColors.textPrimary.withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _pageSize,
                min: _minPageSize,
                max: _maxPageSize,
                divisions: (_maxPageSize - _minPageSize).round(),
                onChanged: (value) {
                  setState(() => _pageSize = value);
                  widget.onPageSizeChanged(value.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumSortTile(
    BuildContext context,
    _AlbumGridSortOption option,
  ) {
    final isSelected = widget.currentSort == option;
    final icon = _albumSortIcon(option);
    final label = _albumSortLabel(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onSortChanged(option);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.accent
                    : context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _albumSortIcon(_AlbumGridSortOption option) {
    switch (option) {
      case _AlbumGridSortOption.name:
        return LucideIcons.disc;
      case _AlbumGridSortOption.artist:
        return LucideIcons.mic;
      case _AlbumGridSortOption.tracks:
        return LucideIcons.hash;
    }
  }

  String _albumSortLabel(_AlbumGridSortOption option) {
    switch (option) {
      case _AlbumGridSortOption.name:
        return 'Album Name';
      case _AlbumGridSortOption.artist:
        return 'Album Artist';
      case _AlbumGridSortOption.tracks:
        return 'Track Count';
    }
  }
}

class _AlbumLoadMoreIndicator extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final bool isComplete;
  final VoidCallback? onLoadMore;

  const _AlbumLoadMoreIndicator({
    required this.visibleCount,
    required this.totalCount,
    this.isComplete = false,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final label = isComplete
        ? 'Showing all $totalCount albums'
        : 'Showing $visibleCount of $totalCount albums';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.7),
            AppColors.surface.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          if (!isComplete) ...[
            Icon(
              LucideIcons.chevronsDown,
              size: 18,
              color: context.adaptiveTextSecondary,
            ),
            const SizedBox(width: AppConstants.spacingSm),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isComplete || onLoadMore == null)
            Text(
              isComplete ? 'Done' : 'Scroll for more',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
              ),
            )
          else
            TextButton(
              onPressed: onLoadMore,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Show more',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _ContentStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: context.responsiveIcon(AppConstants.containerSizeLg),
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppConstants.spacingLg),
            action!,
          ],
        ],
      ),
    );
  }
}

class _PinchGestureRecognizer extends OneSequenceGestureRecognizer {
  _PinchGestureRecognizer();

  void Function(PointerDownEvent event)? onPointerDown;
  void Function(PointerMoveEvent event)? onPointerMove;
  void Function(PointerEvent event)? onPointerUp;

  final Map<int, Offset> _pointers = {};
  bool _pinchAccepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _pointers[event.pointer] = event.position;
    onPointerDown?.call(event);

    if (_pointers.length >= 2 && !_pinchAccepted) {
      _pinchAccepted = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _pointers[event.pointer] = event.position;
      onPointerMove?.call(event);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      onPointerUp?.call(event);
      stopTrackingPointer(event.pointer);
      if (_pointers.isEmpty) {
        _pinchAccepted = false;
      }
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pinchAccepted = false;
  }

  @override
  String get debugDescription => '_PinchGestureRecognizer';
}
