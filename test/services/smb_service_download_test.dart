import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flick/core/utils/app_log.dart';
import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/network_cache_service.dart';
import 'package:flick/services/sources/smb_failure.dart';
import 'package:flick/services/sources/smb_service.dart';
import 'package:flick/src/rust/api/smb_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late NetworkCacheService cache;
  late NetworkServerEntity server;
  late SmbService service;
  late StreamController<SmbProgress> progress;
  late Completer<String> started;
  var calls = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('smb_download_test');
    cache = NetworkCacheService(rootDirectory: root, sizeCapBytes: 100);
    server = NetworkServerEntity()
      ..id = 7
      ..baseUrl = 'smb://private-host/private-share/Albums'
      ..username = 'private-user'
      ..token = base64Encode(utf8.encode('private-password'));
    progress = StreamController<SmbProgress>();
    started = Completer<String>();
    calls = 0;
    service = SmbService.create(
      networkCache: cache,
      downloader:
          ({
            required host,
            required port,
            required share,
            required path,
            required user,
            required pass,
            required destPath,
          }) {
            calls++;
            started.complete(destPath);
            return progress.stream;
          },
    );
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  SmbProgress update(int received, int total, {bool complete = false}) =>
      SmbProgress(
        received: BigInt.from(received),
        total: BigInt.from(total),
        isComplete: complete,
      );

  test(
    'prefetch and interactive playback coalesce and both get original bytes',
    () async {
      final prefetch = service.stream(server, 'song.dsf', extension: 'dsf');
      final dest = await started.future;
      final values = <double>[];
      final playback = service.stream(
        server,
        'song.dsf',
        extension: 'dsf',
        onProgress: values.add,
      );
      final original = List.generate(32, (i) => i);
      await File(dest).writeAsBytes(original);
      progress.add(update(16, 32));
      progress.add(update(32, 32, complete: true));
      await progress.close();
      expect(await prefetch, dest);
      expect(await playback, dest);
      expect(calls, 1);
      expect(values, [0.5, 1.0]);
      expect(await File(dest).readAsBytes(), original);
      expect(await service.stream(server, 'song.dsf', extension: 'dsf'), dest);
      expect(calls, 1);
    },
  );

  test(
    'a throwing progress callback cannot abort or duplicate the transfer',
    () async {
      final half = Completer<void>();
      final first = service.stream(
        server,
        'song.flac',
        extension: 'flac',
        onProgress: (value) {
          if (value == 0.5 && !half.isCompleted) half.complete();
        },
      );
      final dest = await started.future;
      await File(dest).writeAsBytes([1, 2, 3, 4]);

      progress.add(update(2, 4));
      await half.future;

      // Joining after progress already exists exercises the catch-up path;
      // the completion event exercises the live listener path. Neither may
      // escape or cancel the shared transfer.
      final broken = service.stream(
        server,
        'song.flac',
        extension: 'flac',
        onProgress: (_) => throw StateError('broken UI callback'),
      );
      final alsoJoined = service.stream(
        server,
        'song.flac',
        extension: 'flac',
      );

      progress.add(update(4, 4, complete: true));
      await progress.close();

      expect(await first, dest);
      expect(await broken, dest);
      expect(await alsoJoined, dest);
      expect(calls, 1);
      expect(await File(dest).readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'cache extension is normalized and derived from the remote path',
    () async {
      final first = service.stream(server, 'album/song.FLAC');
      final dest = await started.future;
      expect(dest, endsWith('.flac'));
      await File(dest).writeAsBytes([1]);
      progress.add(update(1, 1, complete: true));
      await progress.close();
      expect(await first, dest);

      // A later caller with an explicit (differently cased/spaced) hint must
      // hit the same cached file instead of downloading it again.
      expect(
        await service.stream(server, 'album/song.FLAC', extension: ' FLAC '),
        dest,
      );
      expect(calls, 1);
    },
  );

  for (final terminal in [false, true]) {
    test(
      'rejects ${terminal ? 'wrong byte count' : 'missing completion'} and retries',
      () async {
        final result = service.stream(server, 'song.flac', extension: 'flac');
        final failure = expectLater(result, throwsA(isA<SmbFailure>()));
        final dest = await started.future;
        await File(dest).writeAsBytes([1, 2]);
        progress.add(update(2, 3, complete: terminal));
        await progress.close();
        await failure;
        expect(await File(dest).exists(), isFalse);
        // Same service must release its in-flight entry after failure.
        progress = StreamController<SmbProgress>();
        started = Completer<String>();
        final retry = service.stream(server, 'song.flac', extension: 'flac');
        await File(await started.future).writeAsBytes([1, 2, 3]);
        progress.add(update(3, 3, complete: true));
        await progress.close();
        expect(await retry, dest);
        expect(calls, 2);
      },
    );
  }

  test(
    'rejects an incorrect on-disk length despite a completion event',
    () async {
      final result = service.stream(server, 'song.flac');
      final failure = expectLater(result, throwsA(isA<SmbFailure>()));
      final dest = await started.future;
      await File(dest).writeAsBytes([1]);
      progress.add(update(3, 3, complete: true));
      await progress.close();
      await failure;
      expect(await File(dest).exists(), isFalse);
    },
  );

  test('interruption errors and diagnostics exclude private input', () async {
    final logStart = AppLog.instance.entries.length;
    final result = service.stream(server, 'private-file.flac');
    final failure = expectLater(
      result,
      throwsA(
        isA<SmbFailure>().having(
          (e) => e.toString(),
          'safe code',
          'SMB stage=download code=protocol',
        ),
      ),
    );
    final dest = await started.future;
    await File(dest).writeAsBytes([1]);
    progress.addError(
      Exception(
        'private-host private-share private-file private-user private-password',
      ),
    );
    await progress.close();
    await failure;
    final logs = AppLog.instance.entries
        .skip(logStart)
        .map((e) => e.message)
        .join('\n');
    expect(logs, contains('result=failed'));
    expect(logs, isNot(contains('private-')));
    expect(await File(dest).exists(), isFalse);
  });

  test(
    'bypasses legacy SMB partial files and enforces cap after download',
    () async {
      final legacy = await cache.stash(
        server.id,
        'song.flac',
        List.filled(80, 1),
        extension: 'flac',
      );
      final result = service.stream(server, 'song.flac', extension: 'flac');
      final dest = await started.future;
      expect(dest, isNot(legacy));
      await File(dest).writeAsBytes(List.filled(80, 2));
      progress.add(update(80, 80, complete: true));
      await progress.close();
      expect(await result, dest);
      expect(await File(legacy).exists(), isFalse);
      expect(await File(dest).length(), 80);
    },
  );

  test(
    'connection test receives configured root and keeps errors safe',
    () async {
      String? testedRoot;
      service = SmbService.create(
        networkCache: cache,
        downloader:
            ({
              required host,
              required port,
              required share,
              required path,
              required user,
              required pass,
              required destPath,
            }) => const Stream.empty(),
        connectionTest:
            ({
              required host,
              required port,
              required share,
              required user,
              required pass,
              required rootPath,
            }) async {
              testedRoot = rootPath;
              throw Exception('SMB stage=root code=not_found private-folder');
            },
      );
      expect(await service.ping(server), isFalse);
      expect(testedRoot, 'Albums');
      expect(service.lastPingError, contains('folder'));
      expect(service.lastPingError, isNot(contains('private-')));
      server.baseUrl = 'smb://private-host/';
      testedRoot = null;
      expect(await service.ping(server), isFalse);
      expect(testedRoot, isNull);
      expect(service.lastPingError, contains('share'));
      server.baseUrl = 'smb://private-host:bad/private-share';
      expect(await service.ping(server), isFalse);
      expect(service.lastPingError, isNot(contains('private-')));
    },
  );

  test('diagnostics only retain known native stages and codes', () {
    for (final (stage, code) in [
      ('connect', 'auth'),
      ('share', 'denied'),
      ('root', 'not_found'),
      ('read', 'denied'),
      ('download', 'timeout'),
      ('cache', 'storage'),
    ]) {
      final failure = SmbFailure.from(
        Exception('SMB stage=$stage code=$code private-user private-password'),
      );
      expect(failure.toString(), 'SMB stage=$stage code=$code');
      expect(failure.message, isNot(contains('private-')));
    }
    expect(
      SmbFailure.from(
        Exception('SMB stage=private-host code=private-password'),
      ).toString(),
      'SMB stage=download code=protocol',
    );
    expect(
      const SmbFailure('private-host', 'private-password').toString(),
      'SMB stage=download code=protocol',
    );
  });
}
