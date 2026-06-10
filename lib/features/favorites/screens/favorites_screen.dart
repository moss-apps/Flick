import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/providers/providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final PlayerService _playerService = PlayerService();
  final FavoritesService _favoritesService = FavoritesService();

  List<Song> _favorites = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final navBarNotifier = ref.read(navBarVisibleProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navBarNotifier.setVisible(true);
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(Song song) async {
    setState(() {
      _favorites.remove(song);
    });

    await _favoritesService.removeFavorite(song.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}" from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _favoritesService.addFavorite(song.id);
              setState(() {
                _favorites.add(song);
              });
            },
          ),
        ),
      );
    }
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

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_favorites.map((s) => s.id));
    });
  }

  Future<void> _removeSelected() async {
    final toRemove =
        _favorites.where((s) => _selectedIds.contains(s.id)).toList();
    final removedIds = toRemove.map((s) => s.id).toSet();
    final removedSongs = List<Song>.from(toRemove);

    setState(() {
      _favorites.removeWhere((s) => removedIds.contains(s.id));
      _selectedIds.clear();
      _selectionMode = false;
    });

    for (final id in removedIds) {
      await _favoritesService.removeFavorite(id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${removedSongs.length} from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final song in removedSongs) {
                await _favoritesService.addFavorite(song.id);
              }
              setState(() {
                _favorites = [..._favorites, ...removedSongs];
              });
            },
          ),
        ),
      );
    }
  }

  void _showLongPressSheet(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXl),
          ),
        ),
        padding: const EdgeInsets.only(
          bottom: AppConstants.spacingLg,
          top: AppConstants.spacingSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            ListTile(
              leading: const Icon(LucideIcons.heartOff, color: Colors.red),
              title: const Text('Unfavorite'),
              onTap: () {
                Navigator.of(context).pop();
                _removeFavorite(song);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.checkCheck,
                  color: context.adaptiveTextSecondary),
              title: const Text('Select'),
              onTap: () {
                Navigator.of(context).pop();
                _enterSelectionMode(song.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final removalMode =
        ref.watch(appPreferencesProvider).favoriteRemovalMode;

    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectionMode)
                _buildSelectionHeader(context)
              else
                _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _favorites.isEmpty
                        ? _buildEmptyState()
                        : _buildFavoritesList(removalMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final count = _selectedIds.length;
    final allSelected = count == _favorites.length;

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
              onPressed: _selectAll,
              child: Text(
                'Select All',
                style: TextStyle(color: context.adaptiveTextSecondary),
              ),
            ),
          IconButton(
            icon: Icon(
              LucideIcons.heartOff,
              color: Colors.red.withValues(alpha: 0.8),
            ),
            onPressed: count > 0 ? _removeSelected : null,
            tooltip: 'Unfavorite selected',
          ),
        ],
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
                  'Favorites',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                ),
                Text(
                  '${_favorites.length} liked songs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          if (_favorites.isNotEmpty) ...[
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
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                tooltip: 'Select',
                onPressed: () => _enterSelectionMode(null),
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
                  LucideIcons.shuffle,
                  color: context.adaptiveTextPrimary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                onPressed: () {
                  final shuffled = List<Song>.from(_favorites)..shuffle();
                  _playerService.play(shuffled.first, playlist: shuffled);
                },
              ),
            ),
          ],
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
            _HeartIllustration(),
            const SizedBox(height: AppConstants.spacingXl),
            Text(
              'No Favorites Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Tap the heart icon on any song\nto add it to your favorites',
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

  Widget _buildFavoritesList(String removalMode) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: AppConstants.navBarHeight + 120),
        itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final song = _favorites[index];
        final isSelected = _selectedIds.contains(song.id);
        return _FavoriteSongTile(
          key: ValueKey(song.id),
          song: song,
          isSelectionMode: _selectionMode,
          isSelected: isSelected,
          removalMode: removalMode,
          onTap: () async {
            if (_selectionMode) {
              _toggleSelection(song.id);
              return;
            }
            await _playerService.play(song, playlist: _favorites);
            if (context.mounted) {
              await NavigationHelper.navigateToFullPlayer(
                context,
                heroTag: 'favorite_song_${song.id}',
              );
            }
          },
          onLongPress: () {
            if (_selectionMode) return;
            if (removalMode == 'longpress') {
              _showLongPressSheet(song);
            } else {
              _enterSelectionMode(song.id);
            }
          },
          onRemove: () => _removeFavorite(song),
        );
      },
      ),
    );
  }
}

class _HeartIllustration extends StatefulWidget {
  @override
  State<_HeartIllustration> createState() => _HeartIllustrationState();
}

class _HeartIllustrationState extends State<_HeartIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.surfaceDark, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.2),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 5 * (_pulseAnimation.value - 1),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.heart,
              size: context.responsiveIcon(AppConstants.containerSizeMd),
              color: Colors.red.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteSongTile extends StatelessWidget {
  final Song song;
  final bool isSelectionMode;
  final bool isSelected;
  final String removalMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;

  const _FavoriteSongTile({
    super.key,
    required this.song,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.removalMode = 'swipe',
  });

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected
                      ? LucideIcons.check
                      : LucideIcons.circle,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextTertiary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                ],
                Container(
                  width: context.scaleSize(52),
                  height: context.scaleSize(52),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: CachedImageWidget(
                      imagePath: song.albumArt,
                      audioSourcePath: song.filePath,
                      fit: BoxFit.cover,
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
                        song.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                if (!isSelectionMode)
                  Icon(
                    LucideIcons.heart,
                    color: Colors.red.withValues(alpha: 0.8),
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isSelectionMode || removalMode != 'swipe') {
      return tile;
    }

    return Dismissible(
      key: Key(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppConstants.spacingLg),
        color: Colors.red.withValues(alpha: 0.3),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: tile,
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        LucideIcons.music,
        color: context.adaptiveTextTertiary,
        size: context.responsiveIcon(AppConstants.iconSizeLg),
      ),
    );
  }
}
