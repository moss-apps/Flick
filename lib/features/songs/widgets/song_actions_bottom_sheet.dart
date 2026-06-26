import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/songs/screens/metadata_editor_screen.dart';
import 'package:flick/features/songs/widgets/album_art_picker_bottom_sheet.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom sheet with actions for a song (add to playlist, favorites, view metadata, etc.)
class SongActionsBottomSheet extends ConsumerWidget {
  final Song song;
  final BuildContext rootContext;
  final VoidCallback? onSelect;

  const SongActionsBottomSheet({
    super.key,
    required this.song,
    required this.rootContext,
    this.onSelect,
  });

  /// Show the song actions bottom sheet
  static Future<void> show(
    BuildContext context,
    Song song, {
    VoidCallback? onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        child: SongActionsBottomSheet(
          song: song,
          rootContext: context,
          onSelect: onSelect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isSongFavoriteProvider(song.id));

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: AppConstants.spacingMd),
          _buildSongHeader(context),
          const SizedBox(height: AppConstants.spacingMd),
          _buildActionTile(
            context: context,
            icon: LucideIcons.heart,
            highlighted: isFavorite,
            label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onTap: () async {
              await ref
                  .read(favoritesProvider.notifier)
                  .toggleFavorite(song.id);
              PlayerService().refreshNotificationState();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          if (onSelect != null)
            _buildActionTile(
              context: context,
              icon: LucideIcons.checkCheck,
              label: 'Select',
              onTap: () {
                Navigator.pop(context);
                onSelect?.call();
              },
            ),
          _buildActionTile(
            context: context,
            icon: LucideIcons.listPlus,
            label: 'Add to Queue',
            onTap: () async {
              await ref.read(playerProvider.notifier).addToQueue(song);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Queued "${song.title}"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          _buildActionTile(
            context: context,
            icon: LucideIcons.listMusic,
            label: 'Add to Playlist',
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(context);
            },
          ),
          _buildActionTile(
            context: context,
            icon: LucideIcons.image,
            label: 'Set Album Art',
            onTap: () {
              Navigator.pop(context);
              unawaited(
                Future<void>.delayed(
                  Duration.zero,
                  () => AlbumArtPickerBottomSheet.show(rootContext, song),
                ),
              );
            },
          ),
          if (song.filePath != null &&
              song.startOffsetMs == null &&
              !song.isExternal)
            _buildActionTile(
              context: context,
              icon: LucideIcons.pencil,
              label: 'Edit Metadata',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => MetadataEditorScreen(song: song),
                  ),
                ).then((saved) {
                  if (saved == true && rootContext.mounted) {
                    ref.invalidate(songsProvider);
                  }
                });
              },
            ),
          _buildActionTile(
            context: context,
            icon: LucideIcons.info,
            label: 'View Metadata',
            onTap: () {
              Navigator.pop(context);
              _showMetadataSheet(context);
            },
          ),
          if (song.filePath != null && !song.isExternal)
            _buildActionTile(
              context: context,
              icon: LucideIcons.share2,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                unawaited(Share.shareXFiles([XFile(song.filePath!)]));
              },
            ),
          const SizedBox(height: AppConstants.spacingSm),
          Divider(height: 1, color: AppColors.glassBorderStrong),
          const SizedBox(height: AppConstants.spacingSm),
          _buildActionTile(
            context: context,
            icon: LucideIcons.trash2,
            label: 'Delete Song',
            onTap: () => _showDeleteWarning(context, ref),
            highlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorderStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
      ),
    );
  }

  Widget _buildSongHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 68,
            height: 68,
            child: CachedImageWidget(
              imagePath: song.albumArt,
              audioSourcePath: song.filePath,
              fit: BoxFit.cover,
              useThumbnail: true,
              thumbnailWidth: 136,
              thumbnailHeight: 136,
              placeholder: const ColoredBox(
                color: AppColors.surfaceLight,
                child: Icon(
                  LucideIcons.music,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ),
              errorWidget: const ColoredBox(
                color: AppColors.surfaceLight,
                child: Icon(
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
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 14,
                  color: context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(context, song.formattedDuration),
                  _buildInfoChip(context, song.fileType.toUpperCase()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppColors.accent.withValues(alpha: 0.16)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: highlighted
                      ? AppColors.accent
                      : context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: context.adaptiveTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AppBottomSheetSurface(
          maxHeightRatio: 0.72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppConstants.spacingMd),
              Row(
                children: [
                  Icon(
                    LucideIcons.listPlus,
                    color: sheetContext.adaptiveTextSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    'Add to Playlist',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: sheetContext.adaptiveTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Flexible(
                fit: FlexFit.loose,
                child: Consumer(
                  builder: (context, sheetRef, _) {
                    final playlistsAsync = sheetRef.watch(playlistsProvider);
                    return playlistsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppConstants.spacingXl),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingXl),
                        child: Text('Error loading playlists: $error'),
                      ),
                      data: (state) {
                        if (state.playlists.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(
                              AppConstants.spacingXl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.listMusic,
                                  size: 48,
                                  color: context.adaptiveTextTertiary
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: AppConstants.spacingMd),
                                Text(
                                  'No playlists yet',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                color: sheetContext.adaptiveTextSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppConstants.spacingLg),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final rootContext = Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).context;
                                    Navigator.pop(context);
                                    _showCreatePlaylistDialog(rootContext);
                                  },
                                  icon: const Icon(LucideIcons.plus),
                                  label: const Text('Create Playlist'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView(
                          shrinkWrap: true,
                          children: [
                            _buildActionTile(
                              context: context,
                              icon: LucideIcons.plus,
                              label: 'Create New Playlist',
                              onTap: () {
                                final rootContext = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).context;
                                Navigator.pop(context);
                                _showCreatePlaylistDialog(rootContext);
                              },
                            ),
                            Divider(
                              height: 1,
                              color: AppColors.glassBorderStrong,
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                            ...state.playlists.map((playlist) {
                              return _buildActionTile(
                                context: context,
                                icon: LucideIcons.listMusic,
                                label: playlist.name,
                                onTap: () async {
                                  await sheetRef
                                      .read(playlistsProvider.notifier)
                                      .addSongToPlaylist(playlist.id, song.id, song: song);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added to ${playlist.name}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    final container = ProviderScope.containerOf(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<void> createAndAddSong(String value) async {
          final playlistName = value.trim();
          if (playlistName.isEmpty) return;

          final playlist = await container
              .read(playlistsProvider.notifier)
              .createPlaylist(playlistName);

          if (playlist == null) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('A playlist with this name already exists'),
                ),
              );
            }
            return;
          }

          if (!dialogContext.mounted) return;

          await container
              .read(playlistsProvider.notifier)
              .addSongToPlaylist(playlist.id, song.id, song: song);

          if (!dialogContext.mounted) return;

          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Created ${playlist.name} and added song')),
          );
        }

        return AlertDialog(
          title: const Text('Create Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: createAndAddSong,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await createAndAddSong(controller.text);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showMetadataSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AppBottomSheetSurface(
          maxHeightRatio: 0.72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppConstants.spacingMd),
              Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 20,
                    color: sheetContext.adaptiveTextSecondary,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    'Song Metadata',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: sheetContext.adaptiveTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMetadataRow(sheetContext, 'Title', song.title),
                      _buildMetadataRow(sheetContext, 'Artist', song.artist),
                      if (song.album != null)
                        _buildMetadataRow(sheetContext, 'Album', song.album!),
                      if (song.albumArtist != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Album Artist',
                          song.albumArtist!,
                        ),
                      if (song.genre != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Genre',
                          song.genre!,
                        ),
                      if (song.year != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Year',
                          song.year!.toString(),
                        ),
                      if (song.trackNumber != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Track',
                          song.trackNumber!.toString(),
                        ),
                      if (song.discNumber != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Disc',
                          song.discNumber!.toString(),
                        ),
                      _buildMetadataRow(
                        sheetContext,
                        'Duration',
                        song.formattedDuration,
                      ),
                      _buildMetadataRow(
                        sheetContext,
                        'Format',
                        song.fileType.toUpperCase(),
                      ),
                      if (song.resolution != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Resolution',
                          song.resolution!,
                        ),
                      if (song.filePath != null)
                        _buildMetadataRow(
                          sheetContext,
                          'File Path',
                          song.filePath!,
                        ),
                      if (song.dateAdded != null)
                        _buildMetadataRow(
                          sheetContext,
                          'Date Added',
                          '${song.dateAdded!.year}-${song.dateAdded!.month.toString().padLeft(2, '0')}-${song.dateAdded!.day.toString().padLeft(2, '0')}',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteWarning(BuildContext sheetContext, WidgetRef ref) {
    final canDeleteFile = song.filePath != null &&
        song.filePath!.isNotEmpty &&
        !song.isExternal;

    showDialog(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Song?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
              '"${song.title}" by ${song.artist}',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: sheetContext.adaptiveTextSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              canDeleteFile
                  ? 'Remove the database entry or delete the file from your device. This cannot be undone.'
                  : 'Remove this song from your library. The file on your device will not be affected.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteSong(ref, sheetContext, deleteFile: false);
            },
            child: const Text('Remove from Library'),
          ),
          if (canDeleteFile)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteSong(ref, sheetContext, deleteFile: true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Delete File'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSong(
    WidgetRef ref,
    BuildContext sheetContext, {
    required bool deleteFile,
  }) async {
    final songId = int.tryParse(song.id);
    if (songId == null) return;

    // Capture repository before async work so we don't need `ref` later.
    final repository = ref.read(songRepositoryProvider);

    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    if (!rootContext.mounted) return;

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    await repository.deleteSong(songId);

    if (deleteFile && song.filePath != null) {
      var deleted = false;
      try {
        deleted = await MusicFolderService.deleteDocument(
          folderTreeUri: song.folderUri ?? song.filePath!,
          filePath: song.filePath!,
        );
      } catch (_) {}

      if (!deleted) {
        try {
          final file = File(song.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
          deleted = true;
        } catch (_) {}
      }

      if (deleted) {
        await MusicFolderService.removeFromMediaStore(song.filePath!);
      }
    }

    if (rootContext.mounted) {
      Navigator.of(rootContext).pop();
    }

    if (rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text(
            deleteFile
                ? 'Deleted "${song.title}"'
                : 'Removed "${song.title}" from library',
          ),
        ),
      );
    }
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
