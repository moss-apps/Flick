import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/features/playlists/utils/playlist_cover_edit.dart';
import 'package:flick/features/playlists/utils/playlist_cover_render.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'flick_cover_render_test_',
    );
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  String writeImage(img.Image image, [String name = 'source.png']) {
    final file = File('${temporaryDirectory.path}/$name');
    file.writeAsBytesSync(img.encodePng(image));
    return file.path;
  }

  img.Image quadrantImage() {
    final image = img.Image(width: 8, height: 8);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final int r;
        final int g;
        final int b;
        if (x < 4 && y < 4) {
          r = 220;
          g = 20;
          b = 20;
        } else if (x >= 4 && y < 4) {
          r = 20;
          g = 220;
          b = 20;
        } else if (x < 4) {
          r = 20;
          g = 20;
          b = 220;
        } else {
          r = 230;
          g = 230;
          b = 230;
        }
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  img.Image solidImage(int width, int height, int r, int g, int b) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  img.Image decodeResult(Uint8List? bytes) {
    expect(bytes, isNotNull);
    final decoded = img.decodeImage(bytes!);
    expect(decoded, isNotNull);
    return decoded!;
  }

  void expectColor(
    img.Image image,
    int x,
    int y,
    int red,
    int green,
    int blue, {
    int tolerance = 0,
  }) {
    final pixel = image.getPixel(x, y);
    expect(pixel.r.toInt(), closeTo(red, tolerance));
    expect(pixel.g.toInt(), closeTo(green, tolerance));
    expect(pixel.b.toInt(), closeTo(blue, tolerance));
  }

  Map<String, Object> request(
    String path, {
    int preparedWidth = 8,
    int preparedHeight = 8,
    int quarterTurns = 0,
    bool mirrored = false,
    double cropLeft = 0,
    double cropTop = 0,
    double cropSide = 8,
    double? cropWidth,
    double? cropHeight,
    int maxOutput = 8,
    int quality = 100,
    bool applyEffects = false,
    List<double>? colorMatrix,
    double vignette = 0,
  }) {
    return <String, Object>{
      'path': path,
      'preparedWidth': preparedWidth,
      'preparedHeight': preparedHeight,
      'quarterTurns': quarterTurns,
      'mirrored': mirrored,
      'cropLeft': cropLeft,
      'cropTop': cropTop,
      'cropSide': cropSide,
      'cropWidth': ?cropWidth,
      'cropHeight': ?cropHeight,
      'maxOutput': maxOutput,
      'quality': quality,
      'applyEffects': applyEffects,
      'colorMatrix': ?colorMatrix,
      'vignette': vignette,
    };
  }

  group('preparePlaylistCover', () {
    test('caps the longest side at 2400px', () {
      final path = writeImage(solidImage(2401, 1200, 10, 20, 30));
      final prepared = preparePlaylistCover(path);

      expect(prepared['width'], 2400);
      expect(prepared['height'], 1200);
      final decoded = img.decodeImage(prepared['bytes'] as Uint8List)!;
      expect(decoded.width, 2400);
      expect(decoded.height, 1200);
    });

    test('leaves small images at their original size', () {
      final path = writeImage(solidImage(100, 50, 10, 20, 30));
      final prepared = preparePlaylistCover(path);

      expect(prepared['width'], 100);
      expect(prepared['height'], 50);
    });

    test('throws when the image cannot be decoded', () {
      final path = '${temporaryDirectory.path}/bad.jpg';
      File(path).writeAsBytesSync(<int>[1, 2, 3, 4]);

      expect(() => preparePlaylistCover(path), throwsA(isA<Exception>()));
    });
  });

  group('renderPlaylistCover', () {
    test('returns null for invalid requests', () {
      final path = writeImage(solidImage(8, 8, 10, 20, 30));

      expect(renderPlaylistCover(request(path, cropSide: 0)), isNull);
      expect(renderPlaylistCover(request(path, preparedWidth: 0)), isNull);
      expect(
        renderPlaylistCover(request('${temporaryDirectory.path}/missing.png')),
        isNull,
      );
    });

    test('exports a non-square crop at the requested aspect', () {
      final path = writeImage(solidImage(8, 8, 10, 20, 30));

      final bytes = renderPlaylistCover(
        request(path, cropWidth: 8, cropHeight: 6, maxOutput: 8),
      );

      final decoded = decodeResult(bytes);
      expect(decoded.width, 8);
      expect(decoded.height, 6);
    });

    test('scales the longest side of a non-square crop', () {
      final path = writeImage(solidImage(8, 8, 10, 20, 30));

      final bytes = renderPlaylistCover(
        request(path, cropWidth: 8, cropHeight: 6, maxOutput: 4),
      );

      final decoded = decodeResult(bytes);
      expect(decoded.width, 4);
      expect(decoded.height, 3);
    });

    test('returns null for undecodable bytes', () {
      final path = '${temporaryDirectory.path}/bad.jpg';
      File(path).writeAsBytesSync(<int>[1, 2, 3, 4]);

      expect(renderPlaylistCover(request(path)), isNull);
    });

    test('applies clockwise rotation in the same order as the preview', () {
      final path = writeImage(quadrantImage());

      final expected = <int, List<int>>{
        0: <int>[220, 20, 20],
        1: <int>[20, 20, 220],
        2: <int>[230, 230, 230],
        3: <int>[20, 220, 20],
      };

      for (var turns = 0; turns < 4; turns++) {
        final result = decodeResult(
          renderPlaylistCover(request(path, quarterTurns: turns)),
        );
        final expectedColor = expected[turns]!;
        expectColor(
          result,
          2,
          2,
          expectedColor[0],
          expectedColor[1],
          expectedColor[2],
          tolerance: 15,
        );
      }
    });

    test('mirrors before rotating', () {
      final path = writeImage(quadrantImage());
      final result = decodeResult(
        renderPlaylistCover(request(path, mirrored: true)),
      );

      // A horizontal mirror swaps the red and green quadrants.
      expectColor(result, 2, 2, 20, 220, 20, tolerance: 15);
      expectColor(result, 6, 2, 220, 20, 20, tolerance: 15);
      expectColor(result, 2, 6, 230, 230, 230, tolerance: 15);
      expectColor(result, 6, 6, 20, 20, 220, tolerance: 15);
    });

    test('crops the requested square', () {
      final path = writeImage(quadrantImage());
      final result = decodeResult(
        renderPlaylistCover(
          request(path, cropLeft: 4, cropTop: 4, cropSide: 4, maxOutput: 4),
        ),
      );

      expect(result.width, 4);
      expect(result.height, 4);
      expectColor(result, 2, 2, 230, 230, 230, tolerance: 10);
    });

    test('downscales the output to maxOutput', () {
      final path = writeImage(solidImage(600, 600, 20, 40, 60));
      final result = decodeResult(
        renderPlaylistCover(
          request(
            path,
            preparedWidth: 600,
            preparedHeight: 600,
            cropSide: 600,
            maxOutput: 256,
          ),
        ),
      );

      expect(result.width, 256);
      expect(result.height, 256);
    });

    test('resizes the source to the prepared dimensions before cropping', () {
      final path = writeImage(solidImage(16, 16, 200, 100, 50));
      final result = decodeResult(
        renderPlaylistCover(
          request(
            path,
            preparedWidth: 8,
            preparedHeight: 8,
            cropSide: 8,
            maxOutput: 8,
          ),
        ),
      );

      expect(result.width, 8);
      expect(result.height, 8);
      expectColor(result, 4, 4, 200, 100, 50, tolerance: 10);
    });

    test('applies a mono colour matrix', () {
      final path = writeImage(solidImage(32, 32, 200, 100, 50));
      final matrix = const PlaylistCoverEdit(
        filter: PlaylistCoverFilter.mono,
      ).colorMatrix.values;
      final result = decodeResult(
        renderPlaylistCover(
          request(
            path,
            preparedWidth: 32,
            preparedHeight: 32,
            cropSide: 32,
            maxOutput: 32,
            applyEffects: true,
            colorMatrix: matrix,
          ),
        ),
      );

      expectColor(result, 16, 16, 117, 117, 117, tolerance: 5);
    });

    test('applies the shared vignette curve', () {
      final path = writeImage(solidImage(64, 64, 255, 255, 255));
      final result = decodeResult(
        renderPlaylistCover(
          request(
            path,
            preparedWidth: 64,
            preparedHeight: 64,
            cropSide: 64,
            maxOutput: 64,
            applyEffects: true,
            colorMatrix: CoverColorMatrix.identity.values,
            vignette: 1,
          ),
        ),
      );

      final centre = result.getPixel(32, 32);
      final corner = result.getPixel(0, 0);
      expect(centre.r.toInt(), greaterThan(230));
      expect(corner.r.toInt(), lessThan(60));
      expect(corner.g.toInt(), lessThan(60));
      expect(corner.b.toInt(), lessThan(60));
    });

    test('skips effects when applyEffects is false', () {
      final path = writeImage(solidImage(32, 32, 200, 100, 50));
      final matrix = const PlaylistCoverEdit(
        filter: PlaylistCoverFilter.mono,
      ).colorMatrix.values;
      final result = decodeResult(
        renderPlaylistCover(
          request(
            path,
            preparedWidth: 32,
            preparedHeight: 32,
            cropSide: 32,
            maxOutput: 32,
            applyEffects: false,
            colorMatrix: matrix,
            vignette: 1,
          ),
        ),
      );

      expectColor(result, 16, 16, 200, 100, 50, tolerance: 10);
      expectColor(result, 0, 0, 200, 100, 50, tolerance: 15);
    });
  });
}
