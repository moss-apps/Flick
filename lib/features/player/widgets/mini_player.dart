import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/uac2/uac2_player_status.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  final PlayerService _playerService = PlayerService();

  Future<void> _openQueue(BuildContext context) async {
    await NavigationHelper.navigateToQueue(context);
  }

  Widget _buildQueueButton(BuildContext context, int queueCount) {
    final hasQueue = queueCount > 0;

    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        _openQueue(context);
      },
      child: AnimatedContainer(
        duration: AppConstants.animationFast,
        padding: EdgeInsets.symmetric(
          horizontal: hasQueue ? 10 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: hasQueue
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasQueue
                ? AppColors.accent.withValues(alpha: 0.26)
                : AppColors.glassBorder.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.listMusic,
              size: 16,
              color: hasQueue ? AppColors.accentLight : AppColors.textSecondary,
            ),
            if (hasQueue) ...[
              const SizedBox(width: 6),
              Text(
                '$queueCount',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: _playerService.currentSongNotifier,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            AppHaptics.tap();
            NavigationHelper.navigateToFullPlayer(
              context,
              heroTag: 'song_art_${song.id}',
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Progress bar at the bottom
                  ValueListenableBuilder<Duration>(
                    valueListenable: _playerService.positionNotifier,
                    builder: (context, position, _) {
                      return ValueListenableBuilder<Duration>(
                        valueListenable: _playerService.durationNotifier,
                        builder: (context, duration, _) {
                          if (duration.inMilliseconds <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: FractionallySizedBox(
                                widthFactor: (position.inMilliseconds /
                                        duration.inMilliseconds)
                                    .clamp(0.0, 1.0),
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(3),
                                      topRight: Radius.circular(3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  Row(
                    children: [
                      // Floating Album Art
                      Hero(
                        tag: 'mini_player_art',
                        child: Container(
                          margin: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 14),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedImageWidget(
                              imagePath: song.albumArt,
                              audioSourcePath: song.filePath,
                              fit: BoxFit.cover,
                              useThumbnail: true,
                              thumbnailWidth: 128,
                              thumbnailHeight: 128,
                              placeholder: const Icon(
                                LucideIcons.music,
                                size: 24,
                                color: AppColors.textTertiary,
                              ),
                              errorWidget: const Icon(
                                LucideIcons.music,
                                size: 24,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Song Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'ProductSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Uac2PlayerStatus(
                                  compact: true,
                                  showDeviceName: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2), // Spacing for progress bar
                          ],
                        ),
                      ),

                      // Controls
                      if (!song.isFromLocker)
                        ValueListenableBuilder<List<Song>>(
                          valueListenable: _playerService.upNextNotifier,
                          builder: (context, upNext, _) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildQueueButton(context, upNext.length),
                            );
                          },
                        ),

                      // Play/Pause button with circular background
                      ValueListenableBuilder<bool>(
                        valueListenable: _playerService.isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPlaying 
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.glassBackgroundStrong,
                              border: Border.all(
                                color: isPlaying 
                                  ? AppColors.accent.withValues(alpha: 0.3)
                                  : AppColors.glassBorder.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  AppHaptics.tap();
                                  _playerService.togglePlayPause();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Icon(
                                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                                    color: isPlaying ? AppColors.accentLight : AppColors.textPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
