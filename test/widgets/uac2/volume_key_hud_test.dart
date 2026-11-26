import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/player_service.dart' show VolumeKeyFeedback;
import 'package:flick/widgets/uac2/volume_key_hud.dart';

Widget _host(ValueNotifier<VolumeKeyFeedback?> feedback, {Widget? child}) =>
    MaterialApp(
      home: Scaffold(
        body: VolumeKeyHudHost(
          feedback: feedback,
          child: child ?? const Center(child: Text('content')),
        ),
      ),
    );

// Not const: every key press is a new event, even at the same level.
VolumeKeyFeedback _press(double level, {bool muted = false}) =>
    VolumeKeyFeedback(level, muted: muted);

double _opacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

void main() {
  testWidgets('shows nothing until a volume key moves the DAC', (tester) async {
    final feedback = ValueNotifier<VolumeKeyFeedback?>(null);
    addTearDown(feedback.dispose);

    await tester.pumpWidget(_host(feedback));

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows the level, then hides after a moment', (tester) async {
    final feedback = ValueNotifier<VolumeKeyFeedback?>(null);
    addTearDown(feedback.dispose);
    await tester.pumpWidget(_host(feedback));

    feedback.value = _press(0.5625);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('56%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5625,
    );
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), 0.0);
  });

  testWidgets('another press at the same level keeps it on screen', (
    tester,
  ) async {
    final feedback = ValueNotifier<VolumeKeyFeedback?>(null);
    addTearDown(feedback.dispose);
    await tester.pumpWidget(_host(feedback));

    feedback.value = _press(1.0);
    await tester.pump(const Duration(milliseconds: 1200));
    // Pressing up at the top of the range is a new event, not a repeat of the
    // old value, so the hide timer restarts.
    feedback.value = _press(1.0);
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('100%'), findsOneWidget);
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), 0.0);
  });

  testWidgets('does not take touches from the app underneath', (tester) async {
    final feedback = ValueNotifier<VolumeKeyFeedback?>(null);
    addTearDown(feedback.dispose);
    var taps = 0;
    await tester.pumpWidget(
      _host(
        feedback,
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 80),
          ),
        ),
      ),
    );

    feedback.value = _press(0.3);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(400, 40));

    expect(taps, 1);
  });

  testWidgets('shows a muted DAC with the muted icon', (tester) async {
    final feedback = ValueNotifier<VolumeKeyFeedback?>(null);
    addTearDown(feedback.dispose);
    await tester.pumpWidget(_host(feedback));

    feedback.value = _press(0.4, muted: true);
    await tester.pump(const Duration(milliseconds: 200));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.red.shade400);
  });
}
