import 'package:flick/models/playlist.dart';
import 'package:flick/services/playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Playlist _playlist({String? sourcePath}) => Playlist(
  id: 'p1',
  name: 'Test',
  createdAt: DateTime(2024),
  sourcePath: sourcePath,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Playlist network source parsing', () {
    test('local playlists have no network identity', () {
      final playlist = _playlist();
      expect(playlist.isNetworkSource, isFalse);
      expect(playlist.networkServerId, isNull);
      expect(playlist.networkRemoteId, isNull);
    });

    test('parses serverId and remoteId from subsonic sourcePath', () {
      final playlist = _playlist(sourcePath: 'subsonic://7/pl-42');
      expect(playlist.isNetworkSource, isTrue);
      expect(playlist.networkServerId, 7);
      expect(playlist.networkRemoteId, 'pl-42');
    });

    test('remoteId may contain slashes', () {
      final playlist = _playlist(sourcePath: 'subsonic://7/a/b/c');
      expect(playlist.networkServerId, 7);
      expect(playlist.networkRemoteId, 'a/b/c');
    });

    test('non-subsonic sourcePaths stay local', () {
      final playlist = _playlist(sourcePath: 'content://documents/foo.m3u');
      expect(playlist.isNetworkSource, isFalse);
      expect(playlist.networkServerId, isNull);
    });
  });

  group('network playlist mirrors', () {
    test('upsertNetworkPlaylist creates then updates in place', () async {
      final service = PlaylistService();

      final created = await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'pl-1',
        name: 'Driving',
        songIds: const ['a', 'b'],
      );
      expect(created.id, 'subsonic:7:pl-1');
      expect(created.sourcePath, 'subsonic://7/pl-1');
      expect(created.songIds, ['a', 'b']);

      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'pl-1',
        name: 'Driving v2',
        songIds: const ['a', 'b', 'c'],
      );

      final playlists = await service.getPlaylists();
      expect(playlists, hasLength(1));
      final updated = playlists.single;
      expect(updated.id, 'subsonic:7:pl-1');
      expect(updated.name, 'Driving v2');
      expect(updated.songIds, ['a', 'b', 'c']);
    });

    test('mirrors survive a reload from prefs', () async {
      final service = PlaylistService();
      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'pl-1',
        name: 'Driving',
      );

      final reloaded = PlaylistService();
      final playlists = await reloaded.getPlaylists();
      expect(playlists, hasLength(1));
      expect(playlists.single.networkRemoteId, 'pl-1');
    });

    test('removeStaleNetworkPlaylists drops only stale mirrors', () async {
      final service = PlaylistService();
      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'keep',
        name: 'Keep',
      );
      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'stale',
        name: 'Stale',
      );
      await service.upsertNetworkPlaylist(
        serverId: 8,
        remoteId: 'other',
        name: 'Other server',
      );

      await service.removeStaleNetworkPlaylists('7', {
        'subsonic://7/keep',
      });

      final playlists = await service.getPlaylists();
      expect(playlists.map((p) => p.name), ['Keep', 'Other server']);
    });

    test('removeNetworkPlaylistsForServer purges the whole server', () async {
      final service = PlaylistService();
      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'a',
        name: 'A',
      );
      await service.upsertNetworkPlaylist(
        serverId: 7,
        remoteId: 'b',
        name: 'B',
      );
      await service.upsertNetworkPlaylist(
        serverId: 8,
        remoteId: 'c',
        name: 'C',
      );

      await service.removeNetworkPlaylistsForServer('7');

      final playlists = await service.getPlaylists();
      expect(playlists.map((p) => p.name), ['C']);
    });
  });
}
