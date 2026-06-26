import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/uri_display_utils.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/floating_mini_player.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';

/// Groups songs by immediate subfolder relative to [prefix] within [folderUri].
({List<FolderGroup> subfolders, List<Song> songs}) groupByImmediateFolder({
  required List<Song> allSongs,
  required String folderUri,
  String prefix = '',
}) {
  final subfolderMap = <String, FolderGroup>{};
  final directSongs = <Song>[];

  for (final song in allSongs) {
    if (song.folderUri != folderUri) continue;

    final relPath =
        SongsState.extractRelativeSubfolder(song.folderUri, song.filePath);

    if (prefix.isNotEmpty) {
      if (relPath != prefix && !relPath.startsWith('$prefix/')) continue;
    }

    if (relPath == prefix) {
      directSongs.add(song);
    } else {
      final remainder =
          prefix.isEmpty ? relPath : relPath.substring(prefix.length + 1);
      final slashIdx = remainder.indexOf('/');
      final immediateFolder =
          slashIdx == -1 ? remainder : remainder.substring(0, slashIdx);
      final fullKey =
          prefix.isEmpty ? immediateFolder : '$prefix/$immediateFolder';
      subfolderMap.putIfAbsent(
        fullKey,
        () => FolderGroup(
          name: decodeUriDisplayComponent(immediateFolder),
          key: fullKey,
          folderUri: song.folderUri,
          songs: [],
        ),
      );
      subfolderMap[fullKey]!.songs.add(song);
    }
  }

  final sortedFolders = subfolderMap.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  directSongs.sort((a, b) => a.title.compareTo(b.title));

  return (subfolders: sortedFolders, songs: directSongs);
}

enum FolderRootSortOption { name, songCount }

enum FolderBrowserSortOption { name, songCount, title, artist, dateAdded }

enum FolderViewMode { grid, tree }

/// A node in the recursive folder tree shown by the tree view.
class _FolderTreeNode {
  final String folderUri;
  final String key;
  final String name;
  final List<Song> songs;
  final List<_FolderTreeNode> children;
  final int songCount;

  const _FolderTreeNode({
    required this.folderUri,
    required this.key,
    required this.name,
    required this.songs,
    required this.children,
    required this.songCount,
  });

  List<Song> get allSongs {
    final result = List<Song>.from(songs);
    for (final child in children) {
      result.addAll(child.allSongs);
    }
    return result;
  }
}

/// Top-level folders screen showing root music folders as a grid.
class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final MusicFolderService _folderService = MusicFolderService();
  List<MusicFolder> _folders = [];
  bool _isLoading = true;
  FolderRootSortOption _sortOption = FolderRootSortOption.name;
  FolderViewMode _viewMode = FolderViewMode.grid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).setVisible(true);
      _loadFolders();
    });
    _loadSortOption();
    _loadViewMode();
  }

  Future<void> _loadFolders() async {
    final folders = await _folderService.getSavedFolders();
    if (mounted) {
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('folder_root_sort_option');
    if (!mounted) return;
    final option = FolderRootSortOption.values.firstWhere(
      (v) => v.name == value,
      orElse: () => FolderRootSortOption.name,
    );
    if (option != _sortOption) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _setSortOption(FolderRootSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_root_sort_option', option.name);
    if (mounted) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('folder_view_mode');
    if (!mounted) return;
    final mode = FolderViewMode.values.firstWhere(
      (v) => v.name == value,
      orElse: () => FolderViewMode.grid,
    );
    if (mode != _viewMode) {
      setState(() => _viewMode = mode);
    }
  }

  Future<void> _setViewMode(FolderViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_view_mode', mode.name);
    if (mounted) {
      setState(() => _viewMode = mode);
    }
  }

  void _toggleViewMode() {
    _setViewMode(_viewMode == FolderViewMode.grid ? FolderViewMode.tree : FolderViewMode.grid);
  }

  void _showSortSheet() {
    final pageSize = ref.read(appPreferencesProvider).folderGridPageSize;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderRootSortSheet(
        currentOption: _sortOption,
        folderGridPageSize: pageSize,
        onSelected: (option) {
          _setSortOption(option);
          Navigator.of(context).pop();
        },
        onPageSizeChanged: (value) {
          ref.read(appPreferencesProvider.notifier).setFolderGridPageSize(value);
        },
      ),
    );
  }

  void _openRootFolder(MusicFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderBrowserScreen(
          folderUri: folder.uri,
          displayName: folder.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : _folders.isEmpty
                        ? _buildEmptyState()
                        : _viewMode == FolderViewMode.tree
                            ? _buildFoldersTree()
                            : _buildRootFoldersGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: IconButton(
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: context.adaptiveTextPrimary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                ),
                Text(
                  '${_folders.length} music folders',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: IconButton(
                  icon: Icon(
                    _viewMode == FolderViewMode.grid
                        ? LucideIcons.list
                        : LucideIcons.layoutGrid,
                    color: context.adaptiveTextSecondary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                  onPressed: _toggleViewMode,
                ),
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
                  icon: Icon(
                    Icons.sort_rounded,
                    color: context.adaptiveTextSecondary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                  onPressed: _showSortSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folderOpen,
            size: context.responsiveIcon(AppConstants.containerSizeLg),
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'No Folders Added',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Add music folders in Settings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootFoldersGrid() {
    final songsAsync = ref.watch(songsProvider);
    final allSongs = songsAsync.value?.songs ?? const [];

    // Build folder group-like objects for root folders with song data
    final rootGroups = <_RootFolderEntry>[];
    for (final folder in _folders) {
      final folderSongs =
          allSongs.where((s) => s.folderUri == folder.uri).toList();
      rootGroups.add(_RootFolderEntry(folder: folder, songs: folderSongs));
    }

    rootGroups.sort((a, b) {
      switch (_sortOption) {
        case FolderRootSortOption.name:
          return a.folder.displayName.compareTo(b.folder.displayName);
        case FolderRootSortOption.songCount:
          final countCompare = b.songs.length.compareTo(a.songs.length);
          if (countCompare != 0) return countCompare;
          return a.folder.displayName.compareTo(b.folder.displayName);
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          0,
          AppConstants.spacingLg,
          AppConstants.navBarHeight + 120,
        ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns(compact: 2, phone: 2, tablet: 3),
        childAspectRatio: 0.78,
        crossAxisSpacing: AppConstants.spacingMd,
        mainAxisSpacing: AppConstants.spacingLg,
      ),
      itemCount: rootGroups.length,
      itemBuilder: (context, index) {
        final entry = rootGroups[index];
        return _RootFolderCard(
          entry: entry,
          onTap: () => _openRootFolder(entry.folder),
        );
      },
      ),
    );
  }

  Widget _buildFoldersTree() {
    final songsAsync = ref.watch(songsProvider);
    final allSongs = songsAsync.value?.songs ?? const [];
    final roots = _resolveTree(allSongs);

    return _FolderTreeView(
      roots: roots,
      onFolderTap: (node) => _openTreeFolder(node),
      onSongTap: (node, song) => _playTreeSong(node, song),
    );
  }

  List<_FolderTreeNode>? _treeRoots;
  List<MusicFolder>? _treeRootsForFolders;
  Object? _treeRootsSongsId;
  int _treeRootsSongsLen = -1;

  List<_FolderTreeNode> _resolveTree(List<Song> allSongs) {
    if (_treeRoots != null &&
        identical(_treeRootsForFolders, _folders) &&
        identical(_treeRootsSongsId, allSongs) &&
        _treeRootsSongsLen == allSongs.length) {
      return _treeRoots!;
    }

    final roots = <_FolderTreeNode>[];
    for (final folder in _folders) {
      final folderSongs =
          allSongs.where((s) => s.folderUri == folder.uri).toList();
      roots.add(_buildTreeNode(folder.uri, '', folder.displayName, folderSongs));
    }

    roots.sort((a, b) {
      switch (_sortOption) {
        case FolderRootSortOption.name:
          return a.name.compareTo(b.name);
        case FolderRootSortOption.songCount:
          final countCompare = b.songCount.compareTo(a.songCount);
          if (countCompare != 0) return countCompare;
          return a.name.compareTo(b.name);
      }
    });

    _treeRoots = roots;
    _treeRootsForFolders = _folders;
    _treeRootsSongsId = allSongs;
    _treeRootsSongsLen = allSongs.length;
    return roots;
  }

  _FolderTreeNode _buildTreeNode(
    String folderUri,
    String prefix,
    String name,
    List<Song> folderSongs,
  ) {
    final grouped = groupByImmediateFolder(
      allSongs: folderSongs,
      folderUri: folderUri,
      prefix: prefix,
    );

    final children = grouped.subfolders.map((sub) {
      final childName = decodeUriDisplayComponent(sub.key.split('/').last);
      return _buildTreeNode(folderUri, sub.key, childName, sub.songs);
    }).toList();

    final childSongCount =
        children.fold<int>(0, (sum, node) => sum + node.songCount);

    return _FolderTreeNode(
      folderUri: folderUri,
      key: prefix,
      name: name,
      songs: grouped.songs,
      children: children,
      songCount: grouped.songs.length + childSongCount,
    );
  }

  void _openTreeFolder(_FolderTreeNode node) {
    final folder = _folders.firstWhere(
      (f) => f.uri == node.folderUri,
      orElse: () => MusicFolder(
        uri: node.folderUri,
        displayName: node.name,
        dateAdded: DateTime.now(),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderBrowserScreen(
          folderUri: folder.uri,
          displayName: folder.displayName,
          prefix: node.key,
        ),
      ),
    );
  }

  Future<void> _playTreeSong(_FolderTreeNode node, Song song) async {
    final playlist = node.allSongs;
    await ref.read(playerProvider.notifier).play(
          song,
          playlist: playlist,
          context: PlaybackContext(
            source: PlaybackSource.folder,
            sourceId: node.folderUri,
            sourceName: node.name,
          ),
        );
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_tree_song_${song.id}',
      );
    }
  }
}

class _RootFolderEntry {
  final MusicFolder folder;
  final List<Song> songs;

  const _RootFolderEntry({required this.folder, required this.songs});
}

/// Interactive folder card for root music folders.
class _RootFolderCard extends StatefulWidget {
  final _RootFolderEntry entry;
  final VoidCallback onTap;

  const _RootFolderCard({required this.entry, required this.onTap});

  @override
  State<_RootFolderCard> createState() => _RootFolderCardState();
}

class _RootFolderCardState extends State<_RootFolderCard>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.02)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _cachedArtworks = _computeArtworks(widget.entry.songs);
  }

  @override
  void didUpdateWidget(covariant _RootFolderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry.songs, widget.entry.songs)) {
      _cachedArtworks = _computeArtworks(widget.entry.songs);
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
                              _buildArtGrid(context, padded),
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
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.entry.songs.length} tracks',
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
                            widget.entry.folder.displayName,
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
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${widget.entry.songs.length} songs',
                              if (widget.entry.folder.isRemovable == true)
                                (widget.entry.folder.volumeState != null &&
                                        widget.entry.folder.volumeState != 'mounted')
                                    ? 'USB not connected'
                                    : 'External',
                            ].join(' · '),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtGrid(
      BuildContext context, List<_ArtEntry> artworks) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cardWidth = context.scaleSize(AppConstants.cardWidthMd);
    final targetWidth = (cardWidth * devicePixelRatio).round();
    final cellSize = targetWidth ~/ 2;

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return ClipRRect(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
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
      borderRadius:
          BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
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

/// Recursive folder browser showing subfolders and songs at the current level.
class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String folderUri;
  final String displayName;
  final String prefix;

  const FolderBrowserScreen({
    super.key,
    required this.folderUri,
    required this.displayName,
    this.prefix = '',
  });

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  List<Song> _allSongs = [];
  bool _isLoading = true;
  FolderBrowserSortOption _sortOption = FolderBrowserSortOption.name;
  SongFileTypeFilter _filterOption = SongFileTypeFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navBarVisibleProvider.notifier).setVisible(true);
      _loadSongs();
    });
    _loadSortOption();
    _loadFilterOption();
  }

  Future<void> _loadSongs() async {
    final repository = ref.read(songRepositoryProvider);
    final songs = await repository.getSongsByFolder(widget.folderUri);
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('folder_browser_sort_option');
    if (!mounted) return;
    final option = FolderBrowserSortOption.values.firstWhere(
      (v) => v.name == value,
      orElse: () => FolderBrowserSortOption.name,
    );
    if (option != _sortOption) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _loadFilterOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('folder_browser_filter_option');
    if (!mounted) return;
    final option = SongFileTypeFilter.values.firstWhere(
      (v) => v.name == value,
      orElse: () => SongFileTypeFilter.all,
    );
    if (option != _filterOption) {
      setState(() => _filterOption = option);
    }
  }

  Future<void> _setSortOption(FolderBrowserSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_browser_sort_option', option.name);
    if (mounted) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _setFilterOption(SongFileTypeFilter option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_browser_filter_option', option.name);
    if (mounted) {
      setState(() => _filterOption = option);
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderBrowserSortSheet(
        currentOption: _sortOption,
        currentFilter: _filterOption,
        onSelected: (option) {
          _setSortOption(option);
          Navigator.of(context).pop();
        },
        onFilterChanged: (option) {
          _setFilterOption(option);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, 0),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = groupByImmediateFolder(
      allSongs: _allSongs,
      folderUri: widget.folderUri,
      prefix: widget.prefix,
    );
    var subfolders = grouped.subfolders;
    var songs = grouped.songs;

    if (_filterOption != SongFileTypeFilter.all) {
      songs = songs
          .where((s) => _filterOption.matches(s.fileType))
          .toList();
      subfolders = subfolders
          .map((f) => FolderGroup(
                name: f.name,
                key: f.key,
                folderUri: f.folderUri,
                songs: f.songs
                    .where((s) => _filterOption.matches(s.fileType))
                    .toList(),
              ))
          .where((f) => f.songs.isNotEmpty)
          .toList();
    }

    switch (_sortOption) {
      case FolderBrowserSortOption.name:
        subfolders.sort((a, b) => a.key.compareTo(b.key));
      case FolderBrowserSortOption.songCount:
        subfolders.sort((a, b) {
          final c = b.songs.length.compareTo(a.songs.length);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      case FolderBrowserSortOption.title:
        songs.sort((a, b) => a.title.compareTo(b.title));
      case FolderBrowserSortOption.artist:
        songs.sort((a, b) {
          final c = a.artist.compareTo(b.artist);
          return c != 0 ? c : a.title.compareTo(b.title);
        });
      case FolderBrowserSortOption.dateAdded:
        songs.sort((a, b) {
          final da = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
    }

    final totalCount = subfolders.fold<int>(
          0,
          (sum, g) => sum + g.songs.length,
        ) +
        songs.length;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, totalCount),
                Expanded(
                  child: subfolders.isEmpty && songs.isEmpty
                      ? _buildEmptyState(context)
                      : _buildContent(context, subfolders, songs),
                ),
              ],
            ),
          ),
        ),
        const FloatingMiniPlayer(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final title =
        widget.prefix.isEmpty ? widget.displayName : widget.prefix.split('/').last;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(
                LucideIcons.arrowLeft,
                color: context.adaptiveTextPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.folder,
                      size: 18,
                      color: context.adaptiveTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextPrimary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count items',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: IconButton(
                  icon: Icon(
                    LucideIcons.shuffle,
                    color: context.adaptiveTextPrimary,
                    size: 20,
                  ),
                  onPressed: () => _shuffleAll(context),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.sort_rounded,
                    color: context.adaptiveTextPrimary,
                    size: 20,
                  ),
                  onPressed: _showSortSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<FolderGroup> subfolders,
    List<Song> songs,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: ListView(
        padding: EdgeInsets.only(bottom: AppConstants.navBarHeight + 120),
        children: [
        if (subfolders.isNotEmpty) ...[
          _buildSubfolderGrid(context, subfolders),
          if (songs.isNotEmpty)
            const SizedBox(height: AppConstants.spacingMd),
        ],
        for (final song in songs)
          Padding(
            key: ValueKey(song.id),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: AppConstants.spacingXxs,
            ),
            child: _SongTile(
              song: song,
              onTap: () => _playSong(song, songs, subfolders),
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildSubfolderGrid(
      BuildContext context, List<FolderGroup> subfolders) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        0,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns(compact: 2, phone: 2, tablet: 3),
        childAspectRatio: 0.78,
        crossAxisSpacing: AppConstants.spacingMd,
        mainAxisSpacing: AppConstants.spacingLg,
      ),
      itemCount: subfolders.length,
      itemBuilder: (context, index) {
        final folder = subfolders[index];
        return _SubfolderCard(
          folder: folder,
          onTap: () => _openSubfolder(context, folder),
        );
      },
    );
  }

  void _openSubfolder(BuildContext context, FolderGroup folder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderBrowserScreen(
          folderUri: widget.folderUri,
          displayName: widget.displayName,
          prefix: folder.key,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folderOpen,
            size: 56,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            'No Songs Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'This folder appears to be empty',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
          ),
        ],
      ),
    );
  }

  PlaybackContext get _folderContext => PlaybackContext(
    source: PlaybackSource.folder,
    sourceId: widget.folderUri,
    sourceName: widget.displayName,
  );

  Future<void> _playSong(
    Song song,
    List<Song> directSongs,
    List<FolderGroup> subfolders,
  ) async {
    final playlist = _buildPlaylist(directSongs, subfolders);
    await ref.read(playerProvider.notifier).play(song, playlist: playlist, context: _folderContext);
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_song_${song.id}',
      );
    }
  }

  List<Song> _buildPlaylist(
      List<Song> directSongs, List<FolderGroup> subfolders) {
    final result = <Song>[];
    for (final folder in subfolders) {
      result.addAll(folder.songs);
    }
    result.addAll(directSongs);
    return result;
  }

  Future<void> _shuffleAll(BuildContext context) async {
    final (:subfolders, :songs) = groupByImmediateFolder(
      allSongs: _allSongs,
      folderUri: widget.folderUri,
      prefix: widget.prefix,
    );
    final playlist = _buildPlaylist(songs, subfolders);
    if (playlist.isEmpty) return;
    final shuffled = List<Song>.from(playlist)..shuffle(Random());
    await ref.read(playerProvider.notifier).play(
          shuffled.first,
          playlist: shuffled,
          context: _folderContext,
        );
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_shuffle_${widget.prefix}',
      );
    }
  }
}

/// Interactive folder card for subfolders in the browser.
class _SubfolderCard extends StatefulWidget {
  final FolderGroup folder;
  final VoidCallback onTap;

  const _SubfolderCard({required this.folder, required this.onTap});

  @override
  State<_SubfolderCard> createState() => _SubfolderCardState();
}

class _SubfolderCardState extends State<_SubfolderCard>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.02)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _cachedArtworks = _RootFolderCardState._computeArtworks(widget.folder.songs);
  }

  @override
  void didUpdateWidget(covariant _SubfolderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.folder.songs, widget.folder.songs)) {
      _cachedArtworks = _RootFolderCardState._computeArtworks(widget.folder.songs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                              _buildArtGrid(context, padded),
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
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
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
                          const SizedBox(height: 2),
                          Text(
                            '${widget.folder.songs.length} songs',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtGrid(BuildContext context, List<_ArtEntry> artworks) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cardWidth = context.scaleSize(AppConstants.cardWidthMd);
    final targetWidth = (cardWidth * devicePixelRatio).round();
    final cellSize = targetWidth ~/ 2;

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return ClipRRect(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
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
      borderRadius:
          BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
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

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            children: [
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: context.adaptiveTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} • ${song.fileType.toUpperCase()}',
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
              Text(
                song.formattedDuration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

/// Expandable tree view of folder hierarchies with their songs.
class _FolderTreeView extends StatefulWidget {
  final List<_FolderTreeNode> roots;
  final ValueChanged<_FolderTreeNode> onFolderTap;
  final void Function(_FolderTreeNode, Song) onSongTap;

  const _FolderTreeView({
    required this.roots,
    required this.onFolderTap,
    required this.onSongTap,
  });

  @override
  State<_FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<_FolderTreeView> {
  final Set<String> _expandedKeys = {};

  static const double _indentStep = 20.0;
  static const double _guideOffset = 10.0;

  String _nodeKey(_FolderTreeNode node) => '${node.folderUri}::${node.key}';

  Color _guideColor(BuildContext context) =>
      context.adaptiveTextTertiary.withValues(alpha: 0.25);

  void _toggleNode(_FolderTreeNode node) {
    final key = _nodeKey(node);
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        0,
        AppConstants.spacingMd,
        AppConstants.navBarHeight + 120,
      ),
      itemCount: widget.roots.length,
      itemBuilder: (context, index) {
        final node = widget.roots[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                index == widget.roots.length - 1 ? 0 : AppConstants.spacingSm,
          ),
          child: _buildNode(node, 0),
        );
      },
    );
  }

  Widget _buildNode(_FolderTreeNode node, int depth) {
    final key = _nodeKey(node);
    final isExpanded = _expandedKeys.contains(key);
    final hasChildren = node.children.isNotEmpty || node.songs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FolderTreeRow(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          step: _indentStep,
          offset: _guideOffset,
          guideColor: _guideColor(context),
          onToggle: hasChildren ? () => _toggleNode(node) : null,
          onOpen: () => widget.onFolderTap(node),
        ),
        AnimatedSize(
          duration: AppConstants.animationNormal,
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: isExpanded
              ? _TreeLevelLine(
                  x: depth * _indentStep + _guideOffset,
                  color: _guideColor(context),
                  child: _buildChildrenColumn(node, depth),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  Widget _buildChildrenColumn(_FolderTreeNode node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in node.children) _buildNode(child, depth + 1),
        for (final song in node.songs)
          _FolderTreeSongTile(
            song: song,
            depth: depth + 1,
            step: _indentStep,
            offset: _guideOffset,
            color: _guideColor(context),
            onTap: () => widget.onSongTap(node, song),
          ),
      ],
    );
  }
}

/// A folder row in the tree: glass container with an animated expand chevron,
/// a folder icon that opens when expanded, and a horizontal tick that connects
/// it to its parent's guide line.
class _FolderTreeRow extends StatelessWidget {
  final _FolderTreeNode node;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;
  final double step;
  final double offset;
  final Color guideColor;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;

  const _FolderTreeRow({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.hasChildren,
    required this.step,
    required this.offset,
    required this.guideColor,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: depth > 0
          ? _TreeTickPainter(
              (depth - 1) * step + offset,
              depth * step,
              guideColor,
            )
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: depth * step,
          top: AppConstants.spacingXxs,
          bottom: AppConstants.spacingXxs,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            onTap: onOpen,
            child: AnimatedContainer(
              duration: AppConstants.animationFast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingSm,
                vertical: AppConstants.spacingXs,
              ),
              decoration: BoxDecoration(
                color: isExpanded
                    ? AppColors.glassBackgroundStrong
                    : AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: isExpanded
                      ? AppColors.glassBorderStrong
                      : AppColors.glassBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildChevron(context),
                  const SizedBox(width: AppConstants.spacingXs),
                  Icon(
                    isExpanded ? LucideIcons.folderOpen : LucideIcons.folder,
                    size: 18,
                    color: isExpanded
                        ? context.adaptiveTextPrimary
                        : context.adaptiveTextSecondary,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: context.adaptiveTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: context.adaptiveTextTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (node.children.isNotEmpty) _buildCountBadge(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    if (node.children.isNotEmpty) {
      final count = node.children.length;
      return '$count ${count == 1 ? 'subfolder' : 'subfolders'}';
    }
    if (node.songs.isNotEmpty) {
      final count = node.songs.length;
      return '$count ${count == 1 ? 'song' : 'songs'}';
    }
    return 'Empty';
  }

  Widget _buildChevron(BuildContext context) {
    if (!hasChildren) {
      return SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0.0,
            duration: AppConstants.animationFast,
            child: Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        '${node.songCount}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A song leaf in the tree, indented and tick-connected to its parent's line.
class _FolderTreeSongTile extends StatelessWidget {
  final Song song;
  final int depth;
  final double step;
  final double offset;
  final Color color;
  final VoidCallback onTap;

  const _FolderTreeSongTile({
    required this.song,
    required this.depth,
    required this.step,
    required this.offset,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TreeTickPainter(
        (depth - 1) * step + offset,
        depth * step,
        color,
      ),
      child: Padding(
        padding: EdgeInsets.only(left: depth * step),
        child: _SongTile(song: song, onTap: onTap),
      ),
    );
  }
}

/// Draws a single vertical guide line at [x] spanning its child's height.
class _TreeLevelLine extends StatelessWidget {
  final double x;
  final Color color;
  final Widget child;

  const _TreeLevelLine({
    required this.x,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalLinePainter(x, color),
      child: child,
    );
  }
}

class _VerticalLinePainter extends CustomPainter {
  final double x;
  final Color color;

  _VerticalLinePainter(this.x, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_VerticalLinePainter old) => true;
}

/// Draws a horizontal tick from [fromX] to [toX] at vertical center.
class _TreeTickPainter extends CustomPainter {
  final double fromX;
  final double toX;
  final Color color;

  _TreeTickPainter(this.fromX, this.toX, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(fromX, y),
      Offset(toX, y),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_TreeTickPainter old) =>
      old.fromX != fromX || old.toX != toX || old.color != color;
}

class _FolderRootSortSheet extends StatefulWidget {
  final FolderRootSortOption currentOption;
  final int folderGridPageSize;
  final ValueChanged<FolderRootSortOption> onSelected;
  final ValueChanged<int> onPageSizeChanged;

  const _FolderRootSortSheet({
    required this.currentOption,
    required this.folderGridPageSize,
    required this.onSelected,
    required this.onPageSizeChanged,
  });

  @override
  State<_FolderRootSortSheet> createState() => _FolderRootSortSheetState();
}

class _FolderRootSortSheetState extends State<_FolderRootSortSheet> {
  late double _pageSize;

  static const double _minPageSize = 1;
  static const double _maxPageSize = 30;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.folderGridPageSize.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'SORT BY'),
              const SizedBox(height: 8),
              ...FolderRootSortOption.values.map(
                (option) => _buildSortTile(context, option),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: 12),
              _buildSectionHeader(context, 'FOLDER LIMIT'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Folders shown per page',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSortTile(BuildContext context, FolderRootSortOption option) {
    final isSelected = widget.currentOption == option;
    final icon = _iconFor(option);
    final label = _labelFor(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onSelected(option);
          Navigator.of(context).pop();
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  IconData _iconFor(FolderRootSortOption option) {
    switch (option) {
      case FolderRootSortOption.name:
        return LucideIcons.type;
      case FolderRootSortOption.songCount:
        return LucideIcons.hash;
    }
  }

  String _labelFor(FolderRootSortOption option) {
    switch (option) {
      case FolderRootSortOption.name:
        return 'Name (A-Z)';
      case FolderRootSortOption.songCount:
        return 'Song Count';
    }
  }
}

class _FolderBrowserSortSheet extends StatelessWidget {
  final FolderBrowserSortOption currentOption;
  final SongFileTypeFilter currentFilter;
  final ValueChanged<FolderBrowserSortOption> onSelected;
  final ValueChanged<SongFileTypeFilter> onFilterChanged;

  const _FolderBrowserSortSheet({
    required this.currentOption,
    required this.currentFilter,
    required this.onSelected,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'SORT BY'),
              const SizedBox(height: 8),
              ...FolderBrowserSortOption.values.map(
                (option) => _buildSortTile(context, option),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: 12),
              _buildSectionHeader(context, 'FILTER BY FORMAT'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SongFileTypeFilter.values
                    .map((filter) => _buildFilterChip(context, filter))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSortTile(BuildContext context, FolderBrowserSortOption option) {
    final isSelected = currentOption == option;
    final icon = _iconFor(option);
    final label = _labelFor(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onSelected(option);
          Navigator.of(context).pop();
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  IconData _iconFor(FolderBrowserSortOption option) {
    switch (option) {
      case FolderBrowserSortOption.name:
        return LucideIcons.folder;
      case FolderBrowserSortOption.songCount:
        return LucideIcons.hash;
      case FolderBrowserSortOption.title:
        return LucideIcons.type;
      case FolderBrowserSortOption.artist:
        return LucideIcons.mic;
      case FolderBrowserSortOption.dateAdded:
        return LucideIcons.calendar;
    }
  }

  String _labelFor(FolderBrowserSortOption option) {
    switch (option) {
      case FolderBrowserSortOption.name:
        return 'Folder Name';
      case FolderBrowserSortOption.songCount:
        return 'Folder Song Count';
      case FolderBrowserSortOption.title:
        return 'Song Title';
      case FolderBrowserSortOption.artist:
        return 'Song Artist';
      case FolderBrowserSortOption.dateAdded:
        return 'Date Added';
    }
  }

  Widget _buildFilterChip(BuildContext context, SongFileTypeFilter filter) {
    final isSelected = currentFilter == filter;
    return GestureDetector(
      onTap: () {
        onFilterChanged(filter);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppColors.accent
                : context.adaptiveTextPrimary,
          ),
        ),
      ),
    );
  }
}
