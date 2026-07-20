import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/widgets/common/animated_album_art.dart';
import 'package:flick/widgets/common/scroll_fade_wrapper.dart';

void main() {
  testWidgets('ScrollFadeWrapper fades child as scroll offset grows', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView(
                controller: controller,
                children: const [SizedBox(height: 2000)],
              ),
              ScrollFadeWrapper(
                scrollController: controller,
                fadeDistance: 100,
                child: const Text('hero'),
              ),
            ],
          ),
        ),
      ),
    );

    Opacity opacity = tester.widget(find.byType(Opacity));
    expect(opacity.opacity, 1.0);

    controller.jumpTo(50);
    await tester.pump();
    opacity = tester.widget(find.byType(Opacity));
    expect(opacity.opacity, 0.5);

    controller.jumpTo(200);
    await tester.pump();
    opacity = tester.widget(find.byType(Opacity));
    expect(opacity.opacity, 0.0);
  });

  testWidgets('AnimatedAlbumArt builds and ticks without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnimatedAlbumArt(dominantColor: Colors.red)),
      ),
    );
    expect(find.byType(AnimatedAlbumArt), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
