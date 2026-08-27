import 'package:flick/features/player/widgets/lyrics_alignment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps preference strings to edge-anchored alignments', () {
    expect(resolveLyricsAlignment('left').textAlign, TextAlign.left);
    expect(resolveLyricsAlignment('left').wrapAlignment, WrapAlignment.start);

    expect(resolveLyricsAlignment('right').textAlign, TextAlign.right);
    expect(resolveLyricsAlignment('right').wrapAlignment, WrapAlignment.end);

    expect(resolveLyricsAlignment('center').textAlign, TextAlign.center);
    expect(
      resolveLyricsAlignment('center').wrapAlignment,
      WrapAlignment.center,
    );
  });

  test('unknown values fall back to center', () {
    expect(resolveLyricsAlignment('nonsense').textAlign, TextAlign.center);
    expect(resolveLyricsAlignment('').wrapAlignment, WrapAlignment.center);
  });
}
