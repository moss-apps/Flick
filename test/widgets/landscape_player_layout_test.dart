import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/player/widgets/landscape_player_layout.dart';

void main() {
  for (final size in const [Size(496, 210), Size(850, 300), Size(1280, 650)]) {
    for (final artwork in [false, true]) {
      testWidgets(
        '$size artwork=$artwork keeps identity and playback together',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LandscapePlayerLayout(
                  artworkCard: artwork,
                  stage: const ColoredBox(
                    key: ValueKey('stage'),
                    color: Colors.blue,
                  ),
                  identity: const SizedBox(
                    key: ValueKey('identity'),
                    height: 56,
                    child: Text('Title and artist'),
                  ),
                  actions: const SizedBox(height: 48, child: Text('Actions')),
                  playback: const SizedBox(
                    key: ValueKey('playback'),
                    height: 80,
                    child: Text('Playback'),
                  ),
                ),
              ),
            ),
          );
          final identity = tester.getRect(
            find.byKey(const ValueKey('identity')),
          );
          final playback = tester.getRect(
            find.byKey(const ValueKey('playback')),
          );
          // Artwork-card details keep a little extra breathing room above
          // playback, so allow a slightly larger gap than immersive mode.
          expect(playback.top - identity.bottom, lessThanOrEqualTo(100));
          expect(playback.bottom, lessThanOrEqualTo(size.height));
          if (artwork) {
            expect(
              tester.getSize(find.byKey(const ValueKey('stage'))).width,
              lessThanOrEqualTo(400),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('large details scroll without displacing playback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandscapePlayerLayout(
            lyricsMode: true,
            stage: const Text('Lyrics'),
            identity: Text(List.filled(30, 'A long song title').join('\n')),
            playback: const SizedBox(
              key: ValueKey('playback'),
              height: 100,
              child: Text('Playback'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('playback'))).bottom,
      lessThanOrEqualTo(240),
    );
    await tester.drag(
      find.byKey(const ValueKey('landscape-player-details')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
