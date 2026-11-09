import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/songs/widgets/orbit_scroll.dart';
import 'package:flick/l10n/settings_l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/services/app_preferences_service.dart';

/// Live, browse-only preview of the orbit settings.
///
/// The preview paints the library header above the orbit so the top boundary
/// is visible while the controls below change. Tapping cards only moves the
/// preview's focus; it never starts playback or changes the queue.
class OrbitPreview extends ConsumerStatefulWidget {
  const OrbitPreview({super.key, required this.landscape});

  final bool landscape;

  @override
  ConsumerState<OrbitPreview> createState() => _OrbitPreviewState();
}

class _OrbitPreviewState extends ConsumerState<OrbitPreview> {
  bool? _expanded;
  int _selectedIndex = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded ??= MediaQuery.sizeOf(context).height >= 620;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded ?? false;
    final prefs = ref.watch(appPreferencesProvider);
    final songs = expanded ? _songs(ref) : const <Song>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        0,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
      ),
      child: SettingsCard(
        children: [
          _PreviewHeader(
            landscape: widget.landscape,
            expanded: expanded,
            onToggle: () {
              setState(() => _expanded = !expanded);
            },
            onFullscreen: expanded
                ? () => _openFullscreen(
                    context,
                    prefs: prefs,
                    songs: songs,
                    selectedIndex: _effectiveIndex(songs.length),
                  )
                : null,
          ),
          AnimatedSize(
            duration: AppConstants.animationNormal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _ExpandedPreview(
                    landscape: widget.landscape,
                    prefs: prefs,
                    songs: songs,
                    selectedIndex: _effectiveIndex(songs.length),
                    onSelectedIndexChanged: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  List<Song> _songs(WidgetRef ref) {
    final librarySongs = ref.watch(songsProvider).value?.sortedSongs;
    if (librarySongs != null && librarySongs.length >= 5) {
      return librarySongs.take(40).toList(growable: false);
    }
    return _demoSongs();
  }

  int _effectiveIndex(int songCount) {
    if (songCount == 0) return 0;
    if (_selectedIndex < 0) return songCount ~/ 2;
    return _selectedIndex.clamp(0, songCount - 1);
  }

  List<Song> _demoSongs() {
    return List.generate(9, (index) {
      final number = index + 1;
      return Song(
        id: 'orbit-preview-$number',
        title: '${l10n.preview} $number',
        artist: l10n.flickPreview,
        album: l10n.flickPreview,
        albumArtist: l10n.flickPreview,
        duration: const Duration(minutes: 3, seconds: 30),
        fileType: 'FLAC',
        trackNumber: number,
        year: 2026,
      );
    });
  }

  void _openFullscreen(
    BuildContext context, {
    required AppPreferences prefs,
    required List<Song> songs,
    required int selectedIndex,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: AppConstants.animationNormal,
        reverseTransitionDuration: AppConstants.animationNormal,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenOrbitPreview(
            landscape: widget.landscape,
            prefs: prefs,
            songs: songs,
            selectedIndex: selectedIndex,
            onSelectedIndexChanged: (index) {
              if (mounted) {
                setState(() => _selectedIndex = index);
              }
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.landscape,
    required this.expanded,
    required this.onToggle,
    this.onFullscreen,
  });

  final bool landscape;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.orbit, size: 18, color: AppColors.accent),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              l10n.livePreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message: landscape ? l10n.landscape : l10n.portrait,
            child: Icon(
              landscape
                  ? LucideIcons.rectangleHorizontal
                  : LucideIcons.rectangleVertical,
              size: 16,
              color: context.adaptiveTextTertiary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingXxs),
          if (onFullscreen != null)
            IconButton(
              key: const Key('orbit_preview_fullscreen_button'),
              tooltip: l10n.fullscreen,
              onPressed: onFullscreen,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              icon: Icon(
                LucideIcons.maximize2,
                size: 18,
                color: context.adaptiveTextSecondary,
              ),
            ),
          IconButton(
            key: const Key('orbit_preview_toggle'),
            tooltip: expanded ? l10n.orbitPreviewHide : l10n.orbitPreviewShow,
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: Icon(
              expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 20,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedPreview extends StatelessWidget {
  const _ExpandedPreview({
    required this.landscape,
    required this.prefs,
    required this.songs,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final bool landscape;
  final AppPreferences prefs;
  final List<Song> songs;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
          ),
          child: SizedBox(
            key: const Key('orbit_preview'),
            height: _previewHeight(context),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: _VirtualLibraryPreview(
                  landscape: landscape,
                  prefs: prefs,
                  songs: songs,
                  selectedIndex: selectedIndex,
                  onSelectedIndexChanged: onSelectedIndexChanged,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingSm,
            AppConstants.spacingLg,
            AppConstants.spacingMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.hand,
                size: 14,
                color: context.adaptiveTextTertiary,
              ),
              const SizedBox(width: AppConstants.spacingXs),
              Expanded(
                child: Text(
                  l10n.orbitPreviewHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _previewHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final minHeight = landscape ? 120.0 : 180.0;
    final maxHeight = math.min(340.0, math.max(minHeight, screenHeight - 360));
    final target = screenHeight * (landscape ? 0.42 : 0.36);
    return target.clamp(minHeight, maxHeight);
  }
}

class _VirtualLibraryPreview extends StatelessWidget {
  const _VirtualLibraryPreview({
    required this.landscape,
    required this.prefs,
    required this.songs,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final bool landscape;
  final AppPreferences prefs;
  final List<Song> songs;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  @override
  Widget build(BuildContext context) {
    final size = landscape ? const Size(844, 360) : const Size(411, 560);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.glassBorderStrong, width: 2),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              devicePixelRatio: 1,
              // The preview is already scaled down by the surrounding
              // FittedBox. Keep the miniature library at its base text metrics
              // so its narrow cards do not overflow; the real settings chrome
              // around it still honors the user's text scale.
              textScaler: TextScaler.noScaling,
            ),
            child: Column(
              children: [
                _PreviewLibraryHeader(
                  songCount: songs.length,
                  compact: landscape,
                ),
                Expanded(
                  child: _PreviewOrbit(
                    landscape: landscape,
                    prefs: prefs,
                    songs: songs,
                    selectedIndex: selectedIndex,
                    onSelectedIndexChanged: onSelectedIndexChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewOrbit extends StatelessWidget {
  const _PreviewOrbit({
    required this.landscape,
    required this.prefs,
    required this.songs,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final bool landscape;
  final AppPreferences prefs;
  final List<Song> songs;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  @override
  Widget build(BuildContext context) {
    return OrbitScroll(
      songs: songs,
      selectedIndex: selectedIndex,
      scrollDirection: landscape ? Axis.horizontal : Axis.vertical,
      radiusRatio: landscape
          ? prefs.orbitLandscapeRadiusRatio
          : prefs.orbitRadiusRatio,
      centerOffsetRatio: prefs.orbitCenterOffsetRatio,
      centerYRatio: landscape
          ? prefs.orbitLandscapeCenterYRatio
          : prefs.orbitCenterYRatio,
      itemSpacing: landscape
          ? prefs.orbitLandscapeItemSpacing
          : prefs.orbitItemSpacing,
      selectedScale: landscape
          ? prefs.orbitLandscapeSelectedScale
          : prefs.orbitSelectedScale,
      depth: landscape ? prefs.orbitLandscapeDepth : prefs.orbitDepth,
      visibleItems: landscape
          ? prefs.orbitLandscapeVisibleItems
          : prefs.orbitVisibleItems,
      cardArtSize: prefs.orbitCardArtSize,
      cardWidthRatio: landscape
          ? prefs.orbitLandscapeCardWidthRatio
          : prefs.orbitCardWidthRatio,
      artResolutionMultiplier: prefs.orbitArtResolutionMultiplier,
      showPath: prefs.orbitShowPath,
      showGlow: prefs.orbitShowGlow,
      swipeActionsEnabled: false,
      isSelectionMode: false,
      onSelectedIndexChanged: onSelectedIndexChanged,
      onSongSelected: onSelectedIndexChanged,
    );
  }
}

class _FullScreenOrbitPreview extends StatefulWidget {
  const _FullScreenOrbitPreview({
    required this.landscape,
    required this.prefs,
    required this.songs,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final bool landscape;
  final AppPreferences prefs;
  final List<Song> songs;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  @override
  State<_FullScreenOrbitPreview> createState() =>
      _FullScreenOrbitPreviewState();
}

class _FullScreenOrbitPreviewState extends State<_FullScreenOrbitPreview> {
  late int _selectedIndex = widget.selectedIndex;

  void _select(int index) {
    setState(() => _selectedIndex = index);
    widget.onSelectedIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _FullScreenPreviewHeader(landscape: widget.landscape),
              _PreviewLibraryHeader(
                songCount: widget.songs.length,
                compact: MediaQuery.sizeOf(context).height < 500,
              ),
              Expanded(
                child: SizedBox.expand(
                  key: const Key('orbit_preview_fullscreen'),
                  child: _PreviewOrbit(
                    landscape: widget.landscape,
                    prefs: widget.prefs,
                    songs: widget.songs,
                    selectedIndex: _selectedIndex,
                    onSelectedIndexChanged: _select,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenPreviewHeader extends StatelessWidget {
  const _FullScreenPreviewHeader({required this.landscape});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
        AppConstants.spacingXxs,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.orbit, size: 18, color: AppColors.accent),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              l10n.livePreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message: landscape ? l10n.landscape : l10n.portrait,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingXs,
                vertical: AppConstants.spacingXxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    landscape
                        ? LucideIcons.rectangleHorizontal
                        : LucideIcons.rectangleVertical,
                    size: 14,
                    color: context.adaptiveTextTertiary,
                  ),
                  const SizedBox(width: AppConstants.spacingXxs),
                  Text(
                    landscape ? l10n.landscape : l10n.portrait,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingXs),
          IconButton(
            key: const Key('orbit_preview_close'),
            tooltip: l10n.closePreview,
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: Icon(
              LucideIcons.x,
              size: 20,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLibraryHeader extends StatelessWidget {
  const _PreviewLibraryHeader({required this.songCount, required this.compact});

  final int songCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 16.0 : 20.0;
    final buttonSize = compact ? 28.0 : 34.0;
    final iconSize = compact ? 15.0 : 17.0;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                compact ? 10 : 14,
                horizontalPadding,
                compact ? 6 : 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.yourLibrary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.adaptiveTextPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.songs2(songCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.adaptiveTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  _PreviewHeaderButton(
                    icon: LucideIcons.checkCheck,
                    size: buttonSize,
                    iconSize: iconSize,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  _PreviewHeaderButton(
                    icon: LucideIcons.shuffle,
                    size: buttonSize,
                    iconSize: iconSize,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  _PreviewHeaderButton(
                    icon: Icons.sort_rounded,
                    size: buttonSize,
                    iconSize: iconSize,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                compact ? 8 : 12,
              ),
              child: Container(
                height: compact ? 38 : 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.search,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Expanded(
                      child: Text(
                        l10n.searchSongsArtists,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewHeaderButton extends StatelessWidget {
  const _PreviewHeaderButton({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Icon(icon, size: iconSize, color: AppColors.textSecondary),
    );
  }
}
