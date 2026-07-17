import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/blurred_song_background.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedKeys = {};

  String _upNextKey(int i) => 'upnext-$i';
  String _queueKey(int i) => 'queue-$i';

  void _enterSelectionMode(String? key) {
    setState(() {
      _selectionMode = true;
      if (key != null) _selectedKeys.add(key);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
        if (_selectedKeys.isEmpty) _selectionMode = false;
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _selectAll() {
    final upNext = ref.read(upNextProvider);
    final queue = ref.read(queueProvider);
    setState(() {
      for (int i = 0; i < upNext.length; i++) {
        _selectedKeys.add(_upNextKey(i));
      }
      for (int i = 0; i < queue.length; i++) {
        _selectedKeys.add(_queueKey(i));
      }
    });
  }

  Future<void> _removeSelected() async {
    final upNextIndices = <int>[];
    final queueIndices = <int>[];
    for (final key in _selectedKeys) {
      if (key.startsWith('upnext-')) {
        upNextIndices.add(int.parse(key.substring(7)));
      } else if (key.startsWith('queue-')) {
        queueIndices.add(int.parse(key.substring(6)));
      }
    }
    setState(() {
      _selectedKeys.clear();
      _selectionMode = false;
    });
    // Remove in reverse order to keep indices stable
    upNextIndices.sort((a, b) => b.compareTo(a));
    queueIndices.sort((a, b) => b.compareTo(a));
    for (final i in queueIndices) {
      await ref.read(playerProvider.notifier).removeFromQueue(i);
    }
    for (final i in upNextIndices) {
      await ref.read(playerProvider.notifier).removeFromUpNext(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider);
    final upNext = ref.watch(upNextProvider);
    final currentSong = ref.watch(currentSongProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlurredSongBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            if (_selectionMode)
              _buildSelectionHeader(upNext.length + queue.length)
            else
              _Header(
                queueCount: upNext.length + queue.length,
                canClear: upNext.isNotEmpty || queue.isNotEmpty,
                onClear: () async {
                  await ref.read(playerProvider.notifier).clearAllUpcoming();
                },
                onSelectMode: () => _enterSelectionMode(null),
              ),
            Expanded(
              child: upNext.isEmpty && currentSong == null
                  ? const _EmptyQueue()
                  : CustomScrollView(
                      slivers: [
                        if (currentSong != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppConstants.spacingLg,
                                0,
                                AppConstants.spacingLg,
                                AppConstants.spacingMd,
                              ),
                              child: _NowPlayingCard(song: currentSong),
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
                            child: Text(
                              'Up next',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: context.adaptiveTextSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                        if (upNext.isEmpty)
                          const SliverToBoxAdapter(child: _EmptyUpcomingState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppConstants.spacingLg,
                              0,
                              AppConstants.spacingLg,
                              AppConstants.spacingLg,
                            ),
                            sliver: _selectionMode
                                ? SliverList.builder(
                                    itemCount: upNext.length,
                                    itemBuilder: (context, index) {
                                      final song = upNext[index];
                                      final key = _upNextKey(index);
                                      final isSelected =
                                          _selectedKeys.contains(key);
                                      return _UpcomingTile(
                                        song: song,
                                        index: index,
                                        isSelectionMode: true,
                                        isSelected: isSelected,
                                        onTap: () => _toggleSelection(key),
                                        onLongPress: () {},
                                      );
                                    },
                                  )
                                : SliverReorderableList(
                                    itemCount: upNext.length,
                                    onReorder: (oldIndex, newIndex) async {
                                      final targetIndex = newIndex > oldIndex
                                          ? newIndex - 1
                                          : newIndex;
                                      await ref
                                          .read(playerProvider.notifier)
                                          .moveUpNextItem(oldIndex, targetIndex);
                                    },
                                    itemBuilder: (context, index) {
                                      final song = upNext[index];
                                      return _UpcomingTile(
                                        key: ValueKey('upnext-${song.id}-$index'),
                                        song: song,
                                        index: index,
                                        onTap: () async {
                                          await ref
                                              .read(playerProvider.notifier)
                                              .playFromUpNextIndex(index);
                                        },
                                        onLongPress: () =>
                                            _enterSelectionMode(
                                                _upNextKey(index)),
                                        onRemove: () async {
                                          await ref
                                              .read(playerProvider.notifier)
                                              .removeFromUpNext(index);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        if (queue.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppConstants.spacingLg,
                                0,
                                AppConstants.spacingLg,
                                AppConstants.spacingSm,
                              ),
                              child: Text(
                                'Manual queue',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: context.adaptiveTextSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        if (queue.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppConstants.spacingLg,
                              0,
                              AppConstants.spacingLg,
                              AppConstants.navBarHeight + 120,
                            ),
                            sliver: _selectionMode
                                ? SliverList.builder(
                                    itemCount: queue.length,
                                    itemBuilder: (context, index) {
                                      final song = queue[index];
                                      final key = _queueKey(index);
                                      final isSelected =
                                          _selectedKeys.contains(key);
                                      return _QueueTile(
                                        key: ValueKey(
                                            'queue-sel-${song.id}-$index'),
                                        song: song,
                                        index: index,
                                        isSelectionMode: true,
                                        isSelected: isSelected,
                                        onTap: () =>
                                            _toggleSelection(key),
                                        onLongPress: () {},
                                        onRemove: () async {
                                          await ref
                                              .read(playerProvider.notifier)
                                              .removeFromQueue(index);
                                        },
                                        onMoveToNext: null,
                                      );
                                    },
                                  )
                                : SliverReorderableList(
                                    itemCount: queue.length,
                                    onReorder: (oldIndex, newIndex) async {
                                      final targetIndex = newIndex > oldIndex
                                          ? newIndex - 1
                                          : newIndex;
                                      await ref
                                          .read(playerProvider.notifier)
                                          .moveQueueItem(oldIndex, targetIndex);
                                    },
                                    itemBuilder: (context, index) {
                                      final song = queue[index];
                                      return _QueueTile(
                                        key: ValueKey('${song.id}-$index'),
                                        song: song,
                                        index: index,
                                        onTap: () async {
                                          await ref
                                              .read(playerProvider.notifier)
                                              .playFromQueueIndex(index);
                                        },
                                        onLongPress: () =>
                                            _enterSelectionMode(
                                                _queueKey(index)),
                                        onRemove: () async {
                                          await ref
                                              .read(playerProvider.notifier)
                                              .removeFromQueue(index);
                                        },
                                        onMoveToNext: index == 0
                                            ? null
                                            : () async {
                                                await ref
                                                    .read(playerProvider
                                                        .notifier)
                                                    .moveQueueItemToNext(
                                                        index);
                                              },
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSelectionHeader(int queueCount) {
    final upNext = ref.read(upNextProvider);
    final queue = ref.read(queueProvider);
    final count = _selectedKeys.length;
    final totalItems = upNext.length + queue.length;
    final allSelected = totalItems > 0 && count == totalItems;

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
                LucideIcons.x,
                color: context.adaptiveTextPrimary,
              ),
              onPressed: _exitSelectionMode,
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Queue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                ),
                Text(
                  '$count selected of $queueCount song${queueCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          if (!allSelected)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                'Select All',
                style: TextStyle(color: context.adaptiveTextSecondary),
              ),
            ),
          IconButton(
            icon: Icon(
              LucideIcons.trash2,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? _removeSelected : null,
            tooltip: 'Remove selected',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int queueCount;
  final bool canClear;
  final Future<void> Function() onClear;
  final VoidCallback onSelectMode;

  const _Header({
    required this.queueCount,
    required this.canClear,
    required this.onClear,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
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
                  'Queue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                ),
                Text(
                  '$queueCount upcoming song${queueCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(
                LucideIcons.checkCheck,
                color: context.adaptiveTextPrimary,
              ),
              tooltip: 'Select',
              onPressed: onSelectMode,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          if (canClear)
            TextButton(onPressed: onClear, child: const Text('Clear All')),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.listMusic,
              size: 52,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'Queue is empty',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Add songs from the player or song actions menu.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUpcomingState extends StatelessWidget {
  const _EmptyUpcomingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.sparkles,
              color: context.adaptiveTextTertiary,
              size: 20,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                'No upcoming queue items yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final Song song;

  const _NowPlayingCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.92),
            AppColors.surface.withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _Artwork(song: song),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now playing',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;
  final bool isSelectionMode;
  final bool isSelected;

  const _UpcomingTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.onLongPress,
    this.onRemove,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          onTap: onTap,
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
                colors: [
                  AppColors.surfaceLight.withValues(alpha: 0.7),
                  AppColors.surface.withValues(alpha: 0.82),
                ],
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected ? LucideIcons.check : LucideIcons.circle,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextTertiary,
                    size: 22,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                ] else
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.spacingSm,
                      ),
                      child: Icon(
                        LucideIcons.gripVertical,
                        color: context.adaptiveTextTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                _Artwork(song: song),
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
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode)
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
      ),
    );

    if (isSelectionMode || onRemove == null) return tile;

    return Dismissible(
      key: ValueKey('upnext-dismiss-$index-${song.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          color: Colors.redAccent.withValues(alpha: 0.18),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(LucideIcons.trash2, color: Colors.redAccent),
      ),
      onDismissed: (_) => onRemove!(),
      child: tile,
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  final VoidCallback? onMoveToNext;
  final bool isSelectionMode;
  final bool isSelected;

  const _QueueTile({
    required super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.onLongPress = _noop,
    required this.onRemove,
    required this.onMoveToNext,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          onTap: onTap,
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
                colors: [
                  AppColors.surfaceLight.withValues(alpha: 0.7),
                  AppColors.surface.withValues(alpha: 0.82),
                ],
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected ? LucideIcons.check : LucideIcons.circle,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextTertiary,
                    size: 22,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                ] else
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.spacingSm,
                      ),
                      child: Icon(
                        LucideIcons.gripVertical,
                        color: context.adaptiveTextTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                _Artwork(song: song),
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
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode)
                  PopupMenuButton<_QueueAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _QueueAction.playNext:
                          onMoveToNext?.call();
                          break;
                        case _QueueAction.remove:
                          onRemove();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onMoveToNext != null)
                        const PopupMenuItem(
                          value: _QueueAction.playNext,
                          child: Text('Play next'),
                        ),
                      const PopupMenuItem(
                        value: _QueueAction.remove,
                        child: Text('Remove'),
                      ),
                    ],
                    icon: Icon(
                      LucideIcons.ellipsisVertical,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isSelectionMode) return tile;

    return Dismissible(
      key: ValueKey('queue-dismiss-$index-${song.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          color: Colors.redAccent.withValues(alpha: 0.18),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(LucideIcons.trash2, color: Colors.redAccent),
      ),
      onDismissed: (_) => onRemove(),
      child: tile,
    );
  }
}

class _Artwork extends StatelessWidget {
  final Song song;

  const _Artwork({required this.song});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
    );
  }
}

enum _QueueAction { playNext, remove }
