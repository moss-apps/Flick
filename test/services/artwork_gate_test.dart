import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/artwork_gate.dart';

class _GateHarness with ArtworkExtractionScrollGate {}

ScrollMetrics _metrics(int pixels) => FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100,
      pixels: pixels.toDouble(),
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

void main() {
  testWidgets('scroll gate holds exactly one pause across a burst of updates',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final harness = _GateHarness();
    var flushed = 0;
    enqueueArtworkResolver(() => flushed++);
    expect(artworkExtractionPaused, isFalse);

    for (var i = 0; i < 50; i++) {
      harness.onScrollNotification(ScrollUpdateNotification(
        metrics: _metrics(i),
        context: context,
      ));
    }
    expect(artworkExtractionPaused, isTrue);
    expect(flushed, 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(artworkExtractionPaused, isFalse,
        reason: 'canceled settle timers must not leak pauses');
    expect(flushed, 1);

    harness.onScrollNotification(ScrollEndNotification(
      metrics: _metrics(49),
      context: context,
    ));
    harness.disposeArtworkGate();
    expect(artworkExtractionPaused, isFalse,
        reason: 'release without a held pause must not go negative');

    harness.onScrollNotification(ScrollUpdateNotification(
      metrics: _metrics(0),
      context: context,
    ));
    expect(artworkExtractionPaused, isTrue);
    harness.disposeArtworkGate();
    expect(artworkExtractionPaused, isFalse,
        reason: 'dispose mid-scroll must release the held pause');
  });
}
