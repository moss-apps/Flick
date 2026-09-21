import 'package:test/test.dart';

import 'package:flick/services/artwork_backfill_tracker.dart';

void main() {
  group('ArtworkBackfillTracker', () {
    late ArtworkBackfillTracker tracker;

    setUp(() => tracker = ArtworkBackfillTracker());

    test('awaitFolder resolves immediately when nothing is pending', () async {
      await tracker.awaitFolder('/music');
      expect(tracker.hasPending, isFalse);
      expect(tracker.progress.value, isNull);
    });

    test('awaitFolder waits until the folder is finished', () async {
      final token = tracker.begin('/music');
      var done = false;
      final future = tracker.awaitFolder('/music').then((_) => done = true);

      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(tracker.hasPending, isTrue);

      tracker.finish('/music', token);
      await future;
      expect(done, isTrue);
      expect(tracker.hasPending, isFalse);
    });

    test('awaitAll waits for every pending folder', () async {
      final first = tracker.begin('/a');
      final second = tracker.begin('/b');
      var done = false;
      final future = tracker.awaitAll().then((_) => done = true);

      tracker.finish('/a', first);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      tracker.finish('/b', second);
      await future;
      expect(done, isTrue);
    });

    test('setProgress aggregates across folders and finish clears', () {
      final first = tracker.begin('/a');
      final second = tracker.begin('/b');
      tracker.setProgress('/a', first, 1, 4);
      tracker.setProgress('/b', second, 0, 6);

      expect(tracker.progress.value?.completed, 1);
      expect(tracker.progress.value?.total, 10);

      tracker.finish('/a', first);
      expect(tracker.progress.value?.completed, 0);
      expect(tracker.progress.value?.total, 6);

      tracker.finish('/b', second);
      expect(tracker.progress.value, isNull);
    });

    test('a stale token cannot disturb the current entry', () {
      final stale = tracker.begin('/music');
      final current = tracker.begin('/music');

      tracker.finish('/music', stale);
      expect(tracker.hasPending, isTrue);

      tracker.setProgress('/music', stale, 5, 5);
      expect(tracker.progress.value, isNull);

      tracker.finish('/music', current);
      expect(tracker.hasPending, isFalse);
    });
  });
}
