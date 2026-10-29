import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/mini_player_config.dart';
import 'package:flick/widgets/navigation/bottom_bar_geometry.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/common/marquee_widget.dart';

class MiniPlayerBar extends StatelessWidget {
  final MiniPlayerConfig config;
  final String songId;
  final String title;
  final String artist;
  final String? albumArt;
  final String? audioSourcePath;
  final bool isPlaying;
  final double progress;
  final Widget? progressOverlay;
  final bool separated;
  final bool collapsed;
  final bool enableHero;
  final int songChangeDirection;
  final Widget? visualizer;
  final VoidCallback? onOpen;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final GestureDragEndCallback? onHorizontalDragEnd;

  const MiniPlayerBar({
    super.key,
    required this.config,
    required this.songId,
    required this.title,
    required this.artist,
    this.albumArt,
    this.audioSourcePath,
    this.isPlaying = false,
    this.progress = 0,
    this.progressOverlay,
    this.separated = false,
    this.collapsed = false,
    this.enableHero = true,
    this.songChangeDirection = 0,
    this.visualizer,
    this.onOpen,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onHorizontalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final height = BottomBarGeometry.miniPlayerHeight(context, config);
    final radius = math.min(config.cornerRadius, height / 2);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : AppConstants.animationNormal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final controlsWidth =
            48.0 *
            (1 + (config.showPrevious ? 1 : 0) + (config.showNext ? 1 : 0));
        final titleWidth = math.max(
          56.0,
          MediaQuery.textScalerOf(context).scale(56 * config.textScale),
        );
        final minimum =
            controlsWidth + titleWidth + 16 + (config.showArtwork ? height : 0);
        final standardWidth = BottomBarGeometry.standardNavigationWidth(
          context,
          availableWidth: available,
        );
        final width =
            separated && config.widthMode == MiniPlayerWidthMode.custom
            ? math.min(
                available,
                math.max(available * config.widthFraction, minimum),
              )
            : standardWidth;
        final artworkVisible =
            config.showArtwork &&
            width >= controlsWidth + titleWidth + height + 16;
        return Padding(
          padding: EdgeInsets.only(
            top: 12,
            bottom: separated ? config.navigationGap : (collapsed ? 12 : 8),
          ),
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              onHorizontalDragEnd: onHorizontalDragEnd,
              child: AnimatedContainer(
                key: const ValueKey('mini_player_surface'),
                duration: duration,
                width: width,
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceLight.withValues(
                        alpha: config.backgroundOpacity * (0.86 / 0.94),
                      ),
                      AppColors.surface.withValues(
                        alpha: config.backgroundOpacity,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  border: config.showBorder
                      ? Border.all(color: Colors.white.withValues(alpha: 0.45))
                      : null,
                  boxShadow: config.shadow == MiniPlayerShadow.off
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: config.shadow == MiniPlayerShadow.strong
                                  ? 0.35
                                  : 0.22,
                            ),
                            blurRadius: config.shadow == MiniPlayerShadow.strong
                                ? 24
                                : 14,
                            offset: Offset(
                              0,
                              config.shadow == MiniPlayerShadow.strong ? 8 : 4,
                            ),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(songChangeDirection * 0.3, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: HeroMode(
                              enabled:
                                  enableHero &&
                                  child.key == ValueKey('song_$songId') &&
                                  visualizer == null,
                              child: child,
                            ),
                          ),
                        ),
                        child:
                            visualizer ??
                            _songRow(context, artworkVisible, height),
                      ),
                      if (config.showProgress)
                        progressOverlay ??
                            MiniPlayerProgress(progress: progress),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _songRow(BuildContext context, bool artworkVisible, double height) {
    final titleStyle = TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontFamilyFallback: AppTheme.fontFamilyFallback,
      fontWeight: FontWeight.w600,
      fontSize: 14 * config.textScale,
      height: 1.15,
      color: context.adaptiveTextPrimary,
    );
    return Row(
      key: ValueKey('song_$songId'),
      children: [
        if (artworkVisible)
          HeroMode(
            enabled: enableHero,
            child: Hero(
              tag: 'mini_player_art',
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    math.min(config.cornerRadius, height / 2),
                  ),
                  bottomLeft: Radius.circular(
                    math.min(config.cornerRadius, height / 2),
                  ),
                ),
                child: SizedBox(
                  width: height,
                  height: height,
                  child: albumArt != null
                      ? CachedImageWidget(
                          imagePath: albumArt!,
                          audioSourcePath: audioSourcePath,
                          fit: BoxFit.cover,
                          useThumbnail: true,
                          thumbnailWidth: 128,
                          thumbnailHeight: 128,
                          placeholder: _placeholder,
                          errorWidget: _placeholder,
                        )
                      : _placeholder,
                ),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(context, titleStyle),
              if (config.showArtist) ...[
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontWeight: FontWeight.w500,
                    fontSize: 12 * config.textScale,
                    height: 1.15,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (config.showPrevious)
          _control(context, LucideIcons.skipBack, l10n.previousSong, onPrevious),
        _control(
          context,
          isPlaying ? LucideIcons.pause : LucideIcons.play,
          isPlaying ? l10n.pause : l10n.play,
          onPlayPause,
        ),
        if (config.showNext)
          _control(context, LucideIcons.skipForward, l10n.nextSong, onNext),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _title(BuildContext context, TextStyle style) {
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (config.titleMode != MiniPlayerTitleMode.scroll ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return text;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: title, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final overflows = painter.width > constraints.maxWidth;
        painter.dispose();
        return overflows
            ? MarqueeWidget(
                key: ValueKey(title),
                child: Text(title, maxLines: 1, style: style),
              )
            : text;
      },
    );
  }

  Widget _control(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: context.adaptiveTextPrimary),
    ),
  );

  static const _placeholder = ColoredBox(
    color: AppColors.surface,
    child: FlickArtworkPlaceholder(size: 26, opacity: 0.9),
  );
}

class MiniPlayerProgress extends StatelessWidget {
  final double progress;

  const MiniPlayerProgress({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (!progress.isFinite || progress <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            key: const ValueKey('mini_player_progress'),
            height: 2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
