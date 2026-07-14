import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';

class AddToPlaylistSheet extends ConsumerWidget {
  final Song song;
  const AddToPlaylistSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistSheet(song: song),
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
                'Add to Playlist',
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
                        final isAlreadyAdded = playlist.songIds.contains(
                          song.id,
                        );
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.music,
                              color: context.adaptiveTextSecondary,
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
                                  await ref
                                      .read(playlistsProvider.notifier)
                                      .addSongToPlaylist(
                                        playlist.id,
                                        song.id,
                                        song: song,
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added to "${playlist.name}"',
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
