import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Layout policy for the app window, not the physical device.
///
/// Android windows can be resized, folded, and split while the device stays
/// in one orientation. Every decision here therefore comes from the current
/// constraints/size; nothing reads `MediaQuery.orientation`.
abstract final class AdaptiveLayout {
  /// Below this width a two-pane composition starts to lose its right pane.
  static const double sideBySideMinWidth = 520.0;

  /// Material's medium/expanded boundary, kept for wide library layouts.
  static const double expandedMinWidth = 840.0;

  /// Short windows need vertically compact chrome even when they are wide.
  static const double shortHeight = 480.0;

  /// Width of the compact navigation rail in wide windows.
  static const double navigationRailWidth = 76.0;

  /// Narrow, vertical mini player used by the compact landscape song orbit.
  static const double sideMiniPlayerWidth = 64.0;
  static const double sideMiniPlayerContentInset = 78.0;

  static bool isWide(Size size) => size.width > size.height;

  /// Short landscape windows trade the bottom mini player for a side strip so
  /// the orbit keeps its vertical stage.
  static bool useCompactLandscapeMiniPlayer(Size size) =>
      size.width > size.height && size.height < shortHeight;

  /// True when the player should use its left-stage/right-controls layout.
  static bool usePlayerSideLayout(Size size) =>
      size.width >= sideBySideMinWidth && size.width > size.height;

  /// Same decision using the space actually left for the player body.
  static bool usePlayerSideLayoutFor(BoxConstraints constraints) =>
      constraints.maxWidth >= sideBySideMinWidth &&
      constraints.maxWidth > constraints.maxHeight;

  /// True when the shell should move navigation from the bottom to the side.
  static bool useSideNavigation(Size size) =>
      size.width >= 520.0 && size.width > size.height;

  static double railWidth(BuildContext context) =>
      math.min(navigationRailWidth, MediaQuery.sizeOf(context).width * 0.16);
}
