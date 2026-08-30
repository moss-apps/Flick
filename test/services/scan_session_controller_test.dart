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
  });

  tearDown(() => controller.end());

  group('ScanSessionController', () {
    test('begin activates a non-minimized session with no progress', () {
      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );

      expect(controller.isActive, isTrue);
      expect(controller.isVisible, isFalse);
      expect(controller.minimized.value, isFalse);
      expect(controller.progress.value, isNull);
      expect(controller.session.value?.title, 'Music');
      expect(controller.session.value?.kind, ScanSessionKind.scan);
    });

    test('update stores progress only while a session is active', () {
      controller.update(_progress(3, 10));
      expect(controller.progress.value, isNull);

      controller.begin(
        title: 'Music',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.update(_progress(3, 10));
      expect(controller.progress.value?.filesProcessed, 3);
    });

    test('overlayDismissed minimizes only an active session', () {
      controller.overlayDismissed();
      expect(controller.minimized.value, isFalse);

      controller.begin(
        title: 'All Folders',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.overlayDismissed();
      expect(controller.isVisible, isTrue);
    });

    test('end clears session, progress, and minimized state', () {
      controller.begin(
        title: 'Preloading Audio',
        kind: ScanSessionKind.preload,
        onCancel: () {},
      );
      controller.update(_progress(1, 5));
      controller.overlayDismissed();

      controller.end();

      expect(controller.isActive, isFalse);
      expect(controller.isVisible, isFalse);
      expect(controller.progress.value, isNull);
      expect(controller.session.value, isNull);
    });

    test('begin replaces a stale session and resets transient state', () {
      controller.begin(
        title: 'First',
        kind: ScanSessionKind.scan,
        onCancel: () {},
      );
      controller.overlayDismissed();
      controller.update(_progress(2, 4));

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
  });
}
