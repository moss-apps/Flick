import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/common/glass_dialog.dart';

/// Number of history entries fetched per page.
const int _kPageSize = 50;

/// Pixels from the bottom of the list that trigger the next page load.
const double _kLoadMoreThreshold = 300;

/// Recently Played screen with a grouped list layout and paginated loading.
class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  final PlayerService _playerService = PlayerService();
  final RecentlyPlayedRepository _recentlyPlayedRepository =
      RecentlyPlayedRepository();
  final ScrollController _scrollController = ScrollController();

  List<RecentlyPlayedEntry> _entries = [];
  Map<String, List<RecentlyPlayedEntry>> _groupedHistory = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  StreamSubscription<void>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Defer data loading to avoid jank during navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialHistory();
      _watchHistory();
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _watchHistory() {
    _historySubscription = _recentlyPlayedRepository.watchHistory().listen((_) {
      _resetPagination();
      _loadInitialHistory();
    });
  }

  Future<void> _loadInitialHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasMore = true;
    });

    try {
      final count = await _recentlyPlayedRepository.getHistoryCount();
      final entries = await _recentlyPlayedRepository.getRecentHistoryPaginated(
        offset: 0,
        limit: _kPageSize,
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _groupedHistory = _groupEntries(entries);
          _totalCount = count;
          _hasMore = entries.length < count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _entries = [];
          _groupedHistory = {};
          _totalCount = 0;
          _hasMore = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (!mounted || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextEntries = await _recentlyPlayedRepository
          .getRecentHistoryPaginated(
            offset: _entries.length,
            limit: _kPageSize,
          );
      if (mounted) {
        setState(() {
          _entries.addAll(nextEntries);
          _groupedHistory = _groupEntries(_entries);
          _hasMore = _entries.length < _totalCount;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _resetPagination() {
    _entries = [];
    _groupedHistory = {};
    _hasMore = true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _kLoadMoreThreshold) {
      _loadMoreHistory();
    }
  }

  Map<String, List<RecentlyPlayedEntry>> _groupEntries(
    List<RecentlyPlayedEntry> entries,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    final grouped = <String, List<RecentlyPlayedEntry>>{};

    for (final entry in entries) {
      final playedDate = DateTime(
        entry.playedAt.year,
        entry.playedAt.month,
        entry.playedAt.day,
      );

      final String groupKey;
      if (playedDate == today) {
        groupKey = 'Today';
      } else if (playedDate == yesterday) {
        groupKey = 'Yesterday';
      } else if (playedDate.isAfter(thisWeekStart) ||
          playedDate == thisWeekStart) {
        groupKey = 'This Week';
      } else if (playedDate.isAfter(lastWeekStart) ||
          playedDate == lastWeekStart) {
        groupKey = 'Last Week';
      } else if (playedDate.isAfter(thisMonthStart) ||
          playedDate == thisMonthStart) {
        groupKey = 'This Month';
      } else {
        groupKey = 'Earlier';
      }

      grouped.putIfAbsent(groupKey, () => []).add(entry);
    }

    return grouped;
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: 'Clear History',
        content: const Text(
          'Are you sure you want to clear your entire listening history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _recentlyPlayedRepository.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('History cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DisplayModeWrapper(
      child: Scaffold(
        // Opaque background improves compositor performance (no need to blend
        // everything with what's behind this route during scroll).
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _groupedHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
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
                  'Recently Played',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Text(
                  '$_totalCount ${_totalCount == 1 ? 'song' : 'songs'} played',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (_groupedHistory.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  color: context.adaptiveTextSecondary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                onPressed: _clearHistory,
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
            // Timeline illustration
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Timeline line
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
                  // Center icon
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
                      LucideIcons.clock,
                      size: context.responsiveIcon(AppConstants.iconSizeXl),
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'No History Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Songs you play will appear here',
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

  Widget _buildHistoryList() {
    const sectionOrder = [
      'Today',
      'Yesterday',
      'This Week',
      'Last Week',
      'This Month',
      'Earlier',
    ];

    final sortedSections = _groupedHistory.entries.toList()
      ..sort((a, b) {
        final aIndex = sectionOrder.indexOf(a.key);
        final bIndex = sectionOrder.indexOf(b.key);
        return aIndex.compareTo(bIndex);
      });

    final rows = <_RecentlyPlayedRow>[];
    for (final section in sortedSections) {
      rows.add(_RecentlyPlayedRow.header(section.key, section.value.length));
      for (final entry in section.value) {
        rows.add(_RecentlyPlayedRow.entry(entry));
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
        final entry = row.entry!;
        return _RecentlyPlayedTile(
          key: ValueKey(
            'recent_${entry.song.id}_${entry.playedAt.millisecondsSinceEpoch}',
          ),
          song: entry.song,
          playedAt: entry.playedAt,
          onTap: () async {
            await _playerService.play(
              entry.song,
              playlist: _entries.map((e) => e.song).toList(),
            );
            if (context.mounted) {
              await NavigationHelper.navigateToFullPlayer(
                context,
                heroTag: 'recent_song_${entry.song.id}',
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

class _RecentlyPlayedTile extends StatefulWidget {
  final Song song;
  final DateTime playedAt;
  final VoidCallback onTap;

  const _RecentlyPlayedTile({
    super.key,
    required this.song,
    required this.playedAt,
    required this.onTap,
  });

  @override
  State<_RecentlyPlayedTile> createState() => _RecentlyPlayedTileState();
}

class _RecentlyPlayedTileState extends State<_RecentlyPlayedTile>
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
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.day.toString().padLeft(2, '0')}/'
          '${time.month.toString().padLeft(2, '0')}/'
          '${time.year}';
    }
  }

  String _formatTimestamp(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final artSize = context.scaleSize(56);
    final artworkTargetSize = (artSize * devicePixelRatio).round();

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: context.responsiveIcon(
                                  AppConstants.iconSizeXs,
                                ),
                                color: context.adaptiveTextTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(widget.playedAt),
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
                            _formatTimestamp(widget.playedAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.adaptiveTextTertiary),
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

class _RecentlyPlayedRow {
  const _RecentlyPlayedRow.header(this.title, this.count) : entry = null;
  const _RecentlyPlayedRow.entry(this.entry)
      : title = null,
        count = 0;

  final String? title;
  final int count;
  final RecentlyPlayedEntry? entry;
  bool get isHeader => entry == null;
}
