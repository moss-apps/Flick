import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/services/sources/network_source_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/common/surface_icon_button.dart';
import 'package:flick/features/playlists/playlist_cover_actions.dart';
import 'package:flick/features/playlists/playlist_rename_action.dart';
import 'package:flick/features/playlists/screens/playlist_detail_screen.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/widgets/common/library_heading.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final currentSong = ref.watch(currentSongProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackground(song: currentSong),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref),
                Expanded(
                  child: playlistsAsync.when(
                    loading: () => _buildLoadingState(context),
                    error: (e, _) => _buildErrorState(context, e.toString()),
                    data: (state) => state.playlists.isEmpty
                        ? _buildEmptyState(context)
                        : _buildPlaylistsList(context, ref, state.playlists),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final count = ref.watch(playlistsCountProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
          SurfaceIconButton.icon(
            icon: LucideIcons.chevronLeft,
            onPressed: () => Navigator.of(context).pop(),
            iconColor: context.adaptiveTextPrimary,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LibraryHeading(
                  section: LibrarySection.playlists,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Text(
                  count == 0
                      ? l10n.yourCustomCollections
                      : l10n.playlist(count),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          SurfaceIconButton(
            child: PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                color: context.adaptiveTextPrimary,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
              ),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'create') {
                  _showCreatePlaylistDialog(context, ref);
                } else if (value == 'import_m3u') {
                  _importPlaylist(context, ref);
                } else if (value == 'sync_servers') {
                  _syncServerPlaylists(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(LucideIcons.plus, size: 18),
                      SizedBox(width: 8),
                      Text(l10n.englishForFilipino.createPlaylist),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import_m3u',
                  child: Row(
                    children: [
                      Icon(LucideIcons.fileUp, size: 18),
                      SizedBox(width: 8),
                      Text(l10n.englishForFilipino.importM3uM3u8),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sync_servers',
                  child: Row(
                    children: [
                      Icon(LucideIcons.refreshCw, size: 18),
                      SizedBox(width: 8),
                      Text(l10n.englishForFilipino.syncServerPlaylists),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.adaptiveTextSecondary),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.info,
              size: context.responsiveIcon(AppConstants.iconSizeXl),
              color: context.adaptiveTextTertiary,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              l10n.errorLoadingPlaylists,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.adaptiveTextSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 120,
              width: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 20,
                    child: Transform.rotate(
                      angle: 0.1,
                      child: _buildIllustrationCard(
                        context,
                        AppColors.glassBackground.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    child: Transform.rotate(
                      angle: -0.05,
                      child: _buildIllustrationCard(
                        context,
                        AppColors.glassBackground.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  _buildIllustrationCard(context, AppColors.glassBackground),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingXl),
            Text(
              l10n.noPlaylistsYet2,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              l10n.createYourFirstPlaylistToOrganize,
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

  Widget _buildIllustrationCard(BuildContext context, Color color) {
    return Container(
      width: 100,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.surfaceDark),
      ),
      child: Center(
        child: Icon(
          LucideIcons.listMusic,
          color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          size: context.responsiveIcon(AppConstants.iconSizeXl),
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: AppConstants.navBarHeight + 120),
        itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final serversAsync = ref.watch(networkServersProvider);
        String? serverLabel;
        final serverId = playlist.networkServerId;
        if (serverId != null && serversAsync.value != null) {
          for (final server in serversAsync.value!) {
            if (server.id == serverId) {
              serverLabel = server.label;
              break;
            }
          }
        }
        return _PlaylistCard(
          key: ValueKey(playlist.id),
          playlist: playlist,
          serverLabel: serverLabel,
          onTap: () {
            NavigationHelper.pushFade(
              context,
              (context) => PlaylistDetailScreen(playlist: playlist),
            );
          },
          onRename: () => PlaylistRenameAction.show(context, ref, playlist),
          onDelete: () async {
            final confirm = await _showDeleteDialog(context, ref);
            if (confirm == true) {
              await ref
                  .read(playlistsProvider.notifier)
                  .deletePlaylist(playlist.id);
            }
          },
          onSetCover: () =>
              PlaylistCoverActions.choose(context, ref, playlist),
          onRemoveCover: () =>
              PlaylistCoverActions.remove(context, ref, playlist),
          onExportM3u: () =>
              _exportPlaylist(context, ref, playlist, utf8: false),
          onExportM3u8: () =>
              _exportPlaylist(context, ref, playlist, utf8: true),
        );
      },
      ),
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context, WidgetRef ref) {
    return FlickDialogs.confirm(
      context,
      title: l10n.deletePlaylist,
      message: l10n.areYouSureYouWantTo,
      confirmLabel: l10n.delete,
      destructive: true,
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final serversAsync = ref.watch(networkServersProvider);
    final servers = serversAsync.value
            ?.where((s) => s.protocol == NetworkProtocol.subsonic)
            .toList() ??
        const [];
    // ponytail: 0 = "this device"; Isar ids start at 1 so it never collides.
    var serverId = 0;

    showFlickDialog(
      context: context,
      barrierLabel: l10n.createPlaylist,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => FlickDialog(
          title: l10n.createPlaylist,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlickTextField(
                controller: controller,
                hint: l10n.playlistName,
                autofocus: true,
                onSubmitted: (_) => _createPlaylist(
                  context,
                  ref,
                  controller.text,
                  controller,
                  dialogContext: dialogContext,
                  serverId: serverId,
                ),
              ),
              if (servers.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingMd),
                DropdownButtonFormField<int>(
                  initialValue: serverId,
                  decoration: InputDecoration(
                    labelText: l10n.storeOn,
                    labelStyle: TextStyle(color: context.adaptiveTextTertiary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  style: TextStyle(color: context.adaptiveTextPrimary),
                  dropdownColor: AppColors.surface,
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.thisDevice),
                    ),
                    for (final server in servers)
                      DropdownMenuItem(
                        value: server.id,
                        child: Text(server.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => serverId = value ?? 0),
                ),
              ],
            ],
          ),
          actions: [
            FlickDialogButton(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FlickDialogButton(
              label: l10n.create,
              style: FlickDialogButtonStyle.primary,
              onPressed: () => _createPlaylist(
                context,
                ref,
                controller.text,
                controller,
                dialogContext: dialogContext,
                serverId: serverId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist(
    BuildContext context,
    WidgetRef ref,
    String name,
    TextEditingController controller, {
    BuildContext? dialogContext,
    int serverId = 0,
  }) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(content: Text(l10n.englishForFilipino.pleaseEnterAPlaylistName)),
      );
      return;
    }

    final playlist = await ref.read(playlistsProvider.notifier).createPlaylist(
      name,
      serverId: serverId == 0 ? null : serverId,
    );

    if (playlist == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlickSnackBar(
          SnackBar(
            content: Text(l10n.englishForFilipino.aPlaylistWithThisNameAlready),
          ),
        );
      }
      return;
    }

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(content: Text(l10n.englishForFilipino.playlistCreated(playlist.name))),
      );
    }
  }

  Future<void> _syncServerPlaylists(BuildContext context, WidgetRef ref) async {
    try {
      final synced = await ref
          .read(playlistsProvider.notifier)
          .syncServerPlaylists();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(
          content: Text(
            synced == 0
                ? l10n.englishForFilipino.noServerPlaylistsFound
                : l10n.englishForFilipino.syncedPlaylistFromServers(synced),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showFlickSnackBar(SnackBar(content: Text(l10n.englishForFilipino.serverPlaylistSyncFailed(e))));
    }
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(playlistsProvider.notifier)
          .importM3uPlaylist();
      if (result == null || !context.mounted) return;

      final unmatchedText = result.unmatchedEntries > 0
          ? l10n.englishForFilipino.skippedUnmatchedEntr(
              result.unmatchedEntries,
            )
          : '';
      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(
          content: Text(
            l10n.englishForFilipino.importedWithSongs(result.playlist.name, result.importedSongs, unmatchedText),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showFlickSnackBar(SnackBar(content: Text(l10n.englishForFilipino.importFailed(e))));
    }
  }

  Future<void> _exportPlaylist(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist, {
    required bool utf8,
  }) async {
    try {
      final result = await ref
          .read(playlistsProvider.notifier)
          .exportPlaylistAsM3u(playlist.id, utf8: utf8);
      if (result == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(
          content: Text(
            l10n.englishForFilipino.exportedSongsTo(result.exportedSongs, result.fileName),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showFlickSnackBar(SnackBar(content: Text(l10n.englishForFilipino.exportFailed(e))));
    }
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final String? serverLabel;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;
  final VoidCallback onRemoveCover;
  final VoidCallback onExportM3u;
  final VoidCallback onExportM3u8;

  const _PlaylistCard({
    super.key,
    required this.playlist,
    this.serverLabel,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onSetCover,
    required this.onRemoveCover,
    required this.onExportM3u,
    required this.onExportM3u8,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              children: [
                _PlaylistCover(playlist: playlist),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
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
                        serverLabel == null
                            ? l10n.song2(playlist.songIds.length)
                            : l10n.song3(playlist.songIds.length, serverLabel!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    color: context.adaptiveTextTertiary,
                    size: context.responsiveIcon(AppConstants.iconSizeMd),
                  ),
                  color: AppColors.surface,
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                        break;
                      case 'set_cover':
                        onSetCover();
                        break;
                      case 'remove_cover':
                        onRemoveCover();
                        break;
                      case 'export_m3u':
                        onExportM3u();
                        break;
                      case 'export_m3u8':
                        onExportM3u8();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(LucideIcons.pencilLine, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.englishForFilipino.rename),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'set_cover',
                      child: Row(
                        children: [
                          Icon(LucideIcons.imagePlus, size: 18),
                          SizedBox(width: 8),
                          Text(
                            playlist.coverPath == null
                                ? l10n.englishForFilipino.setCover
                                : l10n.englishForFilipino.changeCover,
                          ),
                        ],
                      ),
                    ),
                    if (playlist.coverPath != null)
                      PopupMenuItem(
                        value: 'remove_cover',
                        child: Row(
                          children: [
                            Icon(LucideIcons.imageOff, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.englishForFilipino.removeCover),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'export_m3u',
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileDown, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.englishForFilipino.exportAsM3u),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_m3u8',
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileDown, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.englishForFilipino.exportAsM3u8),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            l10n.englishForFilipino.delete,
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistCover extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistCover({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverPath = playlist.coverPath;
    if (coverPath != null) {
      return _buildCustomCover(context, coverPath);
    }

    final songsAsync = ref.watch(songsProvider);

    return songsAsync.when(
      loading: () => _buildCoverPlaceholder(context),
      error: (_, __) => _buildCoverPlaceholder(context),
      data: (songsState) {
        final playlistSongs = songsState.songs
            .where((song) => playlist.songIds.contains(song.id))
            .toList();

        if (playlistSongs.isEmpty) {
          return _buildCoverPlaceholder(context);
        }

        final artworkPaths = playlistSongs
            .map((s) => s.albumArt)
            .where((art) => art != null && art.isNotEmpty)
            .cast<String>()
            .take(4)
            .toList();

        return _buildCoverGrid(context, artworkPaths);
      },
    );
  }

  Widget _buildCustomCover(BuildContext context, String coverPath) {
    final size = context.scaleSize(56);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedImageWidget(
          imagePath: coverPath,
          fit: BoxFit.cover,
          useThumbnail: true,
          thumbnailWidth: 112,
          thumbnailHeight: 112,
          placeholder: _buildPlaceholderIcon(context),
          errorWidget: _buildPlaceholderIcon(context),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(BuildContext context) {
    return Container(
      width: context.scaleSize(56),
      height: context.scaleSize(56),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.surfaceDark),
      ),
      child: const FlickArtworkPlaceholder(size: 28, opacity: 0.9),
    );
  }

  Widget _buildCoverGrid(BuildContext context, List<String> artworkPaths) {
    final size = context.scaleSize(56);

    if (artworkPaths.isEmpty) {
      return _buildCoverPlaceholder(context);
    }

    if (artworkPaths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedImageWidget(
            imagePath: artworkPaths[0],
            fit: BoxFit.cover,
            placeholder: _buildPlaceholderIcon(context),
            errorWidget: _buildPlaceholderIcon(context),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildGridArt(context, artworkPaths, size),
      ),
    );
  }

  Widget _buildGridArt(BuildContext context, List<String> artworkPaths, double size) {
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworkPaths.take(4).map((path) {
        return CachedImageWidget(
          imagePath: path,
          fit: BoxFit.cover,
          placeholder: Container(color: AppColors.surfaceLight),
          errorWidget: Container(color: AppColors.surfaceLight),
        );
      }).toList(),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: FlickArtworkPlaceholder(size: 28, opacity: 0.9),
      ),
    );
  }
}
