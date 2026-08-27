import 'package:flutter/widgets.dart';

/// Screen-edge anchoring for the lyrics views: one preference value maps to
/// both text alignment inside a line and how the line box itself sits in the
/// panel, so "left" means the words hug the left edge of the screen.
class LyricsAlignment {
  final TextAlign textAlign;
  final WrapAlignment wrapAlignment;

  const LyricsAlignment._(this.textAlign, this.wrapAlignment);

  static const LyricsAlignment left = LyricsAlignment._(
    TextAlign.left,
    WrapAlignment.start,
  );
  static const LyricsAlignment center = LyricsAlignment._(
    TextAlign.center,
    WrapAlignment.center,
  );
  static const LyricsAlignment right = LyricsAlignment._(
    TextAlign.right,
    WrapAlignment.end,
  );
}

LyricsAlignment resolveLyricsAlignment(String pref) {
  switch (pref) {
    case 'left':
      return LyricsAlignment.left;
    case 'right':
      return LyricsAlignment.right;
    default:
      return LyricsAlignment.center;
  }
}
