import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Maps the visible crop viewport back to a rectangle in source-image pixels.
///
/// The image is displayed at [imageSize] scaled by the larger of the viewport's
/// width/height ratios (cover fit), then transformed by [transform]. Only
/// scaling and translation are supported, which is all [InteractiveViewer]
/// produces.
///
/// The viewport may be any aspect ratio; playlist covers pass a square and
/// share artwork passes 4:5 or 1:1.
Rect calculateArtworkCrop({
  required Size viewportSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  if (viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      imageSize.width <= 0 ||
      imageSize.height <= 0) {
    return Rect.zero;
  }

  final coverScale = math.max(
    viewportSize.width / imageSize.width,
    viewportSize.height / imageSize.height,
  );
  final scale = transform.getMaxScaleOnAxis();
  if (scale <= 0 || coverScale <= 0) return Rect.zero;

  final translation = transform.getTranslation();
  final width = math.min(
    imageSize.width,
    viewportSize.width / (scale * coverScale),
  );
  final height = math.min(
    imageSize.height,
    viewportSize.height / (scale * coverScale),
  );
  if (width <= 0 || height <= 0) return Rect.zero;

  final left = (-translation.x / scale) / coverScale;
  final top = (-translation.y / scale) / coverScale;

  return Rect.fromLTWH(
    left.clamp(0.0, imageSize.width - width),
    top.clamp(0.0, imageSize.height - height),
    width,
    height,
  );
}

/// Square-crop convenience wrapper retained for playlist covers.
Rect calculatePlaylistCoverCrop({
  required Size viewportSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  return calculateArtworkCrop(
    viewportSize: viewportSize,
    imageSize: imageSize,
    transform: transform,
  );
}

/// Builds the [InteractiveViewer] transform that shows [cropSize] around
/// [cropCenter].
///
/// This is the inverse of [calculateArtworkCrop]. It is used after a
/// rotate/flip so the same framing survives the orientation change instead of
/// snapping back to the centre. The viewport is intentionally clamped to the
/// viewer's 1..4 zoom range.
Matrix4 calculateArtworkTransform({
  required Size viewportSize,
  required Size imageSize,
  required Offset cropCenter,
  required Size cropSize,
}) {
  if (viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      imageSize.width < 1 ||
      imageSize.height < 1 ||
      cropSize.width <= 0 ||
      cropSize.height <= 0) {
    return Matrix4.identity();
  }

  final coverScale = math.max(
    viewportSize.width / imageSize.width,
    viewportSize.height / imageSize.height,
  );
  final requestedWidth = cropSize.width.clamp(1.0, imageSize.width).toDouble();
  final requestedHeight = cropSize.height
      .clamp(1.0, imageSize.height)
      .toDouble();
  final scale = math
      .max(
        viewportSize.width / (requestedWidth * coverScale),
        viewportSize.height / (requestedHeight * coverScale),
      )
      .clamp(1.0, 4.0)
      .toDouble();
  final effectiveWidth = viewportSize.width / (scale * coverScale);
  final effectiveHeight = viewportSize.height / (scale * coverScale);

  final halfWidth = effectiveWidth / 2;
  final halfHeight = effectiveHeight / 2;
  final centerX = cropCenter.dx
      .clamp(halfWidth, imageSize.width - halfWidth)
      .toDouble();
  final centerY = cropCenter.dy
      .clamp(halfHeight, imageSize.height - halfHeight)
      .toDouble();

  final translationX = viewportSize.width / 2 - centerX * coverScale * scale;
  final translationY = viewportSize.height / 2 - centerY * coverScale * scale;

  return Matrix4.identity()
    ..setTranslationRaw(translationX, translationY, 0)
    ..scaleByDouble(scale, scale, 1, 1);
}

/// Square-crop convenience wrapper retained for playlist covers.
Matrix4 calculatePlaylistCoverTransform({
  required Size viewportSize,
  required Size imageSize,
  required Offset cropCenter,
  required double cropSide,
}) {
  if (cropSide <= 0 || imageSize.width <= 0 || imageSize.height <= 0) {
    return Matrix4.identity();
  }
  final maxSide = math.min(imageSize.width, imageSize.height);
  return calculateArtworkTransform(
    viewportSize: viewportSize,
    imageSize: imageSize,
    cropCenter: cropCenter,
    cropSize: Size.square(cropSide.clamp(1.0, maxSide).toDouble()),
  );
}
