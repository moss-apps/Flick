import 'package:flick/features/playlists/utils/playlist_cover_crop_math.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculatePlaylistCoverCrop', () {
    test('centered landscape image crops a centered square', () {
      final crop = calculatePlaylistCoverCrop(
        viewportSize: const Size(300, 300),
        imageSize: const Size(2000, 1000),
        transform: Matrix4.identity()..setTranslationRaw(-150, 0, 0),
      );

      expect(crop, const Rect.fromLTWH(500, 0, 1000, 1000));
    });

    test('portrait image crops a centered square', () {
      final crop = calculatePlaylistCoverCrop(
        viewportSize: const Size(300, 300),
        imageSize: const Size(1000, 2000),
        transform: Matrix4.identity()..setTranslationRaw(0, -150, 0),
      );

      expect(crop, const Rect.fromLTWH(0, 500, 1000, 1000));
    });

    test('zooming in reduces the source crop size', () {
      final transform = Matrix4.diagonal3Values(2.0, 2.0, 1.0)
        ..setTranslationRaw(-150, 0, 0);

      final crop = calculatePlaylistCoverCrop(
        viewportSize: const Size(300, 300),
        imageSize: const Size(2000, 1000),
        transform: transform,
      );

      expect(crop.left, closeTo(250, 0.001));
      expect(crop.top, 0);
      expect(crop.width, closeTo(500, 0.001));
      expect(crop.height, closeTo(500, 0.001));
    });

    test('returns zero for empty dimensions', () {
      expect(
        calculatePlaylistCoverCrop(
          viewportSize: Size.zero,
          imageSize: const Size(1000, 1000),
          transform: Matrix4.identity(),
        ),
        Rect.zero,
      );
    });
  });

  group('calculateArtworkCrop', () {
    test('portrait viewport keeps its 4:5 aspect inside a landscape image', () {
      final crop = calculateArtworkCrop(
        viewportSize: const Size(400, 500),
        imageSize: const Size(2000, 1000),
        transform: Matrix4.identity()..setTranslationRaw(-300, 0, 0),
      );

      expect(crop, const Rect.fromLTWH(600, 0, 800, 1000));
    });

    test('4:5 framing round-trips through calculateArtworkTransform', () {
      const viewport = Size(400, 500);
      final transform = calculateArtworkTransform(
        viewportSize: viewport,
        imageSize: const Size(2000, 1000),
        cropCenter: const Offset(1000, 500),
        cropSize: const Size(800, 1000),
      );

      expect(transform.getMaxScaleOnAxis(), closeTo(1, 0.0001));
      expect(transform.getTranslation().x, closeTo(-300, 0.0001));
      expect(transform.getTranslation().y, closeTo(0, 0.0001));

      final crop = calculateArtworkCrop(
        viewportSize: viewport,
        imageSize: const Size(2000, 1000),
        transform: transform,
      );
      expect(crop, const Rect.fromLTWH(600, 0, 800, 1000));
    });
  });

  group('calculatePlaylistCoverTransform', () {
    void expectTransform({
      required Size imageSize,
      required Offset center,
      required double cropSide,
      required double expectedScale,
      required Offset expectedTranslation,
      required Rect expectedCrop,
    }) {
      final transform = calculatePlaylistCoverTransform(
        viewportSize: const Size(300, 300),
        imageSize: imageSize,
        cropCenter: center,
        cropSide: cropSide,
      );

      expect(transform.getMaxScaleOnAxis(), closeTo(expectedScale, 0.0001));
      final translation = transform.getTranslation();
      expect(translation.x, closeTo(expectedTranslation.dx, 0.0001));
      expect(translation.y, closeTo(expectedTranslation.dy, 0.0001));

      final crop = calculatePlaylistCoverCrop(
        viewportSize: const Size(300, 300),
        imageSize: imageSize,
        transform: transform,
      );
      expect(crop.left, closeTo(expectedCrop.left, 0.0001));
      expect(crop.top, closeTo(expectedCrop.top, 0.0001));
      expect(crop.width, closeTo(expectedCrop.width, 0.0001));
      expect(crop.height, closeTo(expectedCrop.height, 0.0001));
    }

    test('centered landscape framing round-trips', () {
      expectTransform(
        imageSize: const Size(2000, 1000),
        center: const Offset(1000, 500),
        cropSide: 1000,
        expectedScale: 1,
        expectedTranslation: const Offset(-150, 0),
        expectedCrop: const Rect.fromLTWH(500, 0, 1000, 1000),
      );
    });

    test('zoomed landscape framing round-trips', () {
      expectTransform(
        imageSize: const Size(2000, 1000),
        center: const Offset(1000, 500),
        cropSide: 500,
        expectedScale: 2,
        expectedTranslation: const Offset(-450, -150),
        expectedCrop: const Rect.fromLTWH(750, 250, 500, 500),
      );
    });

    test('centered portrait framing round-trips', () {
      expectTransform(
        imageSize: const Size(1000, 2000),
        center: const Offset(500, 1000),
        cropSide: 1000,
        expectedScale: 1,
        expectedTranslation: const Offset(0, -150),
        expectedCrop: const Rect.fromLTWH(0, 500, 1000, 1000),
      );
    });

    test('clamps the crop center to the image bounds', () {
      expectTransform(
        imageSize: const Size(2000, 1000),
        center: const Offset(100, 500),
        cropSide: 800,
        expectedScale: 1.25,
        expectedTranslation: const Offset(0, -37.5),
        expectedCrop: const Rect.fromLTWH(0, 100, 800, 800),
      );
    });

    test('clamps the zoom to the InteractiveViewer range', () {
      expectTransform(
        imageSize: const Size(2000, 1000),
        center: const Offset(1000, 500),
        cropSide: 100,
        expectedScale: 4,
        expectedTranslation: const Offset(-1050, -450),
        expectedCrop: const Rect.fromLTWH(875, 375, 250, 250),
      );
    });

    test('returns identity for invalid dimensions', () {
      expect(
        calculatePlaylistCoverTransform(
          viewportSize: Size.zero,
          imageSize: const Size(1000, 1000),
          cropCenter: const Offset(500, 500),
          cropSide: 500,
        ),
        Matrix4.identity(),
      );
      expect(
        calculatePlaylistCoverTransform(
          viewportSize: const Size(300, 300),
          imageSize: const Size(1000, 1000),
          cropCenter: const Offset(500, 500),
          cropSide: 0,
        ),
        Matrix4.identity(),
      );
    });
  });
}
