import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';

class AddToPlaylistSheet extends ConsumerWidget {
  final List<Song> songs;
  const AddToPlaylistSheet({super.key, required this.songs});

  Song get song => songs.first;

  static Future<void> show(BuildContext context, Song song) {
    return showSongs(context, [song]);
  }

  static Future<void> showSongs(BuildContext context, List<Song> songs) {
    return showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistSheet(songs: songs),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.listPlus,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                songs.length == 1
                    ? 'Add to Playlist'
                    : 'Add ${songs.length} Songs to Playlist',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer(
            builder: (context, ref, _) {
              final playlistsAsync = ref.watch(playlistsProvider);
              return playlistsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Error loading playlists',
                  style: TextStyle(color: context.adaptiveTextTertiary),
                ),
                data: (state) {
                  if (state.playlists.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No playlists yet.\nCreate one in the Playlists tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.adaptiveTextTertiary,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = state.playlists[index];
                        final songIds = songs.map((s) => s.id).toSet();
                        final isAlreadyAdded = playlist.songIds
                            .where((id) => songIds.contains(id))
                            .length >=
                            songs.length;
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const FlickArtworkPlaceholder(
                              size: 22,
                              opacity: 0.9,
                            ),
                          ),
                          title: Text(
                            playlist.name,
                            style: TextStyle(
                              color: context.adaptiveTextPrimary,
                              fontFamily: 'ProductSans',
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.songIds.length} songs',
                            style: TextStyle(
                              color: context.adaptiveTextTertiary,
                              fontFamily: 'ProductSans',
                            ),
                          ),
                          trailing: isAlreadyAdded
                              ? Icon(
                                  LucideIcons.check,
                                  color: AppColors.accent,
                                )
                              : null,
                          onTap: isAlreadyAdded
                              ? null
                              : () async {
                                  final notifier = ref.read(
                                    playlistsProvider.notifier,
                                  );
                                  for (final s in songs) {
                                    await notifier.addSongToPlaylist(
                                      playlist.id,
                                      s.id,
                                      song: s,
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          songs.length == 1
                                              ? 'Added to "${playlist.name}"'
                                              : 'Added ${songs.length} songs to "${playlist.name}"',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
