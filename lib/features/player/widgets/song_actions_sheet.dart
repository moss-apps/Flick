import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/player/widgets/player_navigation.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/features/songs/widgets/album_art_picker_bottom_sheet.dart';
import 'package:flick/features/songs/screens/metadata_editor_screen.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/player/widgets/share/share_bottom_sheet.dart';
import 'package:flick/features/player/widgets/song_metadata_sheet.dart';
import 'package:flick/features/player/widgets/add_to_playlist_sheet.dart';
import 'package:flick/features/player/widgets/speed_bottom_sheet.dart';
import 'package:flick/features/player/widgets/pitch_bottom_sheet.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';

class SongActionsSheet extends ConsumerWidget {
  final BuildContext parentContext;
  final PlayerService playerService;
  final Song song;
  final bool isVisualizationMode;
  final VoidCallback onShowLyrics;
  final void Function(bool) onToggleVisualization;
  final void Function(BuildContext) onShowPlayerLayout;
  final PlayerNavigation navigation;

  const SongActionsSheet({
    super.key,
    required this.parentContext,
    required this.playerService,
    required this.song,
    required this.isVisualizationMode,
    required this.onShowLyrics,
    required this.onToggleVisualization,
    required this.onShowPlayerLayout,
    required this.navigation,
  });

  static Future<void> show(
    BuildContext context, {
    required PlayerService playerService,
    required Song song,
    required bool isVisualizationMode,
    required VoidCallback onShowLyrics,
    required void Function(bool) onToggleVisualization,
    required void Function(BuildContext) onShowPlayerLayout,
    required PlayerNavigation navigation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SongActionsSheet(
        parentContext: context,
        playerService: playerService,
        song: song,
        isVisualizationMode: isVisualizationMode,
        onShowLyrics: onShowLyrics,
        onToggleVisualization: onToggleVisualization,
        onShowPlayerLayout: onShowPlayerLayout,
        navigation: navigation,
      ),
    );
  }

  @override
  Widget build(BuildContext sheetContext, WidgetRef ref) {
    final context = parentContext;
      return ValueListenableBuilder<Song?>(
        valueListenable: playerService.currentSongNotifier,
        builder: (sheetContext, currentSong, _) {
          final activeSong = currentSong ?? song;
          return SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.5,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: EdgeInsets.fromLTRB(
                context.responsive(16.0, 18.0, 20.0),
                context.responsive(10.0, 11.0, 12.0),
                context.responsive(16.0, 18.0, 20.0),
                context.responsive(20.0, 22.0, 24.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.glassBorderStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          context.responsive(10.0, 11.0, 12.0),
                        ),
                        child: SizedBox(
                          width: context.responsive(56.0, 62.0, 68.0),
                          height: context.responsive(56.0, 62.0, 68.0),
                          child: CachedImageWidget(
                            imagePath: activeSong.albumArt,
                            audioSourcePath: activeSong.filePath,
                            fit: BoxFit.cover,
                            useThumbnail: true,
                            thumbnailWidth: 136,
                            thumbnailHeight: 136,
                            placeholder: Container(
                              color: AppColors.surfaceLight,
                              child: const Icon(
                                LucideIcons.music,
                                color: AppColors.textTertiary,
                                size: 24,
                              ),
                            ),
                            errorWidget: Container(
                              color: AppColors.surfaceLight,
                              child: const Icon(
                                LucideIcons.music,
                                color: AppColors.textTertiary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: context.responsive(16.0, 17.0, 18.0),
                                fontWeight: FontWeight.w600,
                                color: sheetContext.adaptiveTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: context.responsive(12.0, 13.0, 14.0),
                                color: sheetContext.adaptiveTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSongInfoChip(
                                  sheetContext,
                                  activeSong.formattedDuration,
                                ),
                                _buildSongInfoChip(
                                  sheetContext,
                                  activeSong.fileType.toUpperCase(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!activeSong.isFromLocker)
                            _buildSongActionTile(
                              context: sheetContext,
                              icon: LucideIcons.listPlus,
                              label: 'Add to Queue',
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await navigation.queueSong(context, activeSong);
                              },
                            ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.listMusic,
                            label: 'Add to Playlist',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              AddToPlaylistSheet.show(context, activeSong);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.image,
                            label: 'Set Album Art',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Future.delayed(Duration.zero, () async {
                                final changed =
                                    await AlbumArtPickerBottomSheet.show(
                                      context,
                                      activeSong,
                                    );
                                if (changed && context.mounted) {
                                  ref.invalidate(songsProvider);
                                }
                              });
                            },
                          ),
                          if (activeSong.filePath != null &&
                              activeSong.startOffsetMs == null &&
                              !activeSong.isExternal)
                            _buildSongActionTile(
                              context: sheetContext,
                              icon: LucideIcons.pencil,
                              label: 'Edit Metadata',
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.of(context)
                                    .push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => MetadataEditorScreen(
                                          song: activeSong,
                                        ),
                                      ),
                                    )
                                    .then((saved) {
                                      if (saved == true) {
                                        ref.invalidate(songsProvider);
                                      }
                                    });
                              },
                            ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.info,
                            label: 'View Metadata',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              SongMetadataSheet.show(context, activeSong);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.fileText,
                            label: 'Lyrics',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onShowLyrics();
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: Icons.graphic_eq_rounded,
                            label: isVisualizationMode
                                ? 'Hide Visualizer'
                                : 'Visualizer',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onToggleVisualization(!isVisualizationMode);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.user,
                            label: 'Go to Artist',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              navigation.openArtistFromSong(context, activeSong);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.disc,
                            label: 'Go to Album',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              navigation.openAlbumFromSong(context, activeSong);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: Icons.dashboard_customize_rounded,
                            label: 'Player Layout',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onShowPlayerLayout(context);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.gauge,
                            label: 'Playback Speed',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              SpeedBottomSheet.show(context, playerService);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.music,
                            label: 'Pitch',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              PitchBottomSheet.show(context, playerService);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.moonStar,
                            label: 'Sleep Timer',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              SleepTimerBottomSheet.show(context, playerService);
                            },
                          ),
                          _buildSongActionTile(
                            context: sheetContext,
                            icon: LucideIcons.share2,
                            label: 'Share',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) =>
                                    ShareBottomSheet(song: activeSong),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
    );
  }

  Widget _buildSongInfoChip(BuildContext context, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 9.0, 10.0),
        vertical: context.responsive(3.0, 3.5, 4.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(context.responsive(6.0, 7.0, 8.0)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: context.responsive(10.0, 11.0, 12.0),
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSongActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final iconSize = context.responsive(16.0, 17.0, 18.0);
    final containerSize = context.responsive(30.0, 32.0, 34.0);
    final borderRadius = context.responsive(8.0, 9.0, 10.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          context.responsive(10.0, 11.0, 12.0),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.responsive(10.0, 11.0, 12.0),
          ),
          child: Row(
            children: [
              Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsive(13.0, 14.0, 15.0),
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: context.responsive(14.0, 15.0, 16.0),
                color: context.adaptiveTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
