import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';
import 'package:flick/features/songs/widgets/song_actions_bottom_sheet.dart';

/// Compact trailing button that opens [SongActionsBottomSheet], mirroring the
/// library screen's long-press gesture on a song.
class SongActionsButton extends StatelessWidget {
  final Song song;
  final VoidCallback? onRemoveFromPlaylist;
  final Color? color;

  const SongActionsButton({
    super.key,
    required this.song,
    this.onRemoveFromPlaylist,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        LucideIcons.ellipsisVertical,
        color: color ?? context.adaptiveTextTertiary,
        size: 20,
      ),
      tooltip: 'Song actions',
      visualDensity: VisualDensity.compact,
      onPressed: () => SongActionsBottomSheet.show(
        context,
        song,
        onRemoveFromPlaylist: onRemoveFromPlaylist,
      ),
    );
  }
}
