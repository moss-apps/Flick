import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/songs/widgets/orbit_card_blur.dart';
import 'package:flick/services/artwork_gate.dart';
import 'package:flick/services/orbit_card_blur_image.dart';

Future<String> _writeCover(String directory) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 64, 32),
    Paint()..color = const Color(0xFF3366CC),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 32);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final file = File('$directory/cover.png');
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file.path;
}

Future<void> _loadImage(OrbitCardBlurImage provider) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final loaded = Completer<void>();
  final listener = ImageStreamListener(
    (image, _) {
      image.dispose();
      loaded.complete();
    },
    onError: (Object error, StackTrace? stack) =>
        loaded.completeError(error, stack),
  );
  stream.addListener(listener);
  try {
    await loaded.future.timeout(const Duration(seconds: 5));
  } finally {
    stream.removeListener(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> cover(WidgetTester tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('flick-blur-image'),
    );
    addTearDown(() => directory!.delete(recursive: true));
    return (await tester.runAsync(() => _writeCover(directory!.path)))!;
  }

  testWidgets('rasterizes at the bounded size with the card aspect', (
    tester,
  ) async {
    final path = await cover(tester);

    final image = await tester.runAsync(
      () => OrbitCardBlurImage.renderBlurredCardImage(
        path: path,
        cardSize: const Size(320, 130),
      ),
    );

    // 192 px on the long edge preserves the 320:130 card aspect.
    expect(image!.width, 192);
    expect(image.height, 78);
    image.dispose();
  });

  testWidgets(
    'a cold blur loads without waiting for active animation to stop',
    (tester) async {
      final path = await cover(tester);
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      )..repeat();
      try {
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        final provider = OrbitCardBlurImage(
          path: path,
          cardSize: const Size(320, 130),
        );
        await tester.runAsync(() => _loadImage(provider));
        expect(animation.isAnimating, isTrue);
        expect(
          PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive,
          isTrue,
        );
      } finally {
        animation.dispose();
      }
    },
  );

  testWidgets(
    'a prewarmed overlay paints on its first frame during scrolling',
    (tester) async {
      final path = await cover(tester);
      const size = Size(320, 130);
      await tester.runAsync(() async {
        await OrbitCardBlurArtwork.resolveLocalPath(imagePath: path);
        await _loadImage(OrbitCardBlurImage(path: path, cardSize: size));
      });

      pauseArtworkExtraction(true);
      addTearDown(() => pauseArtworkExtraction(false));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: OrbitCardBlur(imagePath: path),
            ),
          ),
        ),
      );
      final image = tester.widget<RawImage>(find.byType(RawImage));
      expect(image.image, isNotNull);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(artworkExtractionPaused, isTrue);
    },
  );
}
