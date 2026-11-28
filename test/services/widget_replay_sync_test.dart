import 'dart:async';
import 'dart:io';

import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/widget_replay_snapshot.dart';
import 'package:flick/services/widget_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements RecentlyPlayedRepository {
  final changes = StreamController<void>.broadcast();
  final recaps = <String, ListeningRecap>{};
  final requests = <DateTime>[];
  Future<ListeningRecap> Function(DateTime)? load;
  bool unavailable = false;

  @override
  Future<ListeningRecap> getListeningRecap(
    ListeningRecapPeriod period, {
    DateTime? now,
  }) async {
    final date = now!;
    requests.add(date);
    if (unavailable) throw StateError('Library unavailable');
    return load != null
        ? load!(date)
        : recaps[WidgetReplaySnapshot.dayKey(date)] ?? _recap(date);
  }

  @override
  Stream<void> watchHistory() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ListeningRecap _recap(
  DateTime date, {
  int plays = 0,
  int minutes = 0,
  List<String> covers = const [],
}) {
  final period = ListeningRecapPeriod.daily;
  final range = period.rangeFor(date);
  final albums = [
    for (var i = 0; i < covers.length; i++)
      RankedRecapAlbum(
        album: 'Album $i',
        artist: 'Artist $i',
        plays: plays,
        uniqueSongs: 1,
        listeningTime: Duration(minutes: minutes),
        lastPlayedAt: date,
        representativeSong: Song(
          id: '$i',
          title: 'Song $i',
          artist: 'Artist $i',
          albumArt: covers[i],
          duration: const Duration(minutes: 3),
          fileType: 'FLAC',
        ),
      ),
  ];
  return ListeningRecap(
    period: period,
    start: range.start,
    endExclusive: range.endExclusive,
    totalPlays: plays,
    totalListeningTime: Duration(minutes: minutes),
    uniqueSongs: plays,
    uniqueArtists: plays,
    activeDays: plays == 0 ? 0 : 1,
    peakHour: null,
    topSong: null,
    topArtist: null,
    topAlbum: albums.firstOrNull,
    topSongs: const [],
    topArtists: const [],
    topAlbums: albums,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  late _Repository repository;
  late WidgetSyncService service;
  late DateTime now;
  late Directory directory;
  late Map<String, Object?> saved;
  late List<String> written;
  late List<Object?> publishedDays;
  late List<String> updates;

  String cover(String name) {
    final file = File('${directory.path}/$name.png')..writeAsBytesSync([0]);
    return file.path;
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump();
    }
  }

  setUp(() {
    now = DateTime(2026, 10, 14, 12);
    directory = Directory.systemTemp.createTempSync('flick-replay-test-');
    repository = _Repository();
    service = WidgetSyncService(
      replayRepository: () => repository,
      clock: () => now,
    );
    saved = {};
    written = [];
    publishedDays = [];
    updates = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setAppGroupId') return true;
          final args = call.arguments as Map;
          if (call.method == 'saveWidgetData') {
            final key = args['id'] as String;
            saved[key] = args['data'];
            written.add(key);
            if (key == WidgetSyncService.keyReplayDay) {
              publishedDays.add(args['data']);
            }
            return true;
          }
          if (call.method == 'updateWidget') {
            updates.add(args['qualifiedAndroidName'] as String);
            return true;
          }
          fail('Unexpected widget call ${call.method}');
        });
  });

  tearDown(() async {
    service.stopReplaySync();
    await repository.changes.close();
    directory.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'publishes local statistics, comparable deltas and only three local covers',
    () async {
      final first = cover('first');
      final second = cover('second with spaces');
      repository.recaps['2026-10-14'] = _recap(
        now,
        plays: 20,
        minutes: 48,
        covers: [
          first,
          Uri.file(second).toString(),
          'https://example.com/cover',
          cover('fourth'),
        ],
      );
      repository.recaps['2026-10-13'] = _recap(
        DateTime(2026, 10, 13),
        plays: 10,
        minutes: 40,
      );
      await service.refreshReplay();

      expect(saved[WidgetSyncService.keyReplayTimeMs], 48 * 60000);
      expect(saved[WidgetSyncService.keyReplayPlays], 20);
      expect(saved[WidgetSyncService.keyReplayTimeDelta], 20);
      expect(saved[WidgetSyncService.keyReplayPlaysDelta], 100);
      expect(saved[WidgetSyncService.keyReplayCover1], first);
      expect(saved[WidgetSyncService.keyReplayCover2], second);
      expect(saved[WidgetSyncService.keyReplayCover3], '');
      expect(publishedDays, ['', '2026-10-14']);
      expect(written.last, WidgetSyncService.keyReplayDay);
      expect(repository.requests.last, DateTime(2026, 10, 13));
      expect(updates, [WidgetSyncService.replayProvider]);
      expect(WidgetReplaySnapshot.localCover(directory.path), '');
      expect(WidgetReplaySnapshot.localCover('content://library/cover'), '');
    },
  );

  test('unchanged snapshots are neither rewritten nor redrawn', () async {
    repository.recaps['2026-10-14'] = _recap(now, plays: 1, minutes: 3);
    await service.refreshReplay();
    written.clear();
    updates.clear();
    await service.refreshReplay();
    expect(written, isEmpty);
    expect(updates, isEmpty);
    expect(
      saved[WidgetSyncService.keyReplayPlaysDelta],
      WidgetReplaySnapshot.unknownDelta,
    );
  });

  testWidgets(
    'committed repeat plays and history clearing refresh without a song change',
    (tester) async {
      service.startReplaySync();
      await service.refreshReplay();
      updates.clear();
      repository.recaps['2026-10-14'] = _recap(
        now,
        plays: 2,
        minutes: 6,
        covers: [cover('repeat')],
      );
      repository.changes.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await flush(tester);
      expect(saved[WidgetSyncService.keyReplayPlays], 2);
      expect(updates, [WidgetSyncService.replayProvider]);

      repository.recaps.clear();
      repository.changes.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await flush(tester);
      expect(saved[WidgetSyncService.keyReplayPlays], 0);
      expect(saved[WidgetSyncService.keyReplayTimeMs], 0);
      expect(saved[WidgetSyncService.keyReplayCover1], '');
      expect(
        saved[WidgetSyncService.keyReplayTimeDelta],
        WidgetReplaySnapshot.unknownDelta,
      );
      service.stopReplaySync();
    },
  );

  testWidgets('position updates never poll listening history', (tester) async {
    final state = PlayerState();
    service.schedulePush(state);
    await flush(tester);
    expect(repository.requests.length, 2);
    now = now.add(const Duration(minutes: 5));
    service.schedulePush(state.copyWith(position: const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(repository.requests.length, 2);
    service.stopReplaySync();
  });

  testWidgets('midnight publishes the new local day even while paused', (
    tester,
  ) async {
    now = DateTime(2026, 10, 14, 23, 59, 59);
    repository.recaps['2026-10-14'] = _recap(now, plays: 1, minutes: 3);
    service.startReplaySync();
    await service.refreshReplay();
    now = DateTime(2026, 10, 15);
    await tester.pump(const Duration(seconds: 1));
    await flush(tester);
    expect(saved[WidgetSyncService.keyReplayDay], '2026-10-15');
    expect(saved[WidgetSyncService.keyReplayPlays], 0);
    expect(repository.requests.last, DateTime(2026, 10, 14));
    service.stopReplaySync();
    final requestCount = repository.requests.length;
    repository.changes.add(null);
    await tester.pump(const Duration(seconds: 1));
    await flush(tester);
    expect(repository.requests.length, requestCount);
  });

  test(
    'overlapping refreshes serialize writes and finish on the latest history',
    () async {
      final firstToday = Completer<ListeningRecap>();
      var waiting = true;
      repository.recaps['2026-10-14'] = _recap(now, plays: 3, minutes: 9);
      repository.load = (date) {
        if (date.day == 14 && waiting) {
          waiting = false;
          return firstToday.future;
        }
        return Future.value(
          repository.recaps[WidgetReplaySnapshot.dayKey(date)] ?? _recap(date),
        );
      };
      final first = service.refreshReplay();
      await Future<void>.delayed(Duration.zero);
      final second = service.refreshReplay();
      await Future<void>.delayed(Duration.zero);
      firstToday.complete(_recap(now, plays: 1, minutes: 3));
      await Future.wait([first, second]);
      expect(saved[WidgetSyncService.keyReplayPlays], 3);
      expect(publishedDays, ['', '2026-10-14', '', '2026-10-14']);
    },
  );

  test(
    'temporary query failures preserve the last snapshot and retry',
    () async {
      repository.recaps['2026-10-14'] = _recap(now, plays: 1, minutes: 3);
      await service.refreshReplay();
      repository.unavailable = true;
      written.clear();
      updates.clear();
      await service.refreshReplay();
      expect(written, isEmpty);
      expect(updates, isEmpty);
      expect(saved[WidgetSyncService.keyReplayPlays], 1);
      repository.unavailable = false;
      repository.recaps['2026-10-14'] = _recap(now, plays: 2, minutes: 6);
      await service.refreshReplay();
      expect(saved[WidgetSyncService.keyReplayPlays], 2);
    },
  );

  test(
    'the Replay look is pushed alongside the existing widget customization',
    () async {
      for (final look in ['acid', 'night', 'signal', 'artwork']) {
        updates.clear();
        await service.pushCustomization(AppPreferences(widgetReplayLook: look));
        expect(saved[WidgetSyncService.keyReplayLook], look);
        expect(updates, [
          WidgetSyncService.miniPlayerProvider,
          WidgetSyncService.flagshipProvider,
          WidgetSyncService.compactProvider,
          WidgetSyncService.nowPlayingProvider,
          WidgetSyncService.replayProvider,
        ]);
      }
    },
  );
}
