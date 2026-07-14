import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/uac2/uac2_error_notification.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/features/player/widgets/bit_perfect_capsule.dart';
import 'package:flick/features/player/widgets/bit_perfect_indicator.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/features/player/widgets/visualizer_art_box.dart';
import 'package:flick/features/player/widgets/album_art_box.dart';
import 'package:flick/features/player/widgets/waveform_layer.dart';
import 'package:flick/features/player/widgets/player_controls.dart';
import 'package:flick/features/player/widgets/inline_lyrics_panel.dart';
import 'package:flick/features/player/widgets/lyrics_mode_waveform_strip.dart';
class AnimatedSongScene extends StatelessWidget {
  final Song song;
  final bool lyricsMode;
  final bool visualizationMode;
  final bool immersiveFullView;
  final PlayerScreenMode playerScreenMode;
  final AlbumColorMode albumColorMode;
  final Color? albumColor;
  final int transitionDirection;

  final String topBarTextFontFamily;
  final FontWeight topBarTextFontWeight;
  final double cachedTopBarTextWidth;
  final PlayerService playerService;
  final LyricsService lyricsService;
  final ValueNotifier<Duration> throttledPositionNotifier;
  final String Function(Duration) formatDuration;
  final VoidCallback onClose;
  final VoidCallback onOpenQueue;
  final VoidCallback onToggleLyrics;
  final Future<void> Function() onQueueSwipe;
  final Future<void> Function() onReturnToLocker;
  final VoidCallback onShowSongActions;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final void Function(Song song) onNavigateToArtistDetail;
  final void Function(Song song) onNavigateToAlbumDetail;
  final Widget Function(Song song, bool lyricsMode, PlayerScreenMode mode)
  buildFileInfoRow;
  final String visualizerAnimationStyle;
  final String visualizerFrequencyMode;
  final String visualizerMovementMode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
  final bool artworkCardShowFrame;
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;
  final bool immersiveShowTitle;
  final bool immersiveShowArtist;
  final bool immersiveShowFileInfo;
  final bool hideQueueBadge;
  final void Function(bool enabled)? onRotationEnabledChanged;
  final bool vinylMode;
  final ValueChanged<bool>? onVinylChanged;

  const AnimatedSongScene({super.key,
    required this.song,
    required this.lyricsMode,
    required this.visualizationMode,
    required this.immersiveFullView,
    required this.playerScreenMode,
    required this.albumColorMode,
    this.albumColor,
    required this.transitionDirection,
    required this.topBarTextFontFamily,
    required this.topBarTextFontWeight,
    required this.cachedTopBarTextWidth,
    required this.playerService,
    required this.lyricsService,
    required this.throttledPositionNotifier,
    required this.formatDuration,
    required this.onClose,
    required this.onOpenQueue,
    required this.onToggleLyrics,
    required this.onQueueSwipe,
    required this.onReturnToLocker,
    required this.onShowSongActions,
    required this.onPrevious,
    required this.onNext,
    required this.onNavigateToArtistDetail,
    required this.onNavigateToAlbumDetail,
    required this.buildFileInfoRow,
    this.visualizerAnimationStyle = 'bars',
    this.visualizerFrequencyMode = 'full',
    this.visualizerMovementMode = 'bouncy',
    this.artworkCardArtworkScale = 1.0,
    this.artworkCardTextScale = 1.0,
    this.artworkCardVerticalOffset = 0.0,
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFileInfo = true,
    this.artworkCardShowFrame = true,
    this.immersiveTextScale = 1.0,
    this.immersiveVerticalOffset = 0.0,
    this.immersiveFullViewScale = 1.0,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
    this.immersiveShowFileInfo = true,
    this.hideQueueBadge = false,
    this.onRotationEnabledChanged,
    this.vinylMode = false,
    this.onVinylChanged,
  });

  @override
  Widget build(BuildContext context) {
    final direction = transitionDirection >= 0 ? 1.0 : -1.0;
    final sceneKey = ValueKey('${song.id}_${playerScreenMode.storageValue}');
    final showVisualizerOnly =
        visualizationMode &&
        immersiveFullView &&
        playerScreenMode == PlayerScreenMode.immersive;
    final showImmersiveFullView =
        immersiveFullView && playerScreenMode == PlayerScreenMode.immersive;

    final scene = RepaintBoundary(
      key: sceneKey,
      child: Stack(
        children: [
          Positioned.fill(child: _buildBackground(context)),
          AnimatedSwitcher(
            duration: AppConstants.animationNormal,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isFullView =
                  child.key == const ValueKey('immersive-full-view');
              final slideOffset = isFullView
                  ? const Offset(0, 0.12)
                  : const Offset(0, 0.03);
              return SlideTransition(
                position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: showVisualizerOnly
                ? const KeyedSubtree(
                    key: ValueKey('immersive-empty-overlay'),
                    child: SizedBox.shrink(),
                  )
                : showImmersiveFullView
                ? KeyedSubtree(
                    key: const ValueKey('immersive-full-view'),
                    child: SafeArea(
                      child: _buildImmersiveFullViewLayout(context),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('immersive-default-layout'),
                    child: SafeArea(
                      child: Column(
                        children: [
                          const Uac2ErrorNotification(),
                          _buildTopChrome(context),
                          SizedBox(height: context.responsive(8.0, 10.0, 12.0)),
                          Expanded(
                            child:
                                playerScreenMode == PlayerScreenMode.artworkCard
                                ? _buildArtworkCardLayout(context)
                                : _buildImmersiveLayout(context),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    if (AppConstants.animationNormal == Duration.zero) {
      return scene;
    }

    return AnimatedSwitcher(
      duration: AppConstants.animationNormal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...?currentChild == null ? null : [currentChild],
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final offsetAnimation =
            Tween<Offset>(
              begin: Offset(direction * 0.4, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final outgoingOffsetAnimation =
            Tween<Offset>(
              begin: Offset(-direction * 0.4, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInCubic),
            );
        final isIncoming = child.key == sceneKey;

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: isIncoming ? offsetAnimation : outgoingOffsetAnimation,
            child: child,
          ),
        );
      },
      child: scene,
    );
  }

  Widget _buildBackground(BuildContext context) {
    final bgBlend = albumColorMode.backgroundBlend;
    final hasAlbumTint = albumColor != null && bgBlend > 0;

    if (visualizationMode && playerScreenMode != PlayerScreenMode.artworkCard) {
      final overlayColor = hasAlbumTint
          ? albumSurface(albumColor!, bgBlend * 0.5)
          : const Color(0xFF0A0A0A);
      return Stack(
        children: [
          Positioned.fill(
            child: AudioVisualizer(
              playerService: playerService,
              animationStyle: visualizerAnimationStyle,
              frequencyMode: visualizerFrequencyMode,
              movementMode: visualizerMovementMode,
              albumColor: albumColor,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    overlayColor.withValues(alpha: 0.7),
                    overlayColor.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.transparent,
                    overlayColor.withValues(alpha: 0.3),
                    overlayColor.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.12, 0.28, 0.62, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (playerScreenMode == PlayerScreenMode.artworkCard) {
      return Stack(
        children: [
          Positioned.fill(
            child: (song.albumArt != null || song.filePath != null)
                ? AmbientBackground(song: song)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF181818), AppColors.background],
                      ),
                    ),
                    child: Icon(
                      LucideIcons.music,
                      size: 120,
                      color: AppColors.textTertiary.withValues(alpha: 0.2),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend)
                            : const Color(0xFF080808))
                        .withValues(alpha: 0.5),
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend * 0.6)
                            : const Color(0xFF0E0E0E))
                        .withValues(alpha: 0.32),
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend)
                            : const Color(0xFF0A0A0A))
                        .withValues(alpha: 0.94),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Immersive mode: full-bleed album art with dark gradient overlay
    final gradientBase = hasAlbumTint
        ? albumSurface(albumColor!, bgBlend)
        : const Color(0xFF121212);

    final gradientColors = immersiveFullView
        ? [
            gradientBase.withValues(alpha: 0.3),
            gradientBase.withValues(alpha: 0.25),
            gradientBase.withValues(alpha: 0.2),
            gradientBase.withValues(alpha: 0.15),
            gradientBase.withValues(alpha: 0.08),
            Colors.transparent,
          ]
        : [
            gradientBase,
            gradientBase.withValues(alpha: 0.95),
            gradientBase.withValues(alpha: 0.85),
            gradientBase.withValues(alpha: 0.6),
            gradientBase.withValues(alpha: 0.3),
            Colors.transparent,
          ];

    return Stack(
      children: [
        Positioned.fill(
          child: CachedImageWidget(
            imagePath: song.albumArt,
            audioSourcePath: song.filePath,
            fit: BoxFit.cover,
            placeholder: Container(
              color: AppColors.background,
              child: Icon(
                LucideIcons.music,
                size: 120,
                color: AppColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            errorWidget: Container(
              color: AppColors.background,
              child: Icon(
                LucideIcons.music,
                size: 120,
                color: AppColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedContainer(
            duration: AppConstants.animationNormal,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradientColors,
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopChrome(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 12.0, 16.0),
        vertical: context.responsive(4.0, 6.0, 8.0),
      ),
      child: Row(
        children: [
          _buildChromeButton(
            context,
            icon: LucideIcons.chevronDown,
            onTap: onClose,
          ),
          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
          Expanded(
            child: GestureDetector(
              onTap: song.isFromLocker ? null : onOpenQueue,
              onHorizontalDragEnd: song.isFromLocker
                  ? null
                  : (details) async {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -400) {
                        await onQueueSwipe();
                      }
                    },
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: playerService.upNextNotifier,
                builder: (context, upNext, _) {
                  final hasQueue = upNext.isNotEmpty;
                  final fromLocker = song.isFromLocker;
                  final nowPlayingContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: context.responsive(12.0, 13.0, 14.0),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (fromLocker) ...[
                        SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
                        Text(
                          'Opened from Locker',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsive(10.0, 10.5, 11.0),
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  );

                  final chip = AnimatedContainer(
                    duration: AppConstants.animationFast,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(12.0, 14.0, 16.0),
                      vertical: context.responsive(6.0, 7.0, 8.0),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasQueue
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        nowPlayingContent,
                        if (!fromLocker && !hideQueueBadge) ...[
                          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
                          _buildQueueSummaryBadge(
                            context,
                            count: upNext.length,
                            highlighted: hasQueue,
                          ),
                        ],
                      ],
                    ),
                  );

                  return Align(
                    alignment: Alignment.center,
                    widthFactor: 1.0,
                    child: chip,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.isFromLocker) ...[
                _buildReturnToLockerButton(context),
                SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
              ],
              _buildChromeButton(
                context,
                icon: Icons.more_vert,
                onTap: onShowSongActions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnToLockerButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(onReturnToLocker());
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsive(12.0, 14.0, 16.0),
          vertical: context.responsive(10.0, 11.0, 12.0),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF121212).withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.undo2,
              size: context.responsive(14.0, 15.0, 16.0),
              color: Colors.white.withValues(alpha: 0.9),
            ),
            SizedBox(width: context.responsive(6.0, 7.0, 8.0)),
            Text(
              'Back to Locker',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsive(11.0, 12.0, 13.0),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueSummaryBadge(
    BuildContext context, {
    required int count,
    required bool highlighted,
  }) {
    return AnimatedContainer(
      duration: AppConstants.animationFast,
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 9.0, 10.0),
        vertical: context.responsive(3.0, 4.0, 5.0),
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.listMusic,
            size: context.responsive(12.0, 13.0, 14.0),
            color: Colors.white.withValues(alpha: highlighted ? 0.96 : 0.7),
          ),
          SizedBox(width: context.responsive(4.0, 5.0, 6.0)),
          Text(
            count > 0 ? 'Queue $count' : 'Queue',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: context.responsive(10.0, 11.0, 12.0),
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: highlighted ? 0.96 : 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChromeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final surfaceColor = albumColor != null
        ? albumSurface(albumColor!, albumColorMode.surfaceBlend)
        : const Color(0xFF121212);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: AppHaptics.wrap(onTap),
        padding: EdgeInsets.all(context.responsive(8.0, 10.0, 12.0)),
        constraints: const BoxConstraints(),
        icon: Icon(
          icon,
          color: Colors.white,
          size: context.responsive(20.0, 22.0, 24.0),
        ),
      ),
    );
  }

  Widget _buildImmersiveLayout(BuildContext context) {
    final layout = lyricsMode
        ? KeyedSubtree(
            key: const ValueKey('immersive-lyrics-layout'),
            child: Column(
              children: [
                SizedBox(height: context.responsive(8.0, 10.0, 12.0)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(20.0, 28.0, 36.0),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InlineLyricsPanel(
                            song: song,
                            playerService: playerService,
                            lyricsService: lyricsService,
                            albumColor: albumColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
                LyricsModeWaveformStrip(
                  playerService: playerService,
                  positionNotifier: throttledPositionNotifier,
                  currentSong: song,
                  formatDuration: formatDuration,
                  horizontalPadding: context.responsive(18.0, 24.0, 30.0),
                  onSwipeUp: onToggleLyrics,
                ),
              ],
            ),
          )
        : KeyedSubtree(
            key: const ValueKey('immersive-default-layout'),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Transform.translate(
                  offset: Offset(0, immersiveVerticalOffset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsive(12.0, 16.0, 20.0),
                        ),
                        child: _buildImmersiveSongHeader(context),
                      ),
                      if (immersiveShowFileInfo) ...[
                        Builder(
                          builder: (context) {
                            final diagnostics = ProviderScope.containerOf(
                              context,
                            ).read(audioOutputDiagnosticsProvider);
                            final appPrefs = ProviderScope.containerOf(
                              context,
                            ).read(appPreferencesProvider);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (diagnostics != null &&
                                    appPrefs
                                        .replaceAlbumWithBitPerfectCapsule) ...[
                                  SizedBox(
                                    height: context.responsive(6.0, 8.0, 10.0),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.responsive(
                                        12.0,
                                        16.0,
                                        20.0,
                                      ),
                                    ),
                                    child: BitPerfectCapsule(
                                      diagnostics: diagnostics,
                                      horizontalPadding: context.responsive(
                                        12.0,
                                        14.0,
                                        16.0,
                                      ),
                                      verticalPadding: context.responsive(
                                        4.0,
                                        5.0,
                                        6.0,
                                      ),
                                      fontSize: context.responsive(
                                        11.0,
                                        12.0,
                                        13.0,
                                      ),
                                      onTap: () {
                                        final deviceStatus =
                                            ProviderScope.containerOf(
                                              context,
                                            ).read(uac2DeviceStatusProvider);
                                        BitPerfectIndicator.showInfoSheet(
                                          context,
                                          song: song,
                                          diagnostics: diagnostics,
                                          deviceStatus: deviceStatus,
                                          playerService: playerService,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                SizedBox(
                                  height: context.responsive(10.0, 12.0, 14.0),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.responsive(
                                      12.0,
                                      16.0,
                                      20.0,
                                    ),
                                  ),
                                  child: buildFileInfoRow(
                                    song,
                                    lyricsMode,
                                    playerScreenMode,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: context.responsive(12.0, 14.0, 16.0)),
                _buildPlaybackStack(context),
                SizedBox(height: context.responsive(24.0, 32.0, 40.0)),
              ],
            ),
          );

    if (AppConstants.animationNormal == Duration.zero) {
      return layout;
    }

    return AnimatedSwitcher(
      duration: AppConstants.animationNormal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...?currentChild == null ? null : [currentChild],
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isLyricsChild =
            child.key == const ValueKey('immersive-lyrics-layout');
        final offsetAnimation = Tween<Offset>(
          begin: isLyricsChild ? const Offset(0, -0.04) : const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: layout,
    );
  }

  Widget _buildImmersiveFullViewLayout(BuildContext context) {
    final artworkSize =
        context.responsive(56.0, 60.0, 64.0) * immersiveFullViewScale;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsive(16.0, 20.0, 24.0),
          0,
          context.responsive(16.0, 20.0, 24.0),
          context.responsive(20.0, 24.0, 28.0),
        ),
        child: Container(
          padding: EdgeInsets.all(
            context.responsive(10.0, 12.0, 14.0) * immersiveFullViewScale,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  18 * immersiveFullViewScale,
                ),
                child: SizedBox(
                  width: artworkSize,
                  height: artworkSize,
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(
                        LucideIcons.music,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: artworkSize * 0.44,
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(
                        LucideIcons.music,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: artworkSize * 0.44,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.responsive(12.0, 14.0, 16.0)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (immersiveShowTitle)
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: context.responsiveText(
                            context.responsive(18.0, 19.0, 21.0) *
                                immersiveTextScale,
                          ),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                    if (immersiveShowTitle && immersiveShowArtist)
                      SizedBox(height: context.responsive(6.0, 7.0, 8.0)),
                    if (immersiveShowArtist)
                      GestureDetector(
                        onTap: () => onNavigateToArtistDetail(song),
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsiveText(
                              context.responsive(13.0, 14.0, 15.0) *
                                  immersiveTextScale,
                            ),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
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

  Widget _buildImmersiveSongHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (immersiveShowTitle)
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsiveText(
                      context.responsive(22.0, 24.0, 28.0) * immersiveTextScale,
                    ),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.08,
                  ),
                ),
              if (immersiveShowTitle && immersiveShowArtist)
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
              if (immersiveShowArtist)
                GestureDetector(
                  onTap: () => onNavigateToArtistDetail(song),
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsiveText(
                        context.responsive(13.0, 14.0, 16.0) *
                            immersiveTextScale,
                      ),
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              if (immersiveShowTitle || immersiveShowArtist)
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkCardLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShortHeight = constraints.maxHeight < 620;
        final isVeryShortHeight = constraints.maxHeight < 540;
        final horizontalPadding = constraints.maxWidth < 360
            ? 16.0
            : context.responsive(20.0, 28.0, 36.0);
        final topPadding = isVeryShortHeight
            ? 6.0
            : context.responsive(10.0, 12.0, 16.0);
        final maxArtworkSize = context.responsive(320.0, 360.0, 400.0);
        final baseArtworkSize = math
            .min(
              (constraints.maxWidth - (horizontalPadding * 2)) * 0.82,
              isVeryShortHeight
                  ? constraints.maxHeight * 0.32
                  : isShortHeight
                  ? constraints.maxHeight * 0.36
                  : constraints.maxHeight * 0.42,
            )
            .clamp(isVeryShortHeight ? 160.0 : 180.0, maxArtworkSize)
            .toDouble();
        final artworkSize = (baseArtworkSize * artworkCardArtworkScale)
            .clamp(isVeryShortHeight ? 140.0 : 160.0, constraints.maxWidth)
            .toDouble();
        final artworkSpacing = isVeryShortHeight
            ? 12.0
            : isShortHeight
            ? 16.0
            : context.responsive(22.0, 26.0, 30.0);
        final identitySpacing = isVeryShortHeight
            ? 8.0
            : isShortHeight
            ? 12.0
            : context.responsive(18.0, 20.0, 22.0);
        final lyricsSpacing = isVeryShortHeight
            ? 12.0
            : context.responsive(16.0, 18.0, 20.0);
        final playbackSpacing = isVeryShortHeight
            ? 10.0
            : context.responsive(14.0, 16.0, 18.0);
        final directorySpacing = isVeryShortHeight
            ? 12.0
            : isShortHeight
            ? 18.0
            : context.responsive(24.0, 32.0, 40.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            0,
          ),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ...?currentChild == null ? null : [currentChild],
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isLyrics =
                        child.key == const ValueKey('artwork-lyrics');
                    final slide =
                        Tween<Offset>(
                          begin: isLyrics
                              ? const Offset(0, -0.06)
                              : const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: lyricsMode
                      ? Padding(
                          key: const ValueKey('artwork-lyrics'),
                          padding: EdgeInsets.only(bottom: lyricsSpacing),
                          child: InlineLyricsPanel(
                            song: song,
                            playerService: playerService,
                            lyricsService: lyricsService,
                            albumColor: albumColor,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('artwork-default'),
                          child: Transform.translate(
                            offset: Offset(0, artworkCardVerticalOffset),
                            child: Column(
                              mainAxisAlignment: isVeryShortHeight
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: isVeryShortHeight ? 5 : 7,
                                  child: Center(
                                    child: OverflowBox(
                                      maxWidth: artworkSize,
                                      maxHeight: artworkSize,
                                      child: visualizationMode
                                          ? VisualizerArtBox(
                                              playerService: playerService,
                                              size: artworkSize,
                                              animationStyle:
                                                  visualizerAnimationStyle,
                                              frequencyMode:
                                                  visualizerFrequencyMode,
                                              movementMode:
                                                  visualizerMovementMode,
                                              albumColor: albumColor,
                                              showFrame: artworkCardShowFrame,
                                            )
                                          : AlbumArtBox(
                                              song: song,
                                              size: artworkSize,
                                              playerService: playerService,
                                              onRotationEnabledChanged:
                                                  onRotationEnabledChanged,
                                              initialVinyl: vinylMode,
                                              onVinylChanged: onVinylChanged,
                                              showFrame: artworkCardShowFrame,
                                            ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: artworkSpacing),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isVeryShortHeight ? 8.0 : 0.0,
                                  ),
                                  child: _buildSongIdentity(
                                    context,
                                    compact: isShortHeight,
                                    veryCompact: isVeryShortHeight,
                                  ),
                                ),
                                SizedBox(height: identitySpacing),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              if (artworkCardShowFileInfo)
                buildFileInfoRow(song, lyricsMode, playerScreenMode),
              if (artworkCardShowFileInfo) SizedBox(height: playbackSpacing),
              _buildPlaybackStack(context),
              SizedBox(height: directorySpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongIdentity(
    BuildContext context, {
    bool compact = false,
    bool veryCompact = false,
  }) {
    final titleSize =
        (veryCompact
            ? context.responsive(20.0, 22.0, 25.0)
            : compact
            ? context.responsive(22.0, 25.0, 28.0)
            : context.responsive(25.0, 27.0, 30.0)) *
        artworkCardTextScale;
    final artistSize =
        (veryCompact
            ? context.responsive(13.0, 14.0, 15.0)
            : compact
            ? context.responsive(14.0, 15.0, 16.0)
            : context.responsive(15.0, 16.0, 17.0)) *
        artworkCardTextScale;
    final titleToArtistSpacing = veryCompact
        ? 6.0
        : context.responsive(8.0, 10.0, 12.0);
    final artistToAlbumSpacing = veryCompact
        ? 8.0
        : compact
        ? 10.0
        : context.responsive(12.0, 14.0, 16.0);
    final albumHorizontalPadding = veryCompact
        ? 10.0
        : context.responsive(12.0, 14.0, 16.0);
    final albumVerticalPadding = veryCompact
        ? 5.0
        : context.responsive(6.0, 7.0, 8.0);
    final albumFontSize =
        (veryCompact
            ? context.responsive(10.0, 11.0, 12.0)
            : context.responsive(11.0, 12.0, 13.0)) *
        artworkCardTextScale;

    final diagnostics = ProviderScope.containerOf(
      context,
    ).read(audioOutputDiagnosticsProvider);
    final appPrefs = ProviderScope.containerOf(
      context,
    ).read(appPreferencesProvider);
    final isBitPerfectVerified =
        diagnostics?.capabilityFlags.supportsVerifiedBitPerfect == true;
    final showBitPerfectCapsule =
        appPrefs.replaceAlbumWithBitPerfectCapsule &&
        diagnostics != null &&
        isBitPerfectVerified;
    final hasAlbum = song.album != null && song.album!.trim().isNotEmpty;

    return Column(
      children: [
        if (artworkCardShowTitle)
          Text(
            song.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: context.responsiveText(titleSize),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.08,
            ),
          ),
        if (artworkCardShowTitle && artworkCardShowArtist)
          SizedBox(height: titleToArtistSpacing),
        if (artworkCardShowArtist)
          GestureDetector(
            onTap: () => onNavigateToArtistDetail(song),
            child: Text(
              song.artist,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsiveText(artistSize),
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        if (artworkCardShowAlbum &&
            (artworkCardShowTitle || artworkCardShowArtist) &&
            (hasAlbum || showBitPerfectCapsule)) ...[
          SizedBox(height: artistToAlbumSpacing),
          if (diagnostics != null && appPrefs.replaceAlbumWithBitPerfectCapsule)
            Stack(
              alignment: Alignment.center,
              children: [
                if (hasAlbum)
                  AnimatedOpacity(
                    opacity: isBitPerfectVerified ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: albumHorizontalPadding,
                        vertical: albumVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () => onNavigateToAlbumDetail(song),
                        child: Text(
                          song.album!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsiveText(albumFontSize),
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                    ),
                  ),
                BitPerfectCapsule(
                  diagnostics: diagnostics,
                  horizontalPadding: albumHorizontalPadding,
                  verticalPadding: albumVerticalPadding,
                  fontSize: albumFontSize,
                  onTap: () {
                    final deviceStatus = ProviderScope.containerOf(
                      context,
                    ).read(uac2DeviceStatusProvider);
                    BitPerfectIndicator.showInfoSheet(
                      context,
                      song: song,
                      diagnostics: diagnostics,
                      deviceStatus: deviceStatus,
                      playerService: playerService,
                    );
                  },
                ),
              ],
            )
          else if (hasAlbum)
            GestureDetector(
              onTap: () => onNavigateToAlbumDetail(song),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: albumHorizontalPadding,
                  vertical: albumVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  song.album!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsiveText(albumFontSize),
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPlaybackStack(BuildContext context) {
    final immersivePlaybackPadding =
        playerScreenMode == PlayerScreenMode.immersive
        ? context.responsive(18.0, 24.0, 30.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: immersivePlaybackPadding),
          child: WaveformLayer(
            playerService: playerService,
            positionNotifier: throttledPositionNotifier,
            currentSong: song,
          ),
        ),
        SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
        PlayerControls(
          playerService: playerService,
          formatDuration: formatDuration,
          currentSong: song,
          onPrevious: onPrevious,
          onNext: onNext,
          timelineHorizontalPadding: immersivePlaybackPadding,
          albumColorMode: albumColorMode,
          albumColor: albumColor,
        ),
      ],
    );
  }
}

