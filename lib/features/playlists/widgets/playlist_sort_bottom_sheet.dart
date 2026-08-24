import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Sort modes available inside a playlist detail view.
enum PlaylistSortOption {
  manual,
  dateAddedNewest,
  dateAddedOldest,
  title,
  artist,
}

extension PlaylistSortOptionX on PlaylistSortOption {
  String get label {
    switch (this) {
      case PlaylistSortOption.manual:
        return 'Manual Order';
      case PlaylistSortOption.dateAddedNewest:
        return 'Date Added (Newest)';
      case PlaylistSortOption.dateAddedOldest:
        return 'Date Added (Oldest)';
      case PlaylistSortOption.title:
        return 'Title';
      case PlaylistSortOption.artist:
        return 'Artist';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaylistSortOption.manual:
        return LucideIcons.gripVertical;
      case PlaylistSortOption.dateAddedNewest:
        return LucideIcons.calendarArrowDown;
      case PlaylistSortOption.dateAddedOldest:
        return LucideIcons.calendarArrowUp;
      case PlaylistSortOption.title:
        return LucideIcons.type;
      case PlaylistSortOption.artist:
        return LucideIcons.mic;
    }
  }
}

/// Sorts [songs] (provided in playlist order) by [option].
///
/// Manual order returns the songs untouched. Date-added sorts use
/// [Playlist.songAddedAt] when present; songs without a recorded timestamp
/// (legacy playlists, imported lists) fall back to their position in
/// [Playlist.songIds], which mirrors the add order.
List<Song> sortPlaylistSongs({
  required List<Song> songs,
  required Playlist playlist,
  required PlaylistSortOption option,
}) {
  if (option == PlaylistSortOption.manual) return List<Song>.from(songs);

  final ordered = List<Song>.from(songs);
  final indexOf = <String, int>{
    for (var i = 0; i < playlist.songIds.length; i++) playlist.songIds[i]: i,
  };

  ordered.sort((a, b) => _compare(a, b, indexOf, playlist.songAddedAt, option));
  return ordered;
}

int _compare(
  Song a,
  Song b,
  Map<String, int> indexOf,
  Map<String, DateTime> addedAt,
  PlaylistSortOption option,
) {
  switch (option) {
    case PlaylistSortOption.manual:
      return 0;
    case PlaylistSortOption.dateAddedNewest:
    case PlaylistSortOption.dateAddedOldest:
      return _compareAddedAt(
        a,
        b,
        indexOf,
        addedAt,
        newestFirst: option == PlaylistSortOption.dateAddedNewest,
      );
    case PlaylistSortOption.title:
      return _compareText(a.title, b.title, indexOf, a, b);
    case PlaylistSortOption.artist:
      return _compareText(a.artist, b.artist, indexOf, a, b);
  }
}

int _compareAddedAt(
  Song a,
  Song b,
  Map<String, int> indexOf,
  Map<String, DateTime> addedAt, {
  required bool newestFirst,
}) {
  final aAdded = addedAt[a.id];
  final bAdded = addedAt[b.id];
  final aIndex = indexOf[a.id] ?? 0;
  final bIndex = indexOf[b.id] ?? 0;

  // Undated entries are treated as the oldest; they sort below dated ones in
  // newest-first order and above them in oldest-first order.
  if (aAdded == null && bAdded != null) return newestFirst ? 1 : -1;
  if (aAdded != null && bAdded == null) return newestFirst ? -1 : 1;

  if (aAdded != null && bAdded != null) {
    final diff = newestFirst
        ? bAdded.compareTo(aAdded)
        : aAdded.compareTo(bAdded);
    if (diff != 0) return diff;
  }

  final indexDiff = newestFirst
      ? bIndex.compareTo(aIndex)
      : aIndex.compareTo(bIndex);
  return indexDiff;
}

int _compareText(
  String aText,
  String bText,
  Map<String, int> indexOf,
  Song a,
  Song b,
) {
  final diff = aText.toLowerCase().compareTo(bText.toLowerCase());
  if (diff != 0) return diff;
  return (indexOf[a.id] ?? 0).compareTo(indexOf[b.id] ?? 0);
}

class PlaylistSortBottomSheet extends StatelessWidget {
  final PlaylistSortOption currentSort;
  final ValueChanged<PlaylistSortOption> onSortChanged;

  const PlaylistSortBottomSheet({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  static void show(
    BuildContext context, {
    required PlaylistSortOption currentSort,
    required ValueChanged<PlaylistSortOption> onSortChanged,
  }) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PlaylistSortBottomSheet(
        currentSort: currentSort,
        onSortChanged: onSortChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'SORT BY'),
              const SizedBox(height: 8),
              ...PlaylistSortOption.values.map(
                (option) => _buildSortTile(context, option),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSortTile(BuildContext context, PlaylistSortOption option) {
    final isSelected = currentSort == option;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onSortChanged(option);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 20,
                color: isSelected
                    ? AppColors.accent
                    : context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
