import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/services/sources/network_source_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/common/surface_icon_button.dart';
import 'package:flick/features/playlists/playlist_cover_actions.dart';
import 'package:flick/features/playlists/playlist_rename_action.dart';
import 'package:flick/features/playlists/screens/playlist_detail_screen.dart';
import 'package:flick/features/playlists/widgets/playlist_preview_card.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/widgets/common/library_heading.dart';

const _playlistSidePadding = AppConstants.spacingMd;

final _playlistGridViewProvider =
    AsyncNotifierProvider<_PlaylistGridView, bool>(_PlaylistGridView.new);

class _PlaylistGridView extends AsyncNotifier<bool> {
  static const _prefKey = 'playlist_grid_view';
  bool _saving = false;

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> toggle() async {
    final current = state.value;
    if (current == null || _saving) return;
    _saving = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (await prefs.setBool(_prefKey, !current) && ref.mounted) {
        state = AsyncData(!current);
      }
    } finally {
      _saving = false;
    }
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final currentSong = ref.watch(currentSongProvider);
    final gridView = ref.watch(_playlistGridViewProvider).value;

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
                _buildHeader(context, ref, gridView),
                Expanded(
                  child: playlistsAsync.when(
                    loading: () => _buildLoadingState(context),
                    error: (e, _) => _buildErrorState(context, e.toString()),
                    data: (state) => state.playlists.isEmpty
                        ? _buildEmptyState(context)
                        : _buildPlaylists(ref, state.playlists, gridView ?? false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool? gridView) {
    final count = ref.watch(playlistsCountProvider);
    final showGrid = gridView ?? false;
    final copy = context.l10n.englishForFilipino;

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
            child: IconButton(
              icon: Icon(
                showGrid ? LucideIcons.list : LucideIcons.layoutGrid,
                color: context.adaptiveTextPrimary,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
              ),
              tooltip: showGrid ? copy.viewAsList : copy.viewAsGrid,
              onPressed: gridView == null
                  ? null
                  : () => ref.read(_playlistGridViewProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
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

  Widget _buildPlaylists(
    WidgetRef ref,
    List<Playlist> playlists,
    bool showGrid,
  ) {
    final servers = ref.watch(networkServersProvider).value ?? [];
    final serverLabels = {for (final server in servers) server.id: server.label};
    final songs = showGrid ? ref.watch(songsProvider).value?.songs : null;
    final songById = <String, Song>{
      if (songs != null)
        for (final song in songs) song.id: song,
    };

    Widget buildItem(BuildContext context, int index, {double? artworkHeight}) {
      final playlist = playlists[index];
      final serverLabel = serverLabels[playlist.networkServerId];

      void openPlaylist() {
        NavigationHelper.pushFade(
          context,
          (context) => PlaylistDetailScreen(playlist: playlist),
        );
      }

      final actions = _PlaylistActionsMenu(
        hasCustomCover: playlist.coverPath != null,
        onArtwork: artworkHeight != null,
        onRename: () => PlaylistRenameAction.show(context, ref, playlist),
        onDelete: () async {
          final confirm = await _showDeleteDialog(context, ref);
          if (confirm) {
            await ref
                .read(playlistsProvider.notifier)
                .deletePlaylist(playlist.id);
          }
        },
        onSetCover: () => PlaylistCoverActions.choose(context, ref, playlist),
        onRemoveCover: () => PlaylistCoverActions.remove(context, ref, playlist),
        onExportM3u: () => _exportPlaylist(context, ref, playlist, utf8: false),
        onExportM3u8: () => _exportPlaylist(context, ref, playlist, utf8: true),
      );

      return artworkHeight == null
          ? _PlaylistListTile(
              key: ValueKey(playlist.id),
              playlist: playlist,
              serverLabel: serverLabel,
              onTap: openPlaylist,
              actions: actions,
            )
          : PlaylistPreviewCard(
              key: ValueKey(playlist.id),
              preview: PlaylistPreview.fromPlaylist(
                playlist,
                songById,
                context.l10n.englishForFilipino,
              ),
              artworkHeight: artworkHeight,
              songCount: playlist.songIds.length,
              serverLabel: serverLabel,
              onTap: openPlaylist,
              actions: actions,
            );
    }

    const bottomInset = AppConstants.navBarHeight + 120.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: showGrid
          ? LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppConstants.spacingMd;
                const columnCount = 2;
                const gridInsets = 2 * _playlistSidePadding + spacing;
                final cardWidth =
                    (constraints.maxWidth - gridInsets) / columnCount;
                final artworkHeight = (cardWidth - 2 * spacing).clamp(
                  0.0,
                  PlaylistPreviewCard.defaultArtworkHeight,
                );

                return GridView.builder(
                  key: const PageStorageKey('playlists_grid'),
                  padding: const EdgeInsets.fromLTRB(
                    _playlistSidePadding,
                    AppConstants.spacingXs,
                    _playlistSidePadding,
                    bottomInset,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: PlaylistPreviewCard.heightFor(
                      context,
                      artworkHeight,
                    ),
                  ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) =>
                      buildItem(context, index, artworkHeight: artworkHeight),
                );
              },
            )
          : ListView.builder(
              key: const PageStorageKey('playlists_list'),
              padding: const EdgeInsets.only(bottom: bottomInset),
              itemCount: playlists.length,
              itemBuilder: buildItem,
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
    // The creation dialog is an English surface in Taglish. English and
    // Chinese still receive their own copy.
    final l10n = context.l10n.englishForFilipino;
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

class _PlaylistListTile extends StatelessWidget {
  final Playlist playlist;
  final String? serverLabel;
  final VoidCallback onTap;
  final Widget actions;

  const _PlaylistListTile({
    super.key,
    required this.playlist,
    this.serverLabel,
    required this.onTap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _playlistSidePadding,
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
                _PlaylistCover(
                  key: PageStorageKey('playlist-artwork-${playlist.id}'),
                  playlist: playlist,
                ),
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
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistActionsMenu extends StatelessWidget {
  final bool hasCustomCover;
  final bool onArtwork;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;
  final VoidCallback onRemoveCover;
  final VoidCallback onExportM3u;
  final VoidCallback onExportM3u8;

  const _PlaylistActionsMenu({
    required this.hasCustomCover,
    required this.onArtwork,
    required this.onRename,
    required this.onDelete,
    required this.onSetCover,
    required this.onRemoveCover,
    required this.onExportM3u,
    required this.onExportM3u8,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.englishForFilipino;
    return PopupMenuButton<VoidCallback>(
      icon: Icon(
        LucideIcons.ellipsisVertical,
        color: onArtwork ? Colors.white : context.adaptiveTextTertiary,
        size: onArtwork ? 18 : context.responsiveIcon(AppConstants.iconSizeMd),
      ),
      padding: onArtwork ? EdgeInsets.zero : const EdgeInsets.all(8),
      color: AppColors.surface,
      tooltip: l10n.moreActions,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        _item(LucideIcons.pencilLine, l10n.rename, onRename),
        const PopupMenuDivider(),
        _item(
          LucideIcons.imagePlus,
          hasCustomCover ? l10n.changeCover : l10n.setCover,
          onSetCover,
        ),
        if (hasCustomCover)
          _item(LucideIcons.imageOff, l10n.removeCover, onRemoveCover),
        const PopupMenuDivider(),
        _item(LucideIcons.fileDown, l10n.exportAsM3u, onExportM3u),
        _item(LucideIcons.fileDown, l10n.exportAsM3u8, onExportM3u8),
        const PopupMenuDivider(),
        _item(LucideIcons.trash2, l10n.delete, onDelete, color: Colors.red),
      ],
    );
  }

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String label,
    VoidCallback action, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCover extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistCover({super.key, required this.playlist});

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
      primary: false,
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
