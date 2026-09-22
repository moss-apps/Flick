import 'package:test/test.dart';

import 'package:flick/services/library_scanner_service.dart' show ScanProgress;
import 'package:flick/services/scan_session_controller.dart';

ScanProgress _progress(int processed, int total) => ScanProgress(
  songsFound: processed,
  totalFiles: total,
  filesProcessed: processed,
);

void main() {
  late ScanSessionController controller;

  setUp(() {
    controller = ScanSessionController.instance;
    controller.end();
    controller.completed.value = false;
  });

  tearDown(() => controller.end());

  group('ScanSessionController', () {
    test('begin activates a non-minimized session with no progress', () {
      final generation = controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );

      expect(controller.isActive, isTrue);
      expect(controller.isVisible, isFalse);
      expect(controller.isCurrent(generation), isTrue);
      expect(controller.minimized.value, isFalse);
      expect(controller.progress.value, isNull);
      expect(controller.session.value?.title, 'Music');
      expect(controller.session.value?.kind, ScanSessionKind.scan);
    });

    test('update stores progress only for the current generation', () {
      final stale = controller.begin(
        title: 'Stale',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.end(stale);

      controller.update(stale, _progress(3, 10));
      expect(controller.progress.value, isNull);

      final generation = controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.update(generation, _progress(3, 10));
      expect(controller.progress.value?.filesProcessed, 3);

      controller.update(stale, _progress(9, 10));
      expect(controller.progress.value?.filesProcessed, 3);
    });

    test('overlayDismissed minimizes only the current generation', () {
      controller.overlayDismissed(0);
      expect(controller.minimized.value, isFalse);

      final generation = controller.begin(
        title: 'All Folders',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.overlayDismissed(generation);
      expect(controller.isVisible, isTrue);

      final next = controller.begin(
        title: 'Next',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      expect(controller.minimized.value, isFalse);
      controller.overlayDismissed(generation);
      expect(controller.minimized.value, isFalse);
      controller.overlayDismissed(next);
      expect(controller.isVisible, isTrue);
    });

    test('end clears session, progress, and minimized state', () {
      final generation = controller.begin(
        title: 'Preloading Audio',
        kind: ScanSessionKind.preload,
        onCancel: () {},
      );
      controller.update(generation, _progress(1, 5));
      controller.overlayDismissed(generation);

      controller.end(generation);

      expect(controller.isActive, isFalse);
      expect(controller.isVisible, isFalse);
      expect(controller.isCurrent(generation), isFalse);
      expect(controller.progress.value, isNull);
      expect(controller.session.value, isNull);
    });

    test('stale end cannot clear a newer session', () {
      final first = controller.begin(
        title: 'First',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      final second = controller.begin(
        title: 'Second',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );

      controller.end(first);

      expect(controller.isActive, isTrue);
      expect(controller.session.value?.title, 'Second');
      expect(controller.isCurrent(second), isTrue);
    });

    test('begin replaces a stale session and resets transient state', () {
      final first = controller.begin(
        title: 'First',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.overlayDismissed(first);
      controller.update(first, _progress(2, 4));

      controller.begin(
        title: 'Second',
        kind: ScanSessionKind.replayGain,
        onCancel: () {},
      );

      expect(controller.session.value?.title, 'Second');
      expect(controller.session.value?.kind, ScanSessionKind.replayGain);
      expect(controller.minimized.value, isFalse);
      expect(controller.progress.value, isNull);
    });

    test('cancel invokes the active session hook', () {
      var cancelled = false;
      controller.begin(
        title: 'ReplayGain Scan',
        kind: ScanSessionKind.replayGain,
        onCancel: () => cancelled = true,
      );

      controller.cancel();

      expect(cancelled, isTrue);
      // cancel() does not end the session; the owning flow does.
      expect(controller.isActive, isTrue);
    });

    test('stop cancels the hook and clears the session immediately', () {
      var cancelled = false;
      final generation = controller.begin(
        title: 'Preloading Audio',
        kind: ScanSessionKind.preload,
        onCancel: () => cancelled = true,
      );
      controller.update(generation, _progress(2, 6));
      controller.overlayDismissed(generation);

      controller.stop();

      expect(cancelled, isTrue);
      expect(controller.isActive, isFalse);
      expect(controller.isVisible, isFalse);
      expect(controller.isCurrent(generation), isFalse);
      expect(controller.progress.value, isNull);
    });

    test('requestSkip is ignored outside post-processing', () {
      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      final baseline = controller.skipRequests.value;

      controller.requestSkip();

      expect(controller.skipRequests.value, baseline);
    });

    test('requestSkip notifies while post-processing', () {
      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      final baseline = controller.skipRequests.value;
      controller.postProcessing.value = true;
      var notified = 0;
      void listener() => notified++;
      controller.skipRequests.addListener(listener);

      controller.requestSkip();

      expect(controller.skipRequests.value, baseline + 1);
      expect(notified, 1);
      controller.skipRequests.removeListener(listener);
    });

    test('end and begin reset post-processing', () {
      final generation = controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.postProcessing.value = true;
      controller.end(generation);
      expect(controller.postProcessing.value, isFalse);

      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.postProcessing.value = true;
      controller.begin(
        title: 'Replacement',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      expect(controller.postProcessing.value, isFalse);
    });

    test('markCompleted latches only for a live session', () {
      controller.markCompleted();
      expect(controller.completed.value, isFalse);

      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.markCompleted();
      expect(controller.completed.value, isTrue);
    });

    test('end keeps the completion latch so the pill can play its outro', () {
      final generation = controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.overlayDismissed(generation);
      controller.markCompleted();

      controller.end(generation);

      expect(controller.completed.value, isTrue);
      expect(controller.isActive, isFalse);

      controller.begin(
        title: 'Next',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      expect(controller.completed.value, isFalse);
    });
  });
}
