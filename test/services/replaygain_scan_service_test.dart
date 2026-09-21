import 'dart:io';
import 'dart:math' as math;

import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/services/replaygain_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rg_scan_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String localFile(String name) {
    return (File('${tempDir.path}/$name')..writeAsStringSync('x')).path;
  }

  SongEntity song({
    required String path,
    String? album,
    String? albumArtist,
    String artist = 'Artist',
    String? sourceType,
  }) {
    return SongEntity()
      ..filePath = path
      ..title = 'Title'
      ..artist = artist
      ..album = album
      ..albumArtist = albumArtist
      ..sourceType = sourceType;
  }

  test('progress never exceeds the candidate count (regression)', () async {
    final songs = [
      song(path: localFile('a.flac'), album: 'A'),
      song(path: localFile('b.flac'), album: 'A'),
      song(path: localFile('c.flac'), album: 'B'),
    ];

    final persisted = <String>[];
    final service = ReplayGainScanService(
      analyzer: (path) async => (lufs: -18.0, truePeakDb: -1.0),
      persistTags:
          (
            path, {
            required double trackGainDb,
            required double? trackPeak,
            required double albumGainDb,
            required double? albumPeak,
          }) async {
            persisted.add(path);
          },
    );

    final events = await service.scanLibrary(songs).toList();

    expect(events, isNotEmpty);
    expect(events.map((e) => e.total), everyElement(3));

    var previous = 0;
    for (final event in events) {
      expect(event.completed, inInclusiveRange(0, 3));
      expect(event.completed, greaterThanOrEqualTo(previous));
      previous = event.completed;
    }

    expect(events.last.completed, 3);
    expect(events.last.failed, 0);
    expect(events.last.isComplete, isTrue);
    expect(persisted.toSet(), songs.map((s) => s.filePath).toSet());
  });

  test('analysis pass walks 1..total, write pass holds at total', () async {
    final songs = [
      for (var i = 0; i < 3; i++)
        song(path: localFile('t$i.flac'), album: 'A'),
    ];

    final service = ReplayGainScanService(
      analyzer: (path) async => (lufs: -20.0, truePeakDb: null),
      persistTags:
          (
            path, {
            required double trackGainDb,
            required double? trackPeak,
            required double albumGainDb,
            required double? albumPeak,
          }) async {},
    );

    final events = await service.scanLibrary(songs).toList();

    expect(events.take(3).map((e) => e.completed), [1, 2, 3]);
    expect(events.take(3).map((e) => e.isComplete), everyElement(isFalse));
    expect(events.skip(3).map((e) => e.completed), everyElement(3));
    expect(events.last.isComplete, isTrue);
  });

  test('failed analysis counts toward progress but is not persisted', () async {
    final ok = song(path: localFile('ok.flac'), album: 'A');
    final bad = song(path: localFile('bad.flac'), album: 'A');

    final persisted = <String>[];
    final service = ReplayGainScanService(
      analyzer: (path) async =>
          path == bad.filePath ? null : (lufs: -18.0, truePeakDb: null),
      persistTags:
          (
            path, {
            required double trackGainDb,
            required double? trackPeak,
            required double albumGainDb,
            required double? albumPeak,
          }) async {
            persisted.add(path);
          },
    );

    final events = await service.scanLibrary([ok, bad]).toList();

    expect(events.last.completed, 2);
    expect(events.last.failed, 1);
    expect(persisted, [ok.filePath]);
  });

  test('album gain is the power average, track gain follows -18 LUFS',
      () async {
    final a1 = song(path: localFile('a1.flac'), album: 'A');
    final a2 = song(path: localFile('a2.flac'), album: 'A');
    final b1 = song(path: localFile('b1.flac'), album: 'B');

    final gains = <String, ({double trackGainDb, double albumGainDb})>{};
    final peaks = <String, double?>{};
    final service = ReplayGainScanService(
      analyzer: (path) async => switch (path) {
        final p when p == a1.filePath => (lufs: -20.0, truePeakDb: -6.0206),
        final p when p == a2.filePath => (lufs: -10.0, truePeakDb: 0.0),
        _ => (lufs: -18.0, truePeakDb: null),
      },
      persistTags:
          (
            path, {
            required double trackGainDb,
            required double? trackPeak,
            required double albumGainDb,
            required double? albumPeak,
          }) async {
            gains[path] = (trackGainDb: trackGainDb, albumGainDb: albumGainDb);
            peaks[path] = trackPeak;
          },
    );

    await service.scanLibrary([a1, a2, b1]).toList();

    final expectedAlbumLufs =
        10 *
        math.log(
          (math.pow(10, -20.0 / 10) + math.pow(10, -10.0 / 10)) / 2,
        ) /
        math.ln10;

    expect(gains[a1.filePath]!.trackGainDb, closeTo(2.0, 1e-9));
    expect(gains[a2.filePath]!.trackGainDb, closeTo(-8.0, 1e-9));
    expect(gains[b1.filePath]!.trackGainDb, closeTo(0.0, 1e-9));
    expect(
      gains[a1.filePath]!.albumGainDb,
      closeTo(-18.0 - expectedAlbumLufs, 1e-6),
    );
    expect(
      gains[a2.filePath]!.albumGainDb,
      closeTo(gains[a1.filePath]!.albumGainDb, 1e-9),
    );
    expect(gains[b1.filePath]!.albumGainDb, closeTo(0.0, 1e-9));
    expect(peaks[a1.filePath], closeTo(0.5, 1e-3));
    expect(peaks[a2.filePath], closeTo(1.0, 1e-9));
  });

  test('skips network sources and missing local files', () async {
    final local = song(path: localFile('local.flac'), album: 'A');
    final remote = song(
      path: 'https://example.com/stream.flac',
      album: 'A',
      sourceType: 'subsonic',
    );
    final missing = song(path: '${tempDir.path}/gone.flac', album: 'A');

    final service = ReplayGainScanService(
      analyzer: (path) async => (lufs: -18.0, truePeakDb: null),
      persistTags:
          (
            path, {
            required double trackGainDb,
            required double? trackPeak,
            required double albumGainDb,
            required double? albumPeak,
          }) async {},
    );

    final events = await service.scanLibrary([local, remote, missing]).toList();

    expect(events.last.total, 1);
    expect(events.last.completed, 1);
    expect(events.last.isComplete, isTrue);
  });
}
