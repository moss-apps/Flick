import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';

/// Rename dialog shared by the playlist list and detail menus.
class PlaylistRenameAction {
  PlaylistRenameAction._();

  static Future<bool> show(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;

    final name = await FlickDialogs.input(
      context,
      title: l10n.rename,
      hintText: l10n.playlistName,
      initialValue: playlist.name,
      confirmLabel: l10n.save,
    );
    if (name == null || name == playlist.name) return false;
    if (!context.mounted) return false;

    final success = await ref
        .read(playlistsProvider.notifier)
        .renamePlaylist(playlist.id, name);

    messenger?.showFlickSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.englishForFilipino.playlistRenamed(name) : l10n.englishForFilipino.couldNotRenamePlaylist,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return success;
  }
}
