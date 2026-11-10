import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/orbit_card_blur_preloader.dart';

final _songs = List.generate(
  60,
  (index) => Song(
    id: '$index',
    title: 'Song $index',
    artist: 'Artist',
    duration: const Duration(minutes: 4),
    fileType: 'FLAC',
  ),
);
const _size = Size(320, 130);

void main() {
  test('warms the focused cover and four beyond the visible range', () async {
    final seen = <int>[];
    final preloader = OrbitCardBlurPreloader(
      preload: (song, size) async {
        expect(size, _size);
        seen.add(int.parse(song.id));
      },
    );
    addTearDown(preloader.dispose);

    Future<void> update() => preloader.update(
      songs: _songs,
      centerIndex: 20,
      visibleItems: 5,
      cardSize: _size,
    );
    await update();
    expect(seen, [20, 21, 19, 22, 18, 23, 17, 24, 16, 25, 15, 26, 14]);
    await update();
    expect(seen, hasLength(13), reason: 'Unchanged frames do not repeat work.');
  });

  test(
    'a reversal replaces stale queued covers without parallel work',
    () async {
      final seen = <int>[];
      final started = Completer<void>();
      final release = Completer<void>();
      var active = 0;
      final preloader = OrbitCardBlurPreloader(
        preload: (song, _) async {
          expect(++active, 1);
          final index = int.parse(song.id);
          seen.add(index);
          if (index == 40) {
            started.complete();
            await release.future;
          }
          active--;
        },
      );
      addTearDown(preloader.dispose);
      final work = preloader.update(
        songs: _songs,
        centerIndex: 40,
        visibleItems: 5,
        cardSize: _size,
      );
      await started.future;
      final latest = preloader.update(
        songs: _songs,
        centerIndex: 20,
        visibleItems: 5,
        cardSize: _size,
      );
      release.complete();
      await Future.wait([work, latest]);
      expect(seen.take(4), [40, 20, 19, 21]);
      expect(seen, hasLength(14));
      expect(seen.skip(1), everyElement(inInclusiveRange(14, 26)));
    },
  );

  test('disposal stops queued work and ignores later updates', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final seen = <String>[];
    final preloader = OrbitCardBlurPreloader(
      preload: (song, _) async {
        seen.add(song.id);
        started.complete();
        await release.future;
      },
    );
    final work = preloader.update(
      songs: _songs,
      centerIndex: 20,
      visibleItems: 5,
      cardSize: _size,
    );
    await started.future;
    preloader.dispose();
    release.complete();
    await work;
    await preloader.update(
      songs: _songs,
      centerIndex: 30,
      visibleItems: 5,
      cardSize: _size,
    );
    expect(seen, ['20']);
  });

  test(
    'empty lists, boundaries and a failed cover do not wedge loading',
    () async {
      final seen = <String>[];
      final preloader = OrbitCardBlurPreloader(
        preload: (song, _) async {
          seen.add(song.id);
          if (song.id == '0') throw StateError('Unavailable cover');
        },
      );
      addTearDown(preloader.dispose);
      await preloader.update(
        songs: [],
        centerIndex: 0,
        visibleItems: 5,
        cardSize: _size,
      );
      await preloader.update(
        songs: _songs,
        centerIndex: 0,
        visibleItems: 5,
        cardSize: _size,
      );
      expect(seen, ['0', '1', '2', '3', '4', '5', '6']);
    },
  );
}
