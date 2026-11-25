import 'dart:async';
import 'dart:io';

import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/widget_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  const previewKeys = [
    WidgetSyncService.keyNext1Id,
    WidgetSyncService.keyNext1Title,
    WidgetSyncService.keyNext1Art,
    WidgetSyncService.keyNext2Id,
    WidgetSyncService.keyNext2Title,
    WidgetSyncService.keyNext2Art,
  ];
  const playbackProviders = [
    WidgetSyncService.miniPlayerProvider,
    WidgetSyncService.flagshipProvider,
    WidgetSyncService.compactProvider,
    WidgetSyncService.nowPlayingProvider,
    WidgetSyncService.replayProvider,
  ];
  final service = WidgetSyncService.instance;
  late Directory directory;
  late Map<String, Object?> saved;
  late List<String> writtenKeys;
  late List<String> updatedProviders;
  Future<void> Function(String key, Object? value)? beforeSave;

  Song song(String id, {String? art}) => Song(
    id: id,
    title: 'Title $id',
    artist: 'Artist $id',
    albumArt: art,
    duration: const Duration(seconds: 122),
    fileType: 'FLAC',
  );

  String localArt(String name) {
    final file = File('${directory.path}/$name.png');
    file.writeAsBytesSync([0]);
    return file.path;
  }

  Future<void> send(
    WidgetTester tester,
    PlayerState state, {
    Duration delay = Duration.zero,
  }) async {
    final before = updatedProviders.length;
    service.schedulePush(state);
    await tester.pump(delay);
    for (var attempt = 0; attempt < 30; attempt++) {
      if (updatedProviders.length == before + playbackProviders.length) {
        expect(updatedProviders.skip(before), playbackProviders);
        // Flush the continuation that records the successfully pushed snapshot.
        await tester.pump();
        return;
      }
      await tester.pump();
    }
    fail('Expected the playback widgets to refresh after a state change');
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('flick-widget-sync-');
    saved = {};
    writtenKeys = [];
    updatedProviders = [];
    beforeSave = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'setAppGroupId':
              return true;
            case 'saveWidgetData':
              final args = call.arguments as Map;
              final key = args['id'] as String;
              await beforeSave?.call(key, args['data']);
              saved[key] = args['data'];
              writtenKeys.add(key);
              return true;
            case 'updateWidget':
              final args = call.arguments as Map;
              updatedProviders.add(args['qualifiedAndroidName'] as String);
              return true;
            default:
              fail('Unexpected widget platform call: ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  testWidgets('publishes the actual first two upcoming covers', (tester) async {
    final currentArt = localArt('current');
    final firstArt = localArt('first');
    final secondArt = localArt('second');
    await send(
      tester,
      PlayerState(
        currentSong: song('current', art: currentArt),
        upNext: [
          song('first', art: firstArt),
          song('second', art: 'file://$secondArt'),
          song('third', art: localArt('third')),
        ],
      ),
    );

    expect(saved[WidgetSyncService.keyAlbumArt], currentArt);
    expect(saved[WidgetSyncService.keyNext1Id], 'first');
    expect(saved[WidgetSyncService.keyNext1Title], 'Title first');
    expect(saved[WidgetSyncService.keyNext1Art], firstArt);
    expect(saved[WidgetSyncService.keyNext2Id], 'second');
    expect(saved[WidgetSyncService.keyNext2Title], 'Title second');
    expect(saved[WidgetSyncService.keyNext2Art], secondArt);
    expect(saved[WidgetSyncService.keyQueueCount], 3);
  });

  testWidgets('a queue-only reorder refreshes without waiting for progress', (
    tester,
  ) async {
    final first = song('reorder-first', art: localArt('reorder-first'));
    final second = song('reorder-second', art: localArt('reorder-second'));
    final state = PlayerState(
      currentSong: song('reorder-current'),
      upNext: [first, second],
    );
    await send(tester, state);
    await send(tester, state.copyWith(upNext: [second, first]));

    expect(saved[WidgetSyncService.keyNext1Id], second.id);
    expect(saved[WidgetSyncService.keyNext1Art], second.albumArt);
    expect(saved[WidgetSyncService.keyNext2Id], first.id);
    expect(saved[WidgetSyncService.keyNext2Art], first.albumArt);
  });

  testWidgets('remote and missing artwork are never sent to native widgets', (
    tester,
  ) async {
    await send(
      tester,
      PlayerState(
        currentSong: song(
          'remote-current',
          art: 'https://example.com/cover.png',
        ),
        upNext: [
          song('remote-next', art: 'http://example.com/next.png'),
          song('missing-next', art: '${directory.path}/missing.png'),
        ],
      ),
    );

    expect(saved[WidgetSyncService.keyAlbumArt], '');
    expect(saved[WidgetSyncService.keyNext1Art], '');
    expect(saved[WidgetSyncService.keyNext2Art], '');
    expect(saved[WidgetSyncService.keyNext1Id], 'remote-next');
  });

  testWidgets('unchanged previews are not rewritten on playback updates', (
    tester,
  ) async {
    final state = PlayerState(
      currentSong: song('cached-current'),
      upNext: [song('cached-next', art: localArt('cached-next'))],
    );
    await send(tester, state);
    writtenKeys.clear();
    await send(tester, state.copyWith(isPlaying: true));

    expect(writtenKeys.where(previewKeys.contains), isEmpty);
    expect(saved[WidgetSyncService.keyIsPlaying], isTrue);
    expect(saved[WidgetSyncService.keyNext1Id], 'cached-next');
  });

  test('a delayed widget update cannot overwrite a newer skip', () async {
    final writingFirst = Completer<void>();
    final release = Completer<void>();
    beforeSave = (key, value) async {
      if (key == WidgetSyncService.keyTitle && value == 'Title first-skip') {
        writingFirst.complete();
        await release.future;
      }
    };

    final first = service.refreshPlayback(
      PlayerState(currentSong: song('first-skip')),
    );
    await writingFirst.future;
    final latest = service.refreshPlayback(
      PlayerState(currentSong: song('latest-skip')),
    );
    await pumpEventQueue();
    release.complete();
    await Future.wait([first, latest]);

    expect(saved[WidgetSyncService.keyTitle], 'Title latest-skip');
    expect(saved[WidgetSyncService.keySongId], 'latest-skip');
  });

  test('leaving the app keeps the pause button while audio plays', () async {
    await service.pushPaused(isPlaying: true);

    expect(saved[WidgetSyncService.keyIsPlaying], isTrue);
    expect(updatedProviders, contains(WidgetSyncService.nowPlayingProvider));
  });

  testWidgets('clears covers when the queue becomes empty', (tester) async {
    final state = PlayerState(
      currentSong: song('empty-current'),
      upNext: [song('empty-next', art: localArt('empty-next'))],
    );
    await send(tester, state);
    await send(tester, state.copyWith(upNext: []));

    for (final key in previewKeys) {
      expect(saved[key], '', reason: key);
    }
  });

  testWidgets('clears covers when no song is loaded, even with a stale queue', (
    tester,
  ) async {
    final state = PlayerState(
      currentSong: song('stopped-current'),
      upNext: [song('stopped-next', art: localArt('stopped-next'))],
    );
    await send(tester, state);
    await send(tester, state.copyWith(clearSong: true));

    expect(saved[WidgetSyncService.keyHasSong], isFalse);
    for (final key in previewKeys) {
      expect(saved[key], '', reason: key);
    }
  });

  testWidgets('picks up local artwork created after the first update', (
    tester,
  ) async {
    final path = '${directory.path}/late.png';
    final state = PlayerState(
      currentSong: song('late-current'),
      upNext: [song('late-next', art: path)],
    );
    await send(tester, state);
    expect(saved[WidgetSyncService.keyNext1Art], '');
    File(path).writeAsBytesSync([0]);
    await send(
      tester,
      state.copyWith(position: const Duration(seconds: 2)),
      delay: const Duration(seconds: 2),
    );

    expect(saved[WidgetSyncService.keyNext1Art], path);
  });

  testWidgets(
    'replay stats stay untouched when the library database is absent',
    (tester) async {
      await send(tester, PlayerState(currentSong: song('replay-offline')));

      expect(
        saved.keys.where((key) => key.startsWith('flick_widget_replay_')),
        isEmpty,
      );
    },
  );
}
