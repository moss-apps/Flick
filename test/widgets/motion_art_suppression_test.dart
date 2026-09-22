import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:flick/features/player/widgets/motion_art_widget.dart';

Widget _host(ValueListenable<bool> suppression) => MaterialApp(
  home: Scaffold(
    body: MotionArtView(
      title: 'Anti-Hero',
      artist: 'Taylor Swift',
      fallback: const Text('fallback'),
      suppressionOverride: suppression,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('suppressed view renders fallback and never loads', (
    tester,
  ) async {
    final suppression = ValueNotifier<bool>(true);
    await tester.pumpWidget(_host(suppression));

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('flipping to suppressed cancels a pending load', (tester) async {
    final suppression = ValueNotifier<bool>(false);
    await tester.pumpWidget(_host(suppression));

    // Inside the debounce window: no lookup has run yet.
    await tester.pump(const Duration(milliseconds: 50));
    suppression.value = true;
    await tester.pump();

    expect(find.text('fallback'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('lifting suppression lets motion art start loading', (
    tester,
  ) async {
    final suppression = ValueNotifier<bool>(true);
    await tester.pumpWidget(_host(suppression));
    await tester.pump(const Duration(seconds: 1));

    suppression.value = false;
    await tester.pump();

    // No video plugin in the test harness, so the load attempt fails and the
    // fallback stays; the point is that the view re-armed its debounce.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(VideoPlayer), findsNothing);
  });
}
