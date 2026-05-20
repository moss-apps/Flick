import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/widgets/common/glass_search_bar.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Main songs screen with orbital scrolling.
class SongsScreen extends ConsumerStatefulWidget {
  /// Callback when navigation to a different tab is requested from full player
  final ValueChanged<int>? onNavigationRequested;

  const SongsScreen({super.key, this.onNavigationRequested});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  static const double _listItemExtent = 80;
  static const int _folderGridPageSize = 18;
  static const double _folderGridLoadMoreThreshold = 320;
  static const int _listPageSize = 50;
  static const double _listLoadMoreThreshold = 320;

  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _folderGridScrollController = ScrollController();
  final OrbitScrollController _orbitScrollController = OrbitScrollController();
  String _searchQuery = '';
  List<Song> _cachedSongs = [];
  List<Song> _cachedDisplaySongs = [];
  String _selectedFastToken = 'A';
  late final ProviderSubscription<Song?> _currentSongSubscription;
  bool _alignedCurrentSongAfterLoad = false;
  Timer? _fastIndexTimer;
  bool _fastIndexVisible = true;
  int _visibleFolderCount = _folderGridPageSize;
  int _totalFolderCount = 0;
  String _folderPaginationSignature = '';
  int _visibleListCount = _listPageSize;
  String _listPaginationSignature = '';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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
    _folderGridScrollController.addListener(_onFolderGridScroll);
  }

  @override
  void dispose() {
    _currentSongSubscription.close();
    _listScrollController.removeListener(_onListScroll);
    _folderGridScrollController.removeListener(_onFolderGridScroll);
    _listScrollController.dispose();
    _folderGridScrollController.dispose();
    _searchController.dispose();
    _fastIndexTimer?.cancel();
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
    final isFolderMode = sortOption == SongSortOption.folder;
    final shouldReserveOrbitBottomSpace =
        viewMode != SongViewMode.list && navBarVisible && !isFolderMode;

    return DisplayModeWrapper(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background ambient effects
          _buildAmbientBackground(),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header with sort option
                AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
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
                  const SizedBox(height: AppConstants.spacingMd),
                ],

                // Content based on async state
                Expanded(
                  child: songsAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (error, stack) => _buildErrorState(error),
                    data: (songsState) {
                      final isFolderMode =
                          songsState.sortOption == SongSortOption.folder;
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

                      if (!isFolderMode) {
                        final sig = '${songs.length}:${songs.isNotEmpty ? songs.first.id : ''}';
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

                      if (isFolderMode) {
                        final folderGroups = songsState.folderGroups;
                        if (_searchQuery.isNotEmpty) {
                          final filteredGroups = <FolderGroup>[];
                          for (final group in folderGroups) {
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
                                FolderGroup(
                                  name: group.name,
                                  key: group.key,
                                  folderUri: group.folderUri,
                                  songs: filtered,
                                ),
                              );
                            }
                          }
                          if (filteredGroups.isEmpty) {
                            return _buildNoSearchResultsState();
                          }
                          return _buildFolderGridView(filteredGroups);
                        }
                        if (folderGroups.isEmpty) {
                          return _buildEmptyState();
                        }
                        return _buildFolderGridView(folderGroups);
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
                      ? AppConstants.navBarHeight + 90
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
      child: ListView.builder(
        controller: _listScrollController,
        itemExtent: _listItemExtent,
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          0,
          0,
          AppConstants.navBarHeight + 120,
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
      ),
    );
  }

  Widget _buildFolderGridView(List<FolderGroup> folders) {
    _syncFolderPagination(folders);

    final visibleCount = min(_visibleFolderCount, folders.length);
    final visibleFolders = folders.take(visibleCount).toList(growable: false);
    final hasMore = visibleCount < folders.length;

    return CustomScrollView(
      controller: _folderGridScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            0,
            AppConstants.spacingLg,
            AppConstants.spacingLg,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.gridColumns(
                compact: 2,
                phone: 2,
                tablet: 3,
              ),
              childAspectRatio: 0.78,
              crossAxisSpacing: AppConstants.spacingMd,
              mainAxisSpacing: AppConstants.spacingLg,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final folder = visibleFolders[index];
              return _FolderCard(
                folder: folder,
                onTap: () => _openFolderDetail(folder),
              );
            }, childCount: visibleFolders.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              0,
              AppConstants.spacingLg,
              AppConstants.navBarHeight + 120,
            ),
            child: hasMore
                ? _FolderLoadMoreIndicator(
                    visibleCount: visibleCount,
                    totalCount: folders.length,
                  )
                : visibleCount > _folderGridPageSize
                ? _FolderLoadMoreIndicator(
                    visibleCount: visibleCount,
                    totalCount: folders.length,
                    isComplete: true,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  void _openFolderDetail(FolderGroup folder) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FolderDetailScreen(folder: folder),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (AppConstants.animationNormal == Duration.zero) {
            return child;
          }
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppConstants.animationNormal,
        opaque: true,
      ),
    );
  }

  void _syncFolderPagination(List<FolderGroup> folders) {
    final totalSongCount = folders.fold<int>(
      0,
      (sum, folder) => sum + folder.songs.length,
    );
    final signature =
        '$_searchQuery|${folders.length}|$totalSongCount|${folders.isNotEmpty ? folders.first.key : ''}|${folders.isNotEmpty ? folders.last.key : ''}';

    _totalFolderCount = folders.length;

    if (_folderPaginationSignature != signature) {
      _folderPaginationSignature = signature;
      _visibleFolderCount = min(_folderGridPageSize, folders.length);

      if (_folderGridScrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_folderGridScrollController.hasClients) return;
          _folderGridScrollController.jumpTo(0);
        });
      }
      return;
    }

    if (_visibleFolderCount > folders.length) {
      _visibleFolderCount = folders.length;
    } else if (_visibleFolderCount == 0 && folders.isNotEmpty) {
      _visibleFolderCount = min(_folderGridPageSize, folders.length);
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
      case SongSortOption.folder:
        text = SongsState.folderDisplayName(song.folderUri, song.filePath);
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
    if (position.pixels >=
        position.maxScrollExtent - _listLoadMoreThreshold) {
      _loadMoreListSongs();
    }
  }

  void _onFolderGridScroll() {
    if (!_folderGridScrollController.hasClients) return;

    final position = _folderGridScrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - _folderGridLoadMoreThreshold) {
      _loadMoreFolders();
    }
  }

  void _loadMoreFolders() {
    if (!mounted || _visibleFolderCount >= _totalFolderCount) {
      return;
    }

    setState(() {
      _visibleFolderCount = min(
        _visibleFolderCount + _folderGridPageSize,
        _totalFolderCount,
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
    if (_visibleListCount != _listPageSize) {
      _visibleListCount = _listPageSize;
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
        debugPrint('Failed to add favorite for ${song.id}: $error');
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

  Widget _buildAmbientBackground() {
    return Stack(
      children: [
        // Top-left glow
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Center-right glow (follows selected item area)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AsyncValue<SongsState> songsAsync) {
    final songCount = songsAsync.value?.songs.length ?? 0;
    final currentSort =
        songsAsync.value?.sortOption ?? SongSortOption.albumArtist;
    final currentFilter =
        songsAsync.value?.fileTypeFilter ?? SongFileTypeFilter.all;

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
              Container(
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
                  onPressed: () {
                    SortFilterBottomSheet.show(
                      context,
                      currentSort: currentSort,
                      currentFilter: currentFilter,
                      onSortChanged: (option) {
                        ref.read(songsProvider.notifier).setSortOption(option);
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader() {
    final count = _selectedIds.length;
    final allSelected =
        count == _cachedDisplaySongs.length && _cachedDisplaySongs.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x),
            color: context.adaptiveTextPrimary,
            onPressed: _exitSelectionMode,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              '$count selected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
            ),
          ),
          if (!allSelected)
            TextButton(
              onPressed: () => _selectAll(_cachedDisplaySongs),
              child: Text(
                'Select All',
                style: TextStyle(color: context.adaptiveTextSecondary),
              ),
            ),
          IconButton(
            icon: Icon(
              LucideIcons.listPlus,
              color: AppColors.accent.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? () => _queueSelected() : null,
            tooltip: 'Queue selected',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.heart,
              color: Colors.red.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? () => _favoriteSelected() : null,
            tooltip: 'Favorite selected',
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
                  isMultiSelected
                      ? LucideIcons.check
                      : LucideIcons.circle,
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

class _FolderCard extends StatefulWidget {
  final FolderGroup folder;
  final VoidCallback onTap;

  const _FolderCard({required this.folder, required this.onTap});

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard>
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
    _cachedArtworks = _computeArtworks(widget.folder.songs);
  }

  @override
  void didUpdateWidget(covariant _FolderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.folder.songs, widget.folder.songs)) {
      _cachedArtworks = _computeArtworks(widget.folder.songs);
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
    final cardWidth = context.scaleSize(AppConstants.cardWidthMd);
    final artworkTargetWidth = (cardWidth * devicePixelRatio).round();
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
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
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
                                          Colors.black.withValues(alpha: 0.45),
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
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '${widget.folder.songs.length} tracks',
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
                              widget.folder.name,
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
                              '${widget.folder.songs.length} songs',
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
                  ),
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

class _ArtEntry {
  final String? art;
  final String? source;

  const _ArtEntry(this.art, this.source);
}

class _FolderDetailScreen extends ConsumerStatefulWidget {
  final FolderGroup folder;

  const _FolderDetailScreen({required this.folder});

  @override
  ConsumerState<_FolderDetailScreen> createState() =>
      _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<_FolderDetailScreen> {
  late final List<_ArtEntry> _cachedArtworks;

  @override
  void initState() {
    super.initState();
    _cachedArtworks = _FolderCardState._computeArtworks(widget.folder.songs);
  }

  @override
  Widget build(BuildContext context) {
    final artworks = _cachedArtworks;
    final padded = List<_ArtEntry>.from(artworks);
       final f = widget.folder;
        final totalDuration = f.songs.fold<Duration>(
          Duration.zero,
          (sum, song) => sum + song.duration,
        );
        final uniqueArtists = f.songs
            .map((song) => song.artist.trim())
            .where((artist) => artist.isNotEmpty)
            .toSet()
            .length;
        final uniqueFormats = f.songs
            .map((song) => song.fileType.toUpperCase())
            .where((format) => format.isNotEmpty)
            .toSet()
            .length;
        final totalAlbums = f.songs
            .map((song) => (song.album ?? '').trim())
            .where((album) => album.isNotEmpty)
            .toSet()
            .length;
    while (padded.length < 4) {
      padded.add(const _ArtEntry(null, null));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
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
                  _buildHeaderArtGrid(context, padded),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.8),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppConstants.spacingLg,
                    right: AppConstants.spacingLg,
                    bottom: AppConstants.spacingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingSm,
                            vertical: AppConstants.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Text(
                            'Folder Collection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                      Text(
                        f.name,
                        style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: context.adaptiveTextPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalAlbums albums • $uniqueArtists artists',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.adaptiveTextSecondary),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        Wrap(
                          spacing: AppConstants.spacingSm,
                          runSpacing: AppConstants.spacingSm,
                          children: [
                            _FolderSummaryPill(
                              icon: LucideIcons.music4,
                               label: '${f.songs.length} tracks',
                            ),
                            _FolderSummaryPill(
                              icon: LucideIcons.clock3,
                              label: _formatCollectionDuration(totalDuration),
                            ),
                            _FolderSummaryPill(
                              icon: LucideIcons.audioLines,
                              label: '$uniqueFormats formats',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingLg,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceLight.withValues(alpha: 0.9),
                      AppColors.surface.withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Play from this folder',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppConstants.spacingXs),
                      Text(
                        'Tracks stay grouped in this folder, with artwork, format, and album details surfaced inline.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: _FolderActionButton(
                              icon: LucideIcons.play,
                              label: 'Play All',
                              emphasized: true,
                               onTap: () => _playFolder(
                                 f.songs.first,
                                 f,
                               ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingSm),
                          Expanded(
                            child: _FolderActionButton(
                              icon: LucideIcons.shuffle,
                              label: 'Shuffle',
                               onTap: () => _shufflePlayFolder(f),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                0,
                AppConstants.spacingLg,
                AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Text(
                    'Track List',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.adaptiveTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                   Text(
                     '${f.songs.length} songs',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.navBarHeight + 120,
            ),
            sliver: SliverList(
               delegate: SliverChildBuilderDelegate((context, index) {
                 final song = f.songs[index];
                return Padding(
                  key: ValueKey(song.id),
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    0,
                    AppConstants.spacingLg,
                    AppConstants.spacingSm,
                  ),
                  child: _FolderDetailTrackTile(
                    song: song,
                    index: index,
                     onTap: () => _playFolder(song, f),
                    onLongPress: () =>
                        SongActionsBottomSheet.show(context, song),
                  ),
                );
               }, childCount: f.songs.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderArtGrid(BuildContext context, List<_ArtEntry> artworks) {
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return CachedImageWidget(
            imagePath: entry.art,
            audioSourcePath: entry.source,
            fit: BoxFit.cover,
            placeholder: _buildHeaderPlaceholder(context),
            errorWidget: _buildHeaderPlaceholder(context),
          );
        }
        return _buildHeaderPlaceholder(context);
      }).toList(),
    );
  }

  Widget _buildHeaderPlaceholder(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Icon(
        LucideIcons.music,
        size: 40,
        color: context.adaptiveTextTertiary,
      ),
    );
  }

  Future<void> _shufflePlayFolder(FolderGroup folder) async {
    if (folder.songs.isEmpty) return;
    final shuffled = List<Song>.from(folder.songs)..shuffle(Random());
    await ref
        .read(playerProvider.notifier)
        .play(shuffled.first, playlist: shuffled);
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_shuffle_${folder.key}',
      );
    }
  }

  Future<void> _playFolder(Song song, FolderGroup folder) async {
    await ref.read(playerProvider.notifier).play(song, playlist: folder.songs);
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_song_${song.id}',
      );
    }
  }

  String _formatCollectionDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes.remainder(60);
      return '${duration.inHours}h ${minutes}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

class _FolderLoadMoreIndicator extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final bool isComplete;

  const _FolderLoadMoreIndicator({
    required this.visibleCount,
    required this.totalCount,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = isComplete
        ? 'Showing all $totalCount folders'
        : 'Showing $visibleCount of $totalCount folders';

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
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.adaptiveTextSecondary,
                ),
              ),
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
          Text(
            isComplete ? 'Done' : 'Scroll for more',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderSummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FolderSummaryPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const _FolderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = emphasized
        ? AppColors.accent.withValues(alpha: 0.18)
        : AppColors.surfaceLight.withValues(alpha: 0.8);
    final borderColor = emphasized
        ? AppColors.accent.withValues(alpha: 0.35)
        : AppColors.glassBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: context.adaptiveTextPrimary),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderDetailTrackTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderDetailTrackTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final metaStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.adaptiveTextSecondary);
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.adaptiveTextTertiary,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: Ink(
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight.withValues(alpha: 0.82),
                AppColors.surface.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundStrong,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  _trackLabel(song, index),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    useThumbnail: true,
                    thumbnailWidth: 112,
                    thumbnailHeight: 112,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _primaryMeta(song),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _secondaryMeta(song),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: detailStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    LucideIcons.play,
                    size: 16,
                    color: context.adaptiveTextTertiary,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Text(
                    song.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

  String _trackLabel(Song song, int index) {
    final trackNumber = song.trackNumber;
    if (trackNumber != null && trackNumber > 0) {
      return trackNumber.toString().padLeft(2, '0');
    }
    return (index + 1).toString().padLeft(2, '0');
  }

  String _primaryMeta(Song song) {
    final album = (song.album ?? '').trim();
    if (album.isEmpty) {
      return song.artist;
    }
    return '${song.artist} • $album';
  }

  String _secondaryMeta(Song song) {
    final parts = <String>[song.fileType.toUpperCase()];
    if (song.resolution != null && song.resolution!.trim().isNotEmpty) {
      parts.add(song.resolution!.trim());
    }
    if (song.discNumber != null && song.discNumber! > 0) {
      parts.add('Disc ${song.discNumber}');
    }
    return parts.join(' • ');
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
