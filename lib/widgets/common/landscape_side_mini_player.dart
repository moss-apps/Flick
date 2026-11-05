import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/adaptive_layout.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/mini_player_config.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/mini_player_config_provider.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';

/// The compact landscape song orbit needs the stage height that the regular
/// horizontal mini player would otherwise take. This strip keeps the artwork,
/// play/pause and a vertical visualizer while moving the player to the side.
class LandscapeSideMiniPlayer extends ConsumerStatefulWidget {
  const LandscapeSideMiniPlayer({super.key});

  static const String heroTag = 'mini_player_art';

  @override
  ConsumerState<LandscapeSideMiniPlayer> createState() =>
      _LandscapeSideMiniPlayerState();
}

class _LandscapeSideMiniPlayerState
    extends ConsumerState<LandscapeSideMiniPlayer> {
  int _songChangeDirection = 0;

  void _next() {
    _songChangeDirection = 1;
    ref.read(playerProvider.notifier).next();
  }

  void _previous() {
    _songChangeDirection = -1;
    ref.read(playerProvider.notifier).previous(allowRestart: false);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() <= 300) return;
    if (velocity < 0) {
      _next();
    } else {
      _previous();
    }
  }

  Future<void> _openPlayer() async {
    final result = await NavigationHelper.navigateToFullPlayer(
      context,
      heroTag: LandscapeSideMiniPlayer.heroTag,
    );
    if (result != null && mounted) {
      ref.read(navigationIndexProvider.notifier).setIndex(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final prefs = ref.watch(appPreferencesProvider);
    final config = ref.watch(miniPlayerConfigProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final progress = ref.watch(progressProvider);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final radius = math.min(config.cornerRadius, 28.0);
    final duration = reducedMotion
        ? Duration.zero
        : AppConstants.animationNormal;
    final visualizerEnabled =
        prefs.visualizerEnabled && !MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      width: AdaptiveLayout.sideMiniPlayerWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight.withValues(
                  alpha: config.backgroundOpacity * (0.86 / 0.94),
                ),
                AppColors.surface.withValues(alpha: config.backgroundOpacity),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: _shadow(config),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: l10n.openPlayer,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openPlayer,
                            child: Column(
                              // The rotated painter has no intrinsic width;
                              // give it tight bounds on both axes.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (config.showArtwork)
                                  _buildArtwork(song, duration)
                                else
                                  const SizedBox(
                                    height: AppConstants.spacingXs,
                                  ),
                                const SizedBox(height: AppConstants.spacingXxs),
                                Expanded(
                                  child: _buildVisualizer(
                                    prefs: prefs,
                                    visualizerEnabled: visualizerEnabled,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        key: const ValueKey('side_mini_player_divider'),
                        height: 1,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingSm,
                        ),
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      SizedBox(
                        height: 52,
                        child: Center(
                          child: IconButton(
                            tooltip: isPlaying ? l10n.pause : l10n.play,
                            onPressed: () => ref
                                .read(playerProvider.notifier)
                                .togglePlayPause(),
                            icon: Icon(
                              isPlaying ? LucideIcons.pause : LucideIcons.play,
                              size: 22,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (config.showProgress)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _VerticalProgress(progress: progress),
                    ),
                  if (config.showBorder)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(Song song, Duration duration) {
    final placeholder = ColoredBox(
      color: AppColors.surface,
      child: const FlickArtworkPlaceholder(size: 26, opacity: 0.9),
    );
    final artwork = song.albumArt != null
        ? CachedImageWidget(
            imagePath: song.albumArt!,
            audioSourcePath: song.filePath,
            fit: BoxFit.cover,
            useThumbnail: true,
            thumbnailWidth: 128,
            thumbnailHeight: 128,
            placeholder: placeholder,
            errorWidget: placeholder,
          )
        : placeholder;

    return SizedBox(
      height: AdaptiveLayout.sideMiniPlayerWidth,
      width: double.infinity,
      child: Hero(
        tag: LandscapeSideMiniPlayer.heroTag,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, _songChangeDirection * 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(song.id), child: artwork),
        ),
      ),
    );
  }

  Widget _buildVisualizer({
    required AppPreferences prefs,
    required bool visualizerEnabled,
  }) {
    if (!visualizerEnabled) {
      return Center(
        child: Icon(
          LucideIcons.audioLines,
          size: 18,
          color: context.adaptiveTextSecondary.withValues(alpha: 0.35),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: AppConstants.spacingXxs,
      ),
      child: RotatedBox(
        key: const ValueKey('side_mini_player_visualizer'),
        quarterTurns: 3,
        child: AudioVisualizer(
          playerService: ref.read(playerServiceProvider),
          animationStyle: prefs.visualizerAnimationStyle,
          frequencyMode: prefs.visualizerFrequencyMode,
          movementMode: prefs.visualizerMovementMode,
          albumColor: ref.watch(albumDominantColorSyncProvider),
          enabled: true,
        ),
      ),
    );
  }

  List<BoxShadow>? _shadow(MiniPlayerConfig config) {
    return switch (config.shadow) {
      MiniPlayerShadow.off => null,
      MiniPlayerShadow.subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(-4, 0),
        ),
      ],
      MiniPlayerShadow.strong => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(-8, 0),
        ),
      ],
    };
  }
}

class _VerticalProgress extends StatelessWidget {
  final double progress;

  const _VerticalProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
          if (value > 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value,
                widthFactor: 1,
                child: ColoredBox(
                  key: const ValueKey('side_mini_player_progress'),
                  color: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
