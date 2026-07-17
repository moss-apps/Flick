import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/widgets/common/blurred_song_background.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';

/// Number of songs fetched per page.
const int _kPageSize = 50;

/// Pixels from the bottom of the list that trigger the next page load.
const double _kLoadMoreThreshold = 300;

/// Recently Added screen: every scanned song, newest first, paginated.
class RecentlyAddedScreen extends StatefulWidget {
  const RecentlyAddedScreen({super.key});

  @override
  State<RecentlyAddedScreen> createState() => _RecentlyAddedScreenState();
}

class _RecentlyAddedScreenState extends State<RecentlyAddedScreen> {
  final PlayerService _playerService = PlayerService();
  final SongRepository _songRepository = SongRepository();
  final ScrollController _scrollController = ScrollController();

  List<Song> _songs = [];
  Map<String, List<Song>> _groupedSongs = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  StreamSubscription<void>? _songsSubscription;
  Timer? _watchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh(silent: false);
      _watchSongs();
    });
  }

  @override
  void dispose() {
    _watchDebounce?.cancel();
    _songsSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _watchSongs() {
    // The songs collection is noisy: background metadata extraction and
    // album-art writes fire watchLazy repeatedly. Debounce so we don't reload
    // on every write, and refresh silently so the ListView never unmounts and
    // the scroll position is preserved.
    _songsSubscription = _songRepository.watchSongs().listen((_) {
      _watchDebounce?.cancel();
      _watchDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _refresh(silent: true);
      });
    });
  }

  Future<void> _refresh({required bool silent}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
      });
    }

    try {
      final count = await _songRepository.getSongCount();
      // Keep at least as many rows as the user has already paged into view so a
      // background refresh never shrinks the list and yanks the scroll offset.
      final limit = _songs.length > _kPageSize ? _songs.length : _kPageSize;
      final songs = await _songRepository.getRecentlyAddedSongs(
        offset: 0,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _groupedSongs = _groupSongs(songs);
        _totalCount = count;
        _hasMore = songs.length < count;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _songs = [];
          _groupedSongs = {};
          _totalCount = 0;
          _hasMore = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final next = await _songRepository.getRecentlyAddedSongs(
        offset: _songs.length,
        limit: _kPageSize,
      );
      if (mounted) {
        setState(() {
          _songs.addAll(next);
          _groupedSongs = _groupSongs(_songs);
          _hasMore = _songs.length < _totalCount;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _kLoadMoreThreshold) {
      _loadMore();
    }
  }

  Map<String, List<Song>> _groupSongs(List<Song> songs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    final grouped = <String, List<Song>>{};

    for (final song in songs) {
      final added = song.dateAdded;
      final String groupKey;
      if (added == null) {
        groupKey = 'Earlier';
      } else {
        final addedDate = DateTime(added.year, added.month, added.day);
        if (addedDate == today) {
          groupKey = 'Today';
        } else if (addedDate == yesterday) {
          groupKey = 'Yesterday';
        } else if (addedDate.isAfter(thisWeekStart) ||
            addedDate == thisWeekStart) {
          groupKey = 'This Week';
        } else if (addedDate.isAfter(lastWeekStart) ||
            addedDate == lastWeekStart) {
          groupKey = 'Last Week';
        } else if (addedDate.isAfter(thisMonthStart) ||
            addedDate == thisMonthStart) {
          groupKey = 'This Month';
        } else {
          groupKey = 'Earlier';
        }
      }

      grouped.putIfAbsent(groupKey, () => []).add(song);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlurredSongBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _groupedSongs.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
                ),
              ],
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recently Added',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Text(
                  '$_totalCount ${_totalCount == 1 ? 'song' : 'songs'} in your library',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: context.adaptiveTextSecondary),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 3,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.glassBorder.withValues(alpha: 0),
                          AppColors.glassBorder,
                          AppColors.glassBorder.withValues(alpha: 0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: context.scaleSize(AppConstants.containerSizeXl),
                    height: context.scaleSize(AppConstants.containerSizeXl),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassBackground,
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      size: context.responsiveIcon(AppConstants.iconSizeXl),
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'No New Additions Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Songs you scan into your library will show up here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.adaptiveTextTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    const sectionOrder = [
      'Today',
      'Yesterday',
      'This Week',
      'Last Week',
      'This Month',
      'Earlier',
    ];

    final sortedSections = _groupedSongs.entries.toList()
      ..sort((a, b) {
        final aIndex = sectionOrder.indexOf(a.key);
        final bIndex = sectionOrder.indexOf(b.key);
        return aIndex.compareTo(bIndex);
      });

    final rows = <_RecentlyAddedRow>[];
    for (final section in sortedSections) {
      rows.add(_RecentlyAddedRow.header(section.key, section.value.length));
      for (final song in section.value) {
        rows.add(_RecentlyAddedRow.song(song));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: AppConstants.spacingMd,
        right: AppConstants.spacingMd,
        bottom: AppConstants.navBarHeight + 120,
      ),
      itemCount: rows.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return _buildLoadMoreIndicator();
        }
        final row = rows[index];
        if (row.isHeader) {
          return _buildSectionHeader(row.title!, row.count);
        }
        final song = row.song!;
        return _RecentlyAddedTile(
          key: ValueKey(
            'recently_added_${song.id}_${song.dateAdded?.millisecondsSinceEpoch ?? 0}',
          ),
          song: song,
          onTap: () async {
            await _playerService.play(song, playlist: _songs);
            if (context.mounted) {
              await NavigationHelper.navigateToFullPlayer(
                context,
                heroTag: 'recently_added_${song.id}',
              );
            }
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$count ${count == 1 ? 'song' : 'songs'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingLg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.adaptiveTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _RecentlyAddedTile extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _RecentlyAddedTile({super.key, required this.song, required this.onTap});

  @override
  State<_RecentlyAddedTile> createState() => _RecentlyAddedTileState();
}

class _RecentlyAddedTileState extends State<_RecentlyAddedTile>
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
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(time);
  }

  String _formatDate(DateTime time) {
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
    return '${time.day} ${months[time.month - 1]} ${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final artSize = context.scaleSize(56);
    final artworkTargetSize = (artSize * devicePixelRatio).round();
    final addedAt = widget.song.dateAdded;

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
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  child: Row(
                    children: [
                      Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          child: CachedImageWidget(
                            imagePath: widget.song.albumArt,
                            audioSourcePath: widget.song.filePath,
                            fit: BoxFit.cover,
                            useThumbnail: true,
                            thumbnailWidth: artworkTargetSize,
                            thumbnailHeight: artworkTargetSize,
                            placeholder: _buildPlaceholder(context),
                            errorWidget: _buildPlaceholder(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: context.adaptiveTextPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppConstants.spacingXxs),
                            Text(
                              widget.song.artist,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.adaptiveTextTertiary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppConstants.spacingXs),
                            Row(
                              children: [
                                _MetadataChip(text: widget.song.fileType),
                                if (widget.song.resolution != null &&
                                    widget.song.resolution != 'Unknown') ...[
                                  const SizedBox(width: AppConstants.spacingXs),
                                  _MetadataChip(text: widget.song.resolution!),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      if (addedAt != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: context.responsiveIcon(
                                    AppConstants.iconSizeXs,
                                  ),
                                  color: context.adaptiveTextTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(addedAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.adaptiveTextSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingXxs),
                            Text(
                              _formatDate(addedAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.adaptiveTextTertiary,
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
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        LucideIcons.music,
        size: context.responsiveIcon(AppConstants.iconSizeLg),
        color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final String text;

  const _MetadataChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: AppConstants.fontSizeXs,
          color: context.adaptiveTextTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RecentlyAddedRow {
  const _RecentlyAddedRow.header(this.title, this.count) : song = null;
  const _RecentlyAddedRow.song(this.song)
      : title = null,
        count = 0;

  final String? title;
  final int count;
  final Song? song;
  bool get isHeader => song == null;
}
