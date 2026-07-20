import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/artists/screens/artist_detail_screen.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/blurred_song_background.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/common/glass_search_bar.dart';

enum ArtistSortOption { name, songs, albums }

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final SongRepository _songRepository = SongRepository();
  final PlayerService _playerService = PlayerService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, List<Song>> _artists = {};
  List<MapEntry<String, List<Song>>> _sortedArtists = [];
  String _searchQuery = '';
  bool _isLoading = true;
  ArtistSortOption _sortOption = ArtistSortOption.name;
  bool _visibilitySet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSortOption();
      _loadArtists();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('artists_sort_option');
    if (!mounted) return;
    final option = ArtistSortOption.values.firstWhere(
      (v) => v.name == value,
      orElse: () => ArtistSortOption.name,
    );
    if (option != _sortOption) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _setSortOption(ArtistSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('artists_sort_option', option.name);
    if (mounted) {
      setState(() {
        _sortOption = option;
        _applySorting();
      });
    }
  }

  Future<void> _loadArtists() async {
    final artists = await _songRepository.getSongsByArtist();
    if (mounted) {
      setState(() {
        _artists = artists;
        _sortedArtists = artists.entries.toList();
        _applySorting();
        _isLoading = false;
      });
    }
  }

  void _applySorting() {
    switch (_sortOption) {
      case ArtistSortOption.name:
        _sortedArtists.sort((a, b) => a.key.compareTo(b.key));
      case ArtistSortOption.songs:
        _sortedArtists.sort(
          (a, b) => b.value.length.compareTo(a.value.length),
        );
      case ArtistSortOption.albums:
        _sortedArtists.sort((a, b) {
          final aAlbums =
              a.value.map((s) => s.album ?? 'Unknown').toSet().length;
          final bAlbums =
              b.value.map((s) => s.album ?? 'Unknown').toSet().length;
          return bAlbums.compareTo(aAlbums);
        });
    }
  }

  List<MapEntry<String, List<Song>>> get _filteredArtists {
    if (_searchQuery.isEmpty) return _sortedArtists;
    return _sortedArtists
        .where((e) => e.key.toLowerCase().contains(_searchQuery))
        .toList();
  }

  int get _totalSongs =>
      _artists.values.fold(0, (count, songs) => count + songs.length);

  int get _totalAlbums => _artists.values
      .expand((songs) => songs.map((s) => s.album ?? 'Unknown'))
      .toSet()
      .length;

  String? _getArtistArt(List<Song> songs) {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }

  String? _getArtworkSourcePath(List<Song> songs) {
    for (final song in songs) {
      final filePath = song.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        return filePath;
      }
    }
    return null;
  }

  String _getArtistInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArtistSortSheet(
        currentOption: _sortOption,
        onSelected: (option) {
          _setSortOption(option);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openArtistDetail(String artistName, List<Song> songs) {
    NavigationHelper.pushFade(
      context,
      (_) => ArtistDetailScreen(
        artistName: artistName,
        songs: songs,
        artistArt: _getArtistArt(songs),
        artistArtSourcePath: _getArtworkSourcePath(songs),
        playerService: _playerService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visibilitySet) {
      _visibilitySet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ProviderScope.containerOf(context)
              .read(navBarVisibleProvider.notifier)
              .setVisible(true);
        }
      });
    }
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
                      : _artists.isEmpty
                      ? _buildEmptyState()
                      : _buildArtistsList(),
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
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Artists',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.adaptiveTextPrimary,
                          ),
                    ),
                    Text(
                      '${_artists.length} artists',
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
                    Icons.sort_rounded,
                    color: context.adaptiveTextPrimary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                  onPressed: _showSortSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceLight.withValues(alpha: 0.75),
                  AppColors.surface.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GlassSearchBar(
              controller: _searchController,
              hintText: 'Search artists...',
              showBackground: false,
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          if (!ref.watch(appPreferencesProvider).glanceCardHidden)
            GestureDetector(
              onTap: () {
                ref
                    .read(appPreferencesProvider.notifier)
                    .setGlanceCardMinimized(
                      !ref.read(appPreferencesProvider).glanceCardMinimized,
                    );
              },
              child: AnimatedCrossFade(
                firstChild: _buildGlanceCard(context, expanded: true),
                secondChild: _buildGlanceCard(context, expanded: false),
                crossFadeState: ref
                        .watch(appPreferencesProvider)
                        .glanceCardMinimized
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppConstants.animationNormal,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlanceCard(BuildContext context, {required bool expanded}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        expanded ? AppConstants.spacingLg : AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.86),
            AppColors.surface.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your library at a glance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronUp,
                      color: context.adaptiveTextSecondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  'Browse your artists, explore their discographies, and play their tracks.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Wrap(
                  spacing: AppConstants.spacingSm,
                  runSpacing: AppConstants.spacingSm,
                  children: [
                    _buildInfoChip(
                      context,
                      icon: LucideIcons.mic,
                      label: '${_artists.length} artists',
                    ),
                    _buildInfoChip(
                      context,
                      icon: LucideIcons.music4,
                      label: '$_totalSongs songs',
                    ),
                    _buildInfoChip(
                      context,
                      icon: LucideIcons.disc3,
                      label: '$_totalAlbums albums',
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your library at a glance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  LucideIcons.chevronDown,
                  color: context.adaptiveTextSecondary,
                  size: 20,
                ),
              ],
            ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
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
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.users,
            size: context.responsiveIcon(AppConstants.containerSizeLg),
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'No Artists Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Add music with artist tags to see them here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsList() {
    final filtered = _filteredArtists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            0,
            AppConstants.spacingLg,
            AppConstants.spacingMd,
          ),
          child: Text(
            _searchQuery.isNotEmpty
                ? 'Results (${filtered.length})'
                : 'All Artists',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.searchX,
                        size: context.responsiveIcon(48),
                        color: context.adaptiveTextTertiary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      Text(
                        'No artists match "$_searchQuery"',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: AppConstants.navBarHeight + 120,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _ArtistCard(
                      artistName: entry.key,
                      songs: entry.value,
                      artistArt: _getArtistArt(entry.value),
                      artistArtSourcePath: _getArtworkSourcePath(entry.value),
                      initials: _getArtistInitials(entry.key),
                      onTap: () => _openArtistDetail(entry.key, entry.value),
                    );
                  },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ArtistCard extends StatefulWidget {
  final String artistName;
  final List<Song> songs;
  final String? artistArt;
  final String? artistArtSourcePath;
  final String initials;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.artistName,
    required this.songs,
    required this.artistArt,
    required this.artistArtSourcePath,
    required this.initials,
    required this.onTap,
  });

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard>
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
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uniqueAlbums =
        widget.songs.map((s) => s.album ?? 'Unknown').toSet().length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: InkWell(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  Container(
                    width: context.scaleSize(56),
                    height: context.scaleSize(56),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight,
                      border: Border.all(
                        color: AppColors.surfaceDark,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: CachedImageWidget(
                        imagePath: widget.artistArt,
                        audioSourcePath: widget.artistArtSourcePath,
                        fit: BoxFit.cover,
                        placeholder: _buildInitials(context),
                        errorWidget: _buildInitials(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.artistName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: context.adaptiveTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.songs.length} songs \u2022 $uniqueAlbums albums',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.adaptiveTextTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    color: context.adaptiveTextTertiary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitials(BuildContext context) {
    return Center(
      child: Text(
        widget.initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: context.adaptiveTextSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ArtistSortSheet extends StatelessWidget {
  final ArtistSortOption currentOption;
  final ValueChanged<ArtistSortOption> onSelected;

  const _ArtistSortSheet({
    required this.currentOption,
    required this.onSelected,
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
              ...ArtistSortOption.values.map(
                (option) => _buildSortTile(context, option),
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

  Widget _buildSortTile(BuildContext context, ArtistSortOption option) {
    final isSelected = currentOption == option;
    final icon = _iconFor(option);
    final label = _labelFor(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(option),
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

  IconData _iconFor(ArtistSortOption option) {
    switch (option) {
      case ArtistSortOption.name:
        return LucideIcons.type;
      case ArtistSortOption.songs:
        return LucideIcons.music4;
      case ArtistSortOption.albums:
        return LucideIcons.disc3;
    }
  }

  String _labelFor(ArtistSortOption option) {
    switch (option) {
      case ArtistSortOption.name:
        return 'Artist Name';
      case ArtistSortOption.songs:
        return 'Song Count';
      case ArtistSortOption.albums:
        return 'Album Count';
    }
  }
}
