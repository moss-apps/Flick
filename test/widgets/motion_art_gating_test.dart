import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/utils/app_log.dart';
import 'package:flick/features/player/widgets/motion_art_widget.dart';
import 'package:flick/widgets/common/animated_album_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('covered route never starts a motion art load', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final suppression = ValueNotifier<bool>(false);
    addTearDown(suppression.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: MotionArtView(
            title: 'Anti-Hero',
            artist: 'Taylor Swift',
            fallback: const Text('fallback'),
            suppressionOverride: suppression,
          ),
        ),
      ),
    );
    await tester.pump();

    // Cover the player route before the debounce window elapses.
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second')),
      ),
    );
    await tester.pump();

    AppLog.instance.clear();
    await tester.pump(const Duration(seconds: 1));

    final motionArtEntries = AppLog.instance.entries.where(
      (e) => e.message.startsWith('[MotionArt]'),
    );
    expect(motionArtEntries, isEmpty);
  });

  testWidgets('motionEnabled false keeps AnimatedAlbumArt on Ken Burns', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedAlbumArt(
            albumName: 'Midnights',
            artistName: 'Taylor Swift',
            motionEnabled: false,
          ),
        ),
      ),
    );

    expect(find.byType(MotionArtView), findsNothing);
  });
}
