import 'package:flutter/material.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/features/artists/screens/artist_detail_screen.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';

class PlayerNavigation {
  final PlayerService playerService;
  final SongRepository songRepository;

  const PlayerNavigation({
    required this.playerService,
    required this.songRepository,
  });

  Future<void> queueSong(BuildContext context, Song song) async {
    await playerService.addToQueue(song);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued "${song.title}"'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View queue',
          onPressed: () {
            NavigationHelper.navigateToQueue(context);
          },
        ),
      ),
    );
  }

  Future<void> openQueue(BuildContext context) async {
    await NavigationHelper.navigateToQueue(context);
  }

  Future<void> openArtistFromSong(BuildContext context, Song song) async {
    final artistName = song.artist.trim();
    if (artistName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist is not available for this song')),
      );
      return;
    }

    final artistMap = await songRepository.getSongsByArtist();
    final artistSongs = artistMap[artistName];
    if (!context.mounted) return;

    if (artistSongs == null || artistSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load artist songs')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(
          artistName: artistName,
          songs: artistSongs,
          artistArt: _firstArt(artistSongs),
          artistArtSourcePath: _firstSourcePath(artistSongs),
          playerService: playerService,
        ),
      ),
    );
  }

  Future<void> openAlbumFromSong(BuildContext context, Song song) async {
    final albumGroup = await songRepository.getAlbumGroupForSong(song);
    if (!context.mounted) return;

    if (albumGroup == null || albumGroup.songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load album songs')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          albumName: albumGroup.albumName,
          albumArtist: albumGroup.albumArtist,
          songs: albumGroup.songs,
          albumArt: _firstArt(albumGroup.songs),
          albumArtSourcePath: _firstSourcePath(albumGroup.songs),
          playerService: playerService,
        ),
      ),
    );
  }

  }

String? _firstArt(List<Song> songs) {
  for (final item in songs) {
    final art = item.albumArt;
    if (art != null && art.isNotEmpty) {
      return art;
    }
  }
  return null;
}

String? _firstSourcePath(List<Song> songs) {
  for (final item in songs) {
    final filePath = item.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return filePath;
    }
  }
  return null;
}
