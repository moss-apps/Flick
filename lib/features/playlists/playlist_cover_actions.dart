import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/features/playlists/screens/playlist_cover_editor_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';

/// Gallery picker + editor flow shared by the playlist list and detail menus.
class PlaylistCoverActions {
  PlaylistCoverActions._();

  static Future<bool> choose(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    String? pickedPath;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      pickedPath = picked?.path;
    } catch (_) {
      messenger?.showFlickSnackBar(
        SnackBar(
          content: Text(l10n.englishForFilipino.couldNotUpdatePlaylistCover),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (pickedPath == null || !context.mounted) return false;
    return _editSource(context, ref, playlist, pickedPath);
  }

  /// Opens the editor with the playlist's current cover instead of the
  /// gallery picker. Falls back to [choose] when there is no cover yet.
  static Future<bool> edit(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final coverPath = playlist.coverPath;
    if (coverPath == null || coverPath.isEmpty) {
      return choose(context, ref, playlist);
    }
    return _editSource(context, ref, playlist, coverPath);
  }

  static Future<bool> _editSource(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    String sourcePath,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    String? editedPath;
    var changed = false;

    try {
      if (!context.mounted) return false;
      editedPath = await NavigationHelper.pushFade<String>(
        context,
        (_) => PlaylistCoverEditorScreen(sourcePath: sourcePath),
      );
      if (editedPath == null) return false;

      final success = await ref
          .read(playlistsProvider.notifier)
          .setPlaylistCover(playlist.id, editedPath);
      changed = success;
      messenger?.showFlickSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.englishForFilipino.playlistCoverUpdated
                : l10n.englishForFilipino.couldNotUpdatePlaylistCover,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger?.showFlickSnackBar(
        SnackBar(
          content: Text(l10n.englishForFilipino.couldNotUpdatePlaylistCover),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (editedPath != null) {
        try {
          final file = File(editedPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Temporary editor output; the OS will eventually clean it up.
        }
      }
    }

    return changed;
  }

  static Future<bool> remove(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final success = await ref
        .read(playlistsProvider.notifier)
        .removePlaylistCover(playlist.id);

    messenger?.showFlickSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.englishForFilipino.playlistCoverRemoved
              : l10n.englishForFilipino.couldNotUpdatePlaylistCover,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return success;
  }
}
