import 'package:flick/services/mediastore_observer_service.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late int scanCalls;

  setUp(() {
    now = DateTime(2026);
    scanCalls = 0;
  });

  MediaStoreObserverService makeService() => MediaStoreObserverService(
        scanAllFolders: () async* {
          scanCalls++;
        },
        clock: () => now,
      );

  group('MediaStoreObserverService resume rescan', () {
    test('cold start: rescan runs after resume', () async {
      makeService().notifyResumed();
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(scanCalls, 1);
    });

    test('brief app switch: no catch-up rescan', () async {
      final service = makeService();
      service.notifyPaused();
      now = now.add(const Duration(seconds: 30));
      service.notifyResumed();
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(scanCalls, 0);
    });

    test('long background: catch-up rescan still runs', () async {
      final service = makeService();
      service.notifyPaused();
      now = now.add(const Duration(minutes: 2));
      service.notifyResumed();
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(scanCalls, 1);
    });
  });
}
