import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/services/audio_preload_service.dart' show PreloadProgress;
import 'package:flick/services/library_scanner_service.dart' show ScanProgress;
import 'package:flick/services/scan_session_controller.dart';
import 'package:flick/widgets/common/floating_scan_progress.dart';

const _bubbleKey = ValueKey('floating_scan_bubble');
const _cardKey = ValueKey('floating_scan_card');

ScanProgress _progress(int processed, int total) => ScanProgress(
  songsFound: processed,
  totalFiles: total,
  filesProcessed: processed,
  currentFile: '/music/track.flac',
);

Widget _host(
  ValueNotifier<PreloadProgress?> autoProgress, {
  VoidCallback? onCancelAutoPreload,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(
    body: FloatingScanProgress(
      autoPreloadProgress: autoProgress,
      onCancelAutoPreload: onCancelAutoPreload ?? () {},
    ),
  ),
);

double _opacity(WidgetTester tester, Key key) =>
    tester.widget<AnimatedOpacity>(find.byKey(key)).opacity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = ScanSessionController.instance;
  late ValueNotifier<PreloadProgress?> autoProgress;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    controller.end();
    controller.completed.value = false;
    autoProgress = ValueNotifier<PreloadProgress?>(null);
  });

  tearDown(() => controller.end());

  Future<void> pumpHost(
    WidgetTester tester, {
    VoidCallback? onCancelAutoPreload,
  }) async {
    await tester.pumpWidget(
      _host(autoProgress, onCancelAutoPreload: onCancelAutoPreload),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startMinimizedSession(
    WidgetTester tester, {
    String title = 'All Folders',
    ScanSessionKind kind = ScanSessionKind.scan,
    void Function()? onCancel,
  }) async {
    final generation = controller.begin(
      title: title,
      kind: kind,
      onCancel: onCancel ?? () {},
    );
    controller.update(generation, _progress(3, 10));
    controller.overlayDismissed(generation);
    await pumpHost(tester);
  }

  testWidgets('stays hidden when no scan or preload is running', (
    tester,
  ) async {
    await pumpHost(tester);

    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);
  });

  testWidgets('shows the bubble and toggles the card on tap', (tester) async {
    await startMinimizedSession(tester);

    expect(_opacity(tester, _bubbleKey), 1);
    expect(_opacity(tester, _cardKey), 0);
    expect(find.text('All Folders'), findsOneWidget);

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();

    expect(_opacity(tester, _cardKey), 1);
    expect(find.text('3 / 10 files'), findsOneWidget);
  });

  testWidgets('tapping outside collapses the card', (tester) async {
    await startMinimizedSession(tester);

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    expect(_opacity(tester, _cardKey), 1);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(_opacity(tester, _cardKey), 0);
  });

  testWidgets('Stop cancels the session and clears the UI immediately', (
    tester,
  ) async {
    var cancelled = false;
    await startMinimizedSession(
      tester,
      title: 'Preloading Audio',
      kind: ScanSessionKind.preload,
      onCancel: () => cancelled = true,
    );

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(controller.isActive, isFalse);
    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);
  });

  testWidgets('Stop on a scan session also hides the auto preload pass', (
    tester,
  ) async {
    autoProgress.value = const PreloadProgress(completed: 2, total: 8);
    await startMinimizedSession(tester);

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(controller.isActive, isFalse);
    // The cancelled pass lingers in the service for one in-flight chunk but
    // must not resurface as if Stop did nothing.
    expect(autoProgress.value, isNotNull);
    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);

    autoProgress.value = null;
    autoProgress.value = const PreloadProgress(completed: 1, total: 4);
    await tester.pumpAndSettle();
    expect(_opacity(tester, _bubbleKey), 1);
  });

  testWidgets('Stop on a scan session suppresses an auto pass that starts later', (
    tester,
  ) async {
    await startMinimizedSession(tester);

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    // A straggler pass can start only after the cancel, with no null in
    // between; Stop must still win.
    autoProgress.value = const PreloadProgress(completed: 1, total: 4);
    await tester.pumpAndSettle();
    expect(_opacity(tester, _bubbleKey), 0);
  });

  testWidgets('Stop hides the auto preload bubble before the pass drains', (
    tester,
  ) async {
    var cancelRequested = false;
    autoProgress.value = const PreloadProgress(completed: 2, total: 8);
    await pumpHost(
      tester,
      onCancelAutoPreload: () => cancelRequested = true,
    );

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(cancelRequested, isTrue);
    // The service only clears progress once the in-flight chunk finishes.
    expect(autoProgress.value, isNotNull);
    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);

    autoProgress.value = null;
    autoProgress.value = const PreloadProgress(completed: 1, total: 4);
    await tester.pumpAndSettle();
    expect(_opacity(tester, _bubbleKey), 1);
  });

  testWidgets('Skip while loading artwork ends the session and hides the pill', (
    tester,
  ) async {
    final generation = controller.begin(
      title: 'All Folders',
      kind: ScanSessionKind.scan,
      onCancel: () {},
    );
    controller.update(
      generation,
      _progress(3, 10).copyWith(phase: 'Loading artwork'),
    );
    controller.overlayDismissed(generation);
    controller.postProcessing.value = true;
    await pumpHost(tester);

    await tester.tap(find.byKey(_bubbleKey));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(controller.skipRequests.value, greaterThan(0));
    expect(controller.isActive, isFalse);
    expect(controller.postProcessing.value, isFalse);
    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);
  });

  testWidgets('shows for silent auto preload without a session', (
    tester,
  ) async {
    autoProgress.value = const PreloadProgress(completed: 2, total: 8);

    await pumpHost(tester);

    expect(_opacity(tester, _bubbleKey), 1);
    expect(controller.isActive, isFalse);
  });

  testWidgets('completion plays a check outro and then hides the pill', (
    tester,
  ) async {
    await startMinimizedSession(tester);
    expect(_opacity(tester, _bubbleKey), 1);

    controller.markCompleted();
    controller.end();
    await tester.pump();

    expect(_opacity(tester, _bubbleKey), 1);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(_opacity(tester, _bubbleKey), 0);
    expect(_opacity(tester, _cardKey), 0);
    expect(controller.isActive, isFalse);
  });

  testWidgets('completion does not play the outro when the overlay is open', (
    tester,
  ) async {
    final generation = controller.begin(
      title: 'All Folders',
      kind: ScanSessionKind.scan,
      onCancel: () {},
    );
    controller.update(generation, _progress(3, 10));
    await pumpHost(tester);

    controller.markCompleted();
    controller.end(generation);
    await tester.pumpAndSettle();

    expect(_opacity(tester, _bubbleKey), 0);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('preload stays hidden after the check until a new session', (
    tester,
  ) async {
    autoProgress.value = const PreloadProgress(completed: 1, total: 8);
    await startMinimizedSession(tester);
    expect(_opacity(tester, _bubbleKey), 1);

    controller.markCompleted();
    controller.end();
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(_opacity(tester, _bubbleKey), 0);

    autoProgress.value = null;
    autoProgress.value = const PreloadProgress(completed: 1, total: 4);
    await tester.pumpAndSettle();

    expect(_opacity(tester, _bubbleKey), 0);

    final generation = controller.begin(
      title: 'All Folders',
      kind: ScanSessionKind.scan,
      onCancel: () {},
    );
    controller.end(generation);
    await tester.pumpAndSettle();

    expect(_opacity(tester, _bubbleKey), 1);
  });

  testWidgets('drag snaps to the left edge and persists the side', (
    tester,
  ) async {
    await startMinimizedSession(tester);

    final start = tester.getTopLeft(find.byKey(_bubbleKey));
    await tester.drag(find.byKey(_bubbleKey), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final end = tester.getTopLeft(find.byKey(_bubbleKey));
    expect(end.dx, lessThan(start.dx));
    expect(end.dx, 8.0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('floating_scan_indicator_side'), 'left');
    expect(prefs.getDouble('floating_scan_indicator_y_fraction'), isNotNull);
  });
}
