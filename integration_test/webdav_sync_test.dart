import 'dart:convert';
import 'dart:io';

import 'package:flick/data/database.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/services/sources/webdav_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Manual E2E against a live rclone WebDAV server:
//   rclone serve webdav --addr :8080 --user flick --pass flickpass --read-only <dir>
// Run: flutter test integration_test/webdav_sync_test.dart -d <device>
const _baseUrl = 'http://192.168.68.109:8080/';
const _username = 'flick';
const _password = 'flickpass';
const _serverId = 990255;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('syncs and streams special-char library from live WebDAV',
      (tester) async {
    await Database.init();

    final server = NetworkServerEntity()
      ..id = _serverId
      ..label = 'E2E rclone'
      ..protocol = 'webdav'
      ..baseUrl = _baseUrl
      ..username = _username
      ..token = base64Encode(utf8.encode(_password));

    try {
      await Database.instance.writeTxn(() async {
        await Database.networkServers.put(server);
      });

      final service = WebdavService.create();
      final progress = await service.syncLibrary(server).toList();
      expect(progress.last.isComplete, isTrue);
      expect(progress.last.songsFound, 5);

      final songs = await SongRepository().getSongsByRemoteServer(_serverId);
      expect(songs.map((s) => s.title).toList()..sort(), [
        '100% Real - Test',
        'Bawat Kaluluwa',
        'Track #1 - Test',
        'What? - Test',
        '照井順政 - Delirious',
      ]);

      final japanese =
          songs.firstWhere((s) => s.title == '照井順政 - Delirious');
      expect(japanese.remoteId, isNotNull);
      final cached = await service.stream(server, japanese.remoteId!,
          extension: 'flac');
      final bytes = await File(cached).readAsBytes();
      expect(bytes.length, 18035538);
      expect(bytes.sublist(0, 4), [0x66, 0x4C, 0x61, 0x43]);

      final bawat = songs.firstWhere((s) => s.title == 'Bawat Kaluluwa');
      expect(bawat.album, 'Album #1');
      final marker = bawat.albumArtPath!.substring('webdav-cover://'.length);
      final cover = await service.getCoverArt(server, marker);
      expect(cover[0], 0xFF);
      expect(cover[1], 0xD8);

      final stored = await Database.networkServers.get(_serverId);
      expect(stored!.lastSyncedAt, isNotNull);
    } finally {
      final repo = SongRepository();
      final rows = await repo.getSongsByRemoteServer(_serverId);
      if (rows.isNotEmpty) {
        await repo.deleteSongsByIds(rows.map((e) => e.id).toList());
      }
      await Database.instance.writeTxn(() async {
        await Database.networkServers.delete(_serverId);
      });
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
