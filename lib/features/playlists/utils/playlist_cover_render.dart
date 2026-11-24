import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:flick/features/playlists/utils/playlist_cover_vignette.dart';

/// Decodes [sourcePath], returning null for unreadable or malformed files.
///
/// The `image` package can throw on truncated containers instead of returning
/// null (for example, a four-byte PSD header), so callers must not rely on a
/// null result alone.
img.Image? _decodeCover(String sourcePath) {
  try {
    return img.decodeImage(File(sourcePath).readAsBytesSync());
  } catch (_) {
    return null;
  }
}

/// Decodes and normalizes a picked image for the on-screen preview.
///
/// Returns a JPEG that is at most 2400px on its longest side. The editor
/// exports from the original file, using these dimensions to map its crop
/// rectangle back to source pixels.
Map<String, Object> preparePlaylistCover(String sourcePath) {
  final decoded = _decodeCover(sourcePath);
  if (decoded == null) {
    throw const FormatException('Could not decode playlist cover');
  }

  var image = img.bakeOrientation(decoded);
  final longestSide = math.max(image.width, image.height);
  if (longestSide > 2400) {
    final scale = 2400 / longestSide;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  return {
    'bytes': img.encodeJpg(image, quality: 92),
    'width': image.width,
    'height': image.height,
  };
}

/// Applies the editor's orientation to an image.
///
/// The result matches the preview: mirror first, then rotate clockwise by
/// [quarterTurns] * 90 degrees. The input may be mutated when mirroring.
img.Image applyPlaylistCoverOrientation(
  img.Image source, {
  required int quarterTurns,
  required bool mirrored,
}) {
  var image = source;
  if (mirrored) {
    image = img.flipHorizontal(image);
  }
  final turns = quarterTurns % 4;
  if (turns != 0) {
    image = img.copyRotate(image, angle: turns * 90);
  }
  return image;
}

/// Exports the cropped cover described by [request].
///
/// The crop may be square (playlist covers, `cropSide`) or any aspect ratio
/// (share artwork, `cropWidth` + `cropHeight`). All values are primitives so
/// this can run through `compute`. Returns null when the source cannot be
/// decoded.
Uint8List? renderPlaylistCover(Map<String, Object> request) {
  final sourcePath = request['path'] as String?;
  final preparedWidth = (request['preparedWidth'] as num?)?.toInt() ?? 0;
  final preparedHeight = (request['preparedHeight'] as num?)?.toInt() ?? 0;
  final legacySide = (request['cropSide'] as num?)?.toDouble() ?? 0;
  final requestedWidth =
      (request['cropWidth'] as num?)?.toDouble() ?? legacySide;
  final requestedHeight =
      (request['cropHeight'] as num?)?.toDouble() ?? legacySide;
  if (sourcePath == null ||
      preparedWidth <= 0 ||
      preparedHeight <= 0 ||
      requestedWidth < 1 ||
      requestedHeight < 1) {
    return null;
  }

  final decoded = _decodeCover(sourcePath);
  if (decoded == null) return null;

  var image = img.bakeOrientation(decoded);
  if (image.width != preparedWidth || image.height != preparedHeight) {
    image = img.copyResize(
      image,
      width: preparedWidth,
      height: preparedHeight,
      interpolation: img.Interpolation.average,
    );
  }

  image = applyPlaylistCoverOrientation(
    image,
    quarterTurns: (request['quarterTurns'] as num?)?.toInt() ?? 0,
    mirrored: request['mirrored'] as bool? ?? false,
  );

  if (image.width <= 0 || image.height <= 0) return null;
  final cropWidth = requestedWidth.round().clamp(1, image.width);
  final cropHeight = requestedHeight.round().clamp(1, image.height);
  final maxLeft = image.width - cropWidth;
  final maxTop = image.height - cropHeight;
  final left = ((request['cropLeft'] as num?)?.toDouble() ?? 0).round().clamp(
    0,
    maxLeft,
  );
  final top = ((request['cropTop'] as num?)?.toDouble() ?? 0).round().clamp(
    0,
    maxTop,
  );

  var cropped = img.copyCrop(
    image,
    x: left,
    y: top,
    width: cropWidth,
    height: cropHeight,
  );

  final maxOutput = (request['maxOutput'] as num?)?.toInt() ?? 1600;
  final longestSide = math.max(cropped.width, cropped.height);
  if (maxOutput > 0 && longestSide > maxOutput) {
    final scale = maxOutput / longestSide;
    cropped = img.copyResize(
      cropped,
      width: math.max(1, (cropped.width * scale).round()),
      height: math.max(1, (cropped.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  final applyEffects = request['applyEffects'] as bool? ?? true;
  final vignette = ((request['vignette'] as num?)?.toDouble() ?? 0)
      .clamp(0.0, 1.0)
      .toDouble();
  final matrix = _readMatrix(request['colorMatrix']);
  if (applyEffects && (vignette > 0 || !_isIdentityMatrix(matrix))) {
    cropped = _applyEffects(cropped, matrix, vignette);
  }

  final quality = (request['quality'] as num?)?.toInt() ?? 90;
  return img.encodeJpg(cropped, quality: quality);
}

const List<double> _identityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _readMatrix(Object? raw) {
  if (raw is! List || raw.length != 20) return _identityMatrix;
  return <double>[for (final value in raw) (value as num).toDouble()];
}

bool _isIdentityMatrix(List<double> matrix) {
  for (var i = 0; i < _identityMatrix.length; i++) {
    if ((matrix[i] - _identityMatrix[i]).abs() > 1e-6) return false;
  }
  return true;
}

img.Image _applyEffects(img.Image source, List<double> m, double vignette) {
  final rgba = source.convert(format: img.Format.uint8, numChannels: 4);
  final pixels = rgba.getBytes(order: img.ChannelOrder.rgba);
  final width = rgba.width;
  final height = rgba.height;
  final inverseRadius = 1 / playlistCoverVignetteRadius;

  for (var y = 0; y < height; y++) {
    final normalizedY = (y + 0.5) / height - 0.5;
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final red = pixels[offset].toDouble();
      final green = pixels[offset + 1].toDouble();
      final blue = pixels[offset + 2].toDouble();
      final alpha = pixels[offset + 3].toDouble();

      var outRed =
          m[0] * red + m[1] * green + m[2] * blue + m[3] * alpha + m[4];
      var outGreen =
          m[5] * red + m[6] * green + m[7] * blue + m[8] * alpha + m[9];
      var outBlue =
          m[10] * red + m[11] * green + m[12] * blue + m[13] * alpha + m[14];
      final outAlpha =
          m[15] * red + m[16] * green + m[17] * blue + m[18] * alpha + m[19];

      if (vignette > 0) {
        final normalizedX = (x + 0.5) / width - 0.5;
        final distance =
            math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY) *
            inverseRadius;
        final darken = playlistCoverVignetteFactor(
          normalizedDistance: distance,
          amount: vignette,
        );
        final keep = 1 - darken;
        outRed *= keep;
        outGreen *= keep;
        outBlue *= keep;
      }

      pixels[offset] = outRed.clamp(0, 255).round();
      pixels[offset + 1] = outGreen.clamp(0, 255).round();
      pixels[offset + 2] = outBlue.clamp(0, 255).round();
      pixels[offset + 3] = outAlpha.clamp(0, 255).round();
    }
  }

  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
}
