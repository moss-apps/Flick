import 'dart:convert';

import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/last_played_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSongRepository extends Fake implements SongRepository {
  _FakeSongRepository(this.songs);

  final List<Song> songs;

  @override
  Future<List<Song>> getAllSongs() async => songs;
}

const _songA = Song(
  id: 'last-played-a',
  title: 'Last Played A',
  artist: 'Test Artist',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: '/tmp/last-played-a.flac',
  sampleRate: 44100,
  bitDepth: 16,
);

const _songB = Song(
  id: 'last-played-b',
  title: 'Last Played B',
  artist: 'Test Artist',
  duration: Duration(minutes: 4),
  fileType: 'FLAC',
  filePath: '/tmp/last-played-b.flac',
  sampleRate: 44100,
  bitDepth: 16,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LastPlayedService createService() => LastPlayedService(
    songRepository: _FakeSongRepository(const [_songA, _songB]),
  );

  test('saves song, position, playlist, index, and playing state', () async {
    final lastPlayed = createService();

    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 42),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 1,
      wasPlaying: true,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_played_song_id'), _songB.id);
    expect(prefs.getInt('last_played_position_ms'), 42000);
    expect(prefs.getBool('last_played_was_playing'), isTrue);
    expect(jsonDecode(prefs.getString('last_played_playlist_song_ids')!), [
      _songA.id,
      _songB.id,
    ]);
    expect(prefs.getInt('last_played_playlist_index'), 1);
  });

  test('position-only save preserves existing playlist context', () async {
    final lastPlayed = createService();
    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 10),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 1,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_played_playlist_song_ids', '["sentinel"]');
    await prefs.setInt('last_played_playlist_index', 9);

    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 50),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 1,
      wasPlaying: true,
    );

    expect(prefs.getString('last_played_playlist_song_ids'), '["sentinel"]');
    expect(prefs.getInt('last_played_playlist_index'), 9);
    expect(prefs.getInt('last_played_position_ms'), 50000);
    expect(prefs.getBool('last_played_was_playing'), isTrue);
  });

  test('changed playlist rewrites the persisted JSON', () async {
    final lastPlayed = createService();
    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 10),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 1,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_played_playlist_song_ids', '["sentinel"]');

    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 20),
      playlistSongIds: [_songB.id],
      currentIndex: 0,
    );

    expect(jsonDecode(prefs.getString('last_played_playlist_song_ids')!), [
      _songB.id,
    ]);
    expect(prefs.getInt('last_played_playlist_index'), 0);
  });

  test('index-only change updates the index without rewriting JSON', () async {
    final lastPlayed = createService();
    await lastPlayed.saveLastPlayed(
      _songA.id,
      const Duration(seconds: 10),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 0,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_played_playlist_song_ids', '["sentinel"]');
    await prefs.setInt('last_played_playlist_index', 7);

    await lastPlayed.saveLastPlayed(
      _songB.id,
      const Duration(seconds: 20),
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 1,
    );

    expect(prefs.getString('last_played_playlist_song_ids'), '["sentinel"]');
    expect(prefs.getInt('last_played_playlist_index'), 1);
  });

  test('empty or null playlist clears the persisted context', () async {
    final lastPlayed = createService();
    await lastPlayed.saveLastPlayed(
      _songA.id,
      Duration.zero,
      playlistSongIds: [_songA.id, _songB.id],
      currentIndex: 0,
    );

    final prefs = await SharedPreferences.getInstance();
    await lastPlayed.saveLastPlayed(_songA.id, Duration.zero);
    expect(prefs.getString('last_played_playlist_song_ids'), isNull);
    expect(prefs.getInt('last_played_playlist_index'), isNull);

    await lastPlayed.saveLastPlayed(
      _songA.id,
      Duration.zero,
      playlistSongIds: [_songA.id],
      currentIndex: 0,
    );
    await lastPlayed.saveLastPlayed(
      _songA.id,
      Duration.zero,
      playlistSongIds: const [],
    );
    expect(prefs.getString('last_played_playlist_song_ids'), isNull);
    expect(prefs.getInt('last_played_playlist_index'), isNull);
  });

  test(
    'round trip restores playlist order, index, position, and state',
    () async {
      final lastPlayed = createService();
      await lastPlayed.saveLastPlayed(
        _songA.id,
        const Duration(seconds: 42),
        playlistSongIds: [_songB.id, _songA.id],
        currentIndex: 1,
        wasPlaying: true,
      );

      final restored = await lastPlayed.getLastPlayed();

      expect(restored, isNotNull);
      expect(restored!.song.id, _songA.id);
      expect(restored.position, const Duration(seconds: 42));
      expect(restored.playlist!.map((song) => song.id).toList(), [
        _songB.id,
        _songA.id,
      ]);
      expect(restored.playlistIndex, 1);
      expect(restored.wasPlaying, isTrue);
    },
  );

  test('clearLastPlayed resets the cache for later saves', () async {
    final lastPlayed = createService();
    await lastPlayed.saveLastPlayed(
      _songA.id,
      Duration.zero,
      playlistSongIds: [_songA.id],
      currentIndex: 0,
    );

    await lastPlayed.clearLastPlayed();
    expect(await lastPlayed.getLastPlayed(), isNull);

    await lastPlayed.saveLastPlayed(
      _songA.id,
      Duration.zero,
      playlistSongIds: [_songA.id],
      currentIndex: 0,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('last_played_playlist_song_ids')!), [
      _songA.id,
    ]);
  });
}
