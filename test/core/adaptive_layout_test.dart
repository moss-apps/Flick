import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/utils/adaptive_layout.dart';

void main() {
  group('AdaptiveLayout window decisions', () {
    test('portrait phones keep the stacked player and bottom navigation', () {
      for (final size in const [
        Size(320, 568),
        Size(360, 640),
        Size(411, 891),
      ]) {
        expect(AdaptiveLayout.isWide(size), isFalse);
        expect(AdaptiveLayout.usePlayerSideLayout(size), isFalse);
        expect(AdaptiveLayout.useSideNavigation(size), isFalse);
      }
    });

    test('landscape phones get the side player layout and rail', () {
      for (final size in const [
        Size(520, 320),
        Size(568, 320),
        Size(640, 360),
        Size(891, 411),
      ]) {
        expect(AdaptiveLayout.isWide(size), isTrue);
        expect(AdaptiveLayout.usePlayerSideLayout(size), isTrue);
        expect(AdaptiveLayout.useSideNavigation(size), isTrue);
      }
    });

    test('tablets follow window shape, not hardware class', () {
      expect(
        AdaptiveLayout.usePlayerSideLayout(const Size(800, 1280)),
        isFalse,
      );
      expect(AdaptiveLayout.usePlayerSideLayout(const Size(1280, 800)), isTrue);
      expect(AdaptiveLayout.useSideNavigation(const Size(800, 1280)), isFalse);
      expect(AdaptiveLayout.useSideNavigation(const Size(1280, 800)), isTrue);
    });

    test(
      'compact side mini player only belongs to short landscape windows',
      () {
        for (final size in const [
          Size(520, 320),
          Size(640, 360),
          Size(891, 411),
        ]) {
          expect(AdaptiveLayout.useCompactLandscapeMiniPlayer(size), isTrue);
        }
        for (final size in const [
          Size(360, 640),
          Size(640, 480),
          Size(1280, 650),
        ]) {
          expect(AdaptiveLayout.useCompactLandscapeMiniPlayer(size), isFalse);
        }
      },
    );

    test('a narrow landscape window is not treated as wide', () {
      expect(AdaptiveLayout.usePlayerSideLayout(const Size(520, 600)), isFalse);
      expect(AdaptiveLayout.useSideNavigation(const Size(520, 600)), isFalse);
      expect(AdaptiveLayout.useSideNavigation(const Size(519, 320)), isFalse);
    });

    test('constraints equivalents agree with window size', () {
      const constraints = BoxConstraints.tightFor(width: 640, height: 360);
      expect(
        AdaptiveLayout.usePlayerSideLayoutFor(constraints),
        AdaptiveLayout.usePlayerSideLayout(const Size(640, 360)),
      );
      expect(
        AdaptiveLayout.usePlayerSideLayoutFor(
          const BoxConstraints.tightFor(width: 360, height: 640),
        ),
        isFalse,
      );
    });
  });
}
