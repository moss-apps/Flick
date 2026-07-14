import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/providers/rating_provider.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/features/player/widgets/bit_perfect_indicator.dart';
import 'package:flick/features/player/widgets/rating_button.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';
import 'package:flick/features/player/widgets/volume_bottom_sheet.dart';
import 'package:flick/features/player/widgets/share/share_bottom_sheet.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';

class PlayerActionButtonRow extends ConsumerStatefulWidget {
  final Song song;
  final bool lyricsMode;
  final bool isVisualizationMode;
  final PlayerScreenMode playerScreenMode;
  final Color? albumColor;
  final AlbumColorMode albumColorMode;
  final PlayerActionButton leftAction;
  final PlayerActionButton rightAction;
  final PlayerService playerService;
  final FavoritesService favoritesService;
  final VoidCallback onToggleLyrics;
  final void Function(bool) onToggleVisualization;
  final void Function(BuildContext) onOpenQueue;
  final GlobalKey usbVolumeButtonKey;
  final void Function(BuildContext) onShowUsbVolumePopup;

  const PlayerActionButtonRow({
    super.key,
    required this.song,
    required this.lyricsMode,
    required this.isVisualizationMode,
    required this.playerScreenMode,
    required this.albumColor,
    required this.albumColorMode,
    required this.leftAction,
    required this.rightAction,
    required this.playerService,
    required this.favoritesService,
    required this.onToggleLyrics,
    required this.onToggleVisualization,
    required this.onOpenQueue,
    required this.usbVolumeButtonKey,
    required this.onShowUsbVolumePopup,
  });

  @override
  ConsumerState<PlayerActionButtonRow> createState() =>
      _PlayerActionButtonRowState();
}

class _PlayerActionButtonRowState extends ConsumerState<PlayerActionButtonRow> {
  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final lyricsMode = widget.lyricsMode;
    final playerScreenMode = widget.playerScreenMode;
    final albumColor = widget.albumColor;
    final albumColorMode = widget.albumColorMode;
    final leftAction = widget.leftAction;
    final rightAction = widget.rightAction;
    final immersiveActions = playerScreenMode == PlayerScreenMode.immersive;
    final actionPadding = immersiveActions
        ? EdgeInsets.all(context.responsive(8.0, 9.0, 10.0))
        : EdgeInsets.all(context.responsive(6.0, 7.0, 8.0));
    final actionRadius = immersiveActions ? 12.0 : 10.0;
    final actionIconSize = context.responsive(18.0, 20.0, 22.0);

    final accentBlend = albumColorMode.accentBlend;
    final surfaceBlend = albumColorMode.surfaceBlend;
    final hasAlbumTint = albumColor != null && accentBlend > 0;

    final inactiveBg = hasAlbumTint
        ? albumSurface(
            albumColor,
            surfaceBlend,
          ).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.15);
    final inactiveBorder = hasAlbumTint
        ? albumSurface(
            albumColor,
            surfaceBlend,
          ).withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(
          context: context,
          song: song,
          action: leftAction,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          immersiveActions: immersiveActions,
          lyricsMode: lyricsMode,
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerBadge(context, song.fileType.toUpperCase()),
              if (song.isDsd && song.dsdRateLabel.isNotEmpty) ...[
                SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
                Flexible(
                  child: Text(
                    song.dsdRateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsive(9.0, 10.0, 11.0),
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ] else if (song.resolution != null) ...[
                SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
                Flexible(
                  child: Text(
                    song.resolution!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsive(9.0, 10.0, 11.0),
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
              SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
              BitPerfectIndicator(
                song: song,
                playerService: widget.playerService,
                onTap: () {
                  final diagnostics = ref.read(audioOutputDiagnosticsProvider);
                  final deviceStatus = ref.read(uac2DeviceStatusProvider);
                  BitPerfectIndicator.showInfoSheet(
                    context,
                    song: song,
                    diagnostics: diagnostics,
                    deviceStatus: deviceStatus,
                    playerService: widget.playerService,
                  );
                },
              ),
            ],
          ),
        ),
        _buildActionButton(
          context: context,
          song: song,
          action: rightAction,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          immersiveActions: immersiveActions,
          lyricsMode: lyricsMode,
        ),
      ],
    );
  }

  Widget _buildPlayerBadge(BuildContext context, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(4.0, 5.0, 6.0),
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: context.responsive(9.0, 10.0, 11.0),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
  Widget _buildActionButton({
    required BuildContext context,
    required Song song,
    required PlayerActionButton action,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
    required bool immersiveActions,
    required bool lyricsMode,
  }) {
    switch (action) {
      case PlayerActionButton.lyrics:
        return _buildLyricsButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          lyricsMode: lyricsMode,
        );
      case PlayerActionButton.favorites:
        if (song.isExternal) {
          return SizedBox(
            width: actionIconSize + actionPadding.horizontal,
            height: actionIconSize + actionPadding.vertical,
          );
        }
        return _buildFavoritesButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.visualizer:
        return _buildVisualizerButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.ratings:
        if (song.isExternal) {
          return SizedBox(
            width: actionIconSize + actionPadding.horizontal,
            height: actionIconSize + actionPadding.vertical,
          );
        }
        return _buildRatingsButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
        );
      case PlayerActionButton.queue:
        return _buildQueueButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.sleepTimer:
        return _buildSleepTimerButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.share:
        return _buildShareButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.usbVolume:
        return _buildUsbVolumeButton(
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.equalizer:
        return _buildEqualizerButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.volume:
        return _buildVolumeButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
    }
  }

  Widget _buildLyricsButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
    required bool lyricsMode,
  }) {
    final lyricsActiveBg = hasAlbumTint
        ? albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.28)
        : AppColors.accent.withValues(alpha: 0.28);
    final lyricsActiveBorder = hasAlbumTint
        ? albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.45)
        : AppColors.accent.withValues(alpha: 0.45);

    return Tooltip(
      message: lyricsMode ? 'Hide lyrics' : 'Show lyrics',
      child: GestureDetector(
        onTap: () => widget.onToggleLyrics(),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: lyricsMode ? lyricsActiveBg : inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(
              color: lyricsMode ? lyricsActiveBorder : inactiveBorder,
            ),
          ),
          child: Icon(
            lyricsMode
                ? Icons.keyboard_arrow_down_rounded
                : LucideIcons.fileText,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    return FutureBuilder<bool>(
      future: widget.favoritesService.isFavorite(song.id),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        return GestureDetector(
          onTap: () async {
            final newState = await widget.favoritesService.toggleFavorite(song.id);
            setState(() {});
            widget.playerService.refreshNotificationState();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newState ? 'Added to favorites' : 'Removed from favorites',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          child: Container(
            padding: actionPadding,
            decoration: BoxDecoration(
              color: isFavorite
                  ? (hasAlbumTint
                        ? albumAccent(
                            albumColor!,
                            accentBlend,
                          ).withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25))
                  : inactiveBg,
              borderRadius: BorderRadius.circular(actionRadius),
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite
                  ? (hasAlbumTint
                        ? albumAccent(
                            albumColor!,
                            accentBlend,
                          )
                        : Colors.red)
                  : Colors.white.withValues(alpha: 0.9),
              size: actionIconSize,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisualizerButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    final isVisMode = widget.isVisualizationMode;
    final visActiveBg = hasAlbumTint
        ? albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.28)
        : AppColors.accent.withValues(alpha: 0.28);
    final visActiveBorder = hasAlbumTint
        ? albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.45)
        : AppColors.accent.withValues(alpha: 0.45);

    return Tooltip(
      message: isVisMode ? 'Hide visualizer' : 'Show visualizer',
      child: GestureDetector(
        onTap: () => widget.onToggleVisualization(!isVisMode),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: isVisMode ? visActiveBg : inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(
              color: isVisMode ? visActiveBorder : inactiveBorder,
            ),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
  }) {
    final ratings = ref.watch(ratingProvider);
    final currentRating = ratings[song.id] ?? 0;

    return RatingButton(
      currentRating: currentRating,
      onRatingChanged: (rating) {
        if (rating == 0) {
          ref.read(ratingProvider.notifier).removeRating(song.id);
        } else {
          ref.read(ratingProvider.notifier).setRating(song.id, rating);
        }
        setState(() {});
      },
      iconSize: actionIconSize,
      padding: actionPadding,
      borderRadius: actionRadius,
      albumColor: albumColor,
      accentBlend: accentBlend,
      inactiveBg: inactiveBg,
      inactiveBorder: inactiveBorder,
    );
  }

  Widget _buildQueueButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    return Tooltip(
      message: 'Queue',
      child: GestureDetector(
        onTap: () => widget.onOpenQueue(context),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.listMusic,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Sleep timer',
      child: GestureDetector(
        onTap: () => SleepTimerBottomSheet.show(context, widget.playerService),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.moonStar,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Share',
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => ShareBottomSheet(song: song),
          );
        },
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.share2,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildUsbVolumeButton({
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    final enginePref = ref.watch(audioEnginePreferenceProvider);
    final isIsochronous = enginePref.when(
      data: (e) => e == AudioEnginePreference.isochronousUsb,
      loading: () => false,
      error: (_, _) => false,
    );

    if (!isIsochronous) {
      return SizedBox(
        width: actionIconSize + actionPadding.horizontal,
        height: actionIconSize + actionPadding.vertical,
      );
    }

    return Tooltip(
      message: 'USB Volume',
      child: GestureDetector(
        key: widget.usbVolumeButtonKey,
        onTap: () => widget.onShowUsbVolumePopup(context),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.volume2,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizerButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Equalizer',
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const EqualizerScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (AppConstants.animationNormal == Duration.zero) {
                      return child;
                    }
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.12, 0.0),
                        end: Offset.zero,
                      ).animate(curvedAnimation),
                      child: FadeTransition(
                        opacity: curvedAnimation,
                        child: child,
                      ),
                    );
                  },
              transitionDuration: AppConstants.animationNormal,
            ),
          );
        },
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.slidersHorizontal,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Volume',
      child: GestureDetector(
        onTap: () => VolumeBottomSheet.show(context, widget.playerService),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.volume,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }
}
