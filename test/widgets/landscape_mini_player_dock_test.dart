import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/widgets/common/landscape_mini_player_dock.dart';

const _bottomKey = ValueKey('bottom_player');
const _sideKey = ValueKey('side_player');

Widget _host({
  required bool sideDocked,
  bool reducedMotion = false,
  EdgeInsets padding = EdgeInsets.zero,
  Widget bottomPlayer = const SizedBox.expand(key: _bottomKey),
  Widget sidePlayer = const SizedBox.expand(key: _sideKey),
}) => ProviderScope(
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 400),
        padding: padding,
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              left: 76,
              child: LandscapeMiniPlayerDock(
                sideDocked: sideDocked,
                bottomPlayerHeight: 80,
                bottomPlayer: bottomPlayer,
                sidePlayer: sidePlayer,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _Counts {
  int builds = 0;
  int layouts = 0;
}

class _PlayerProbe extends StatelessWidget {
  const _PlayerProbe(this.counts);

  final _Counts counts;

  @override
  Widget build(BuildContext context) {
    counts.builds++;
    return _LayoutProbe(counts);
  }
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe(this.counts) : super(child: const SizedBox.expand());

  final _Counts counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutCounter(counts);
}

class _LayoutCounter extends RenderProxyBox {
  _LayoutCounter(this.counts);

  final _Counts counts;

  @override
  void performLayout() {
    counts.layouts++;
    super.performLayout();
  }
}

void main() {
  setUp(() => AppConstants.setAnimationsEnabled(true));
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  Future<void> setLandscape(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('starts at either dock without an entrance animation', (
    tester,
  ) async {
    await setLandscape(tester);
    await tester.pumpWidget(_host(sideDocked: false));
    await tester.pump();
    expect(
      tester.getRect(find.byKey(_bottomKey)),
      const Rect.fromLTWH(76, 320, 724, 80),
    );
    expect(find.byKey(_sideKey), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host(sideDocked: true));
    await tester.pump();
    expect(
      tester.getRect(find.byKey(_sideKey)),
      const Rect.fromLTWH(730, 0, 64, 400),
    );
    expect(find.byKey(_bottomKey), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('glides both fixed-size players along one path in 220ms', (
    tester,
  ) async {
    await setLandscape(tester);
    await tester.pumpWidget(_host(sideDocked: false));
    final start = tester.getRect(find.byKey(_bottomKey));

    await tester.pumpWidget(_host(sideDocked: true));
    expect(tester.getRect(find.byKey(_bottomKey)), start);
    await tester.pump(const Duration(milliseconds: 80));

    final bottom = tester.getRect(find.byKey(_bottomKey));
    final side = tester.getRect(find.byKey(_sideKey));
    expect(tester.getSize(find.byKey(_bottomKey)), start.size);
    expect(tester.getSize(find.byKey(_sideKey)), const Size(64, 400));
    expect(bottom.center.dx, greaterThan(start.center.dx));
    expect(bottom.center.dx, lessThan(762));
    expect(bottom.center.dy, lessThan(start.center.dy));
    expect((bottom.center - side.center).distance, lessThan(0.001));

    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byKey(_bottomKey), findsNothing);
    expect(tester.getCenter(find.byKey(_sideKey)), const Offset(762, 200));
    // The ticker stops on the frame following the exact duration boundary.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host(sideDocked: false));
    await tester.pump(const Duration(milliseconds: 80));
    final returning = tester.getCenter(find.byKey(_bottomKey));
    expect(returning.dx, greaterThan(start.center.dx));
    expect(returning.dx, lessThan(762));
    expect(returning.dy, greaterThan(200));
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getRect(find.byKey(_bottomKey)), start);
    expect(find.byKey(_sideKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('rapid reversals continue from the current position', (
    tester,
  ) async {
    await setLandscape(tester);
    await tester.pumpWidget(_host(sideDocked: false));
    await tester.pumpWidget(_host(sideDocked: true));
    await tester.pump(const Duration(milliseconds: 64));
    final before = tester.getCenter(find.byKey(_sideKey));

    await tester.pumpWidget(_host(sideDocked: false));
    expect(tester.getCenter(find.byKey(_sideKey)), before);
    await tester.pump(const Duration(milliseconds: 32));
    final reversed = tester.getCenter(find.byKey(_bottomKey));
    expect(reversed.dx, lessThan(before.dx));
    expect(reversed.dy, greaterThan(before.dy));

    await tester.pumpWidget(_host(sideDocked: true));
    expect(tester.getCenter(find.byKey(_bottomKey)), reversed);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(_bottomKey), findsNothing);
    expect(find.byKey(_sideKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animation ticks do not rebuild or lay out either player', (
    tester,
  ) async {
    await setLandscape(tester);
    final bottom = _Counts();
    final side = _Counts();
    final bottomPlayer = _PlayerProbe(bottom);
    final sidePlayer = _PlayerProbe(side);

    Future<void> show(bool sideDocked) => tester.pumpWidget(
      _host(
        sideDocked: sideDocked,
        bottomPlayer: bottomPlayer,
        sidePlayer: sidePlayer,
      ),
    );

    await show(false);
    await show(true);
    await tester.pump(const Duration(milliseconds: 16));
    final builds = (bottom.builds, side.builds);
    final layouts = (bottom.layouts, side.layouts);

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect((bottom.builds, side.builds), builds);
    expect((bottom.layouts, side.layouts), layouts);

    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(_PlayerProbe), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion snaps to the target, including mid-flight', (
    tester,
  ) async {
    await setLandscape(tester);
    await tester.pumpWidget(_host(sideDocked: false));
    await tester.pumpWidget(_host(sideDocked: true));
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pumpWidget(_host(sideDocked: true, reducedMotion: true));
    expect(find.byKey(_bottomKey), findsNothing);
    expect(tester.getCenter(find.byKey(_sideKey)), const Offset(762, 200));

    await tester.pumpWidget(_host(sideDocked: false, reducedMotion: true));
    expect(find.byKey(_sideKey), findsNothing);
    expect(tester.getCenter(find.byKey(_bottomKey)), const Offset(438, 360));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('respects the app-wide animations switch', (tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(_host(sideDocked: true));
    AppConstants.setAnimationsEnabled(false);
    await tester.pumpWidget(_host(sideDocked: false));
    expect(find.byKey(_sideKey), findsNothing);
    expect(tester.getCenter(find.byKey(_bottomKey)), const Offset(438, 360));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('keeps safe insets and one tutorial anchor through handoffs', (
    tester,
  ) async {
    await setLandscape(tester);
    const padding = EdgeInsets.only(top: 24, right: 20, bottom: 16);
    await tester.pumpWidget(_host(sideDocked: false, padding: padding));
    expect(
      tester.getRect(find.byKey(_bottomKey)),
      const Rect.fromLTWH(76, 304, 704, 80),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LandscapeMiniPlayerDock)),
    );
    final registry = container.read(tutorialTargetRegistryProvider);

    await tester.pumpWidget(_host(sideDocked: true, padding: padding));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(TutorialTargetAnchor), findsOneWidget);
    expect(
      registry.rectFor(TutorialTarget.miniPlayer),
      tester.getRect(find.byKey(_sideKey)),
    );

    await tester.pump(const Duration(milliseconds: 140));
    expect(
      tester.getRect(find.byKey(_sideKey)),
      const Rect.fromLTWH(710, 24, 64, 360),
    );
    expect(
      registry.rectFor(TutorialTarget.miniPlayer),
      tester.getRect(find.byKey(_sideKey)),
    );
  });

  testWidgets(
    'only the target is interactive, ticking, and available to heroes',
    (tester) async {
      await setLandscape(tester);
      var bottomTaps = 0;
      var sideTaps = 0;
      final bottomPlayer = Hero(
        tag: 'mini_player_art',
        child: GestureDetector(
          key: _bottomKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => bottomTaps++,
          child: const SizedBox.expand(),
        ),
      );
      final sidePlayer = Hero(
        tag: 'mini_player_art',
        child: GestureDetector(
          key: _sideKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => sideTaps++,
          child: const SizedBox.expand(),
        ),
      );
      Future<void> show(bool sideDocked) => tester.pumpWidget(
        _host(
          sideDocked: sideDocked,
          bottomPlayer: bottomPlayer,
          sidePlayer: sidePlayer,
        ),
      );

      await show(false);
      await show(true);
      await tester.pump(const Duration(milliseconds: 80));
      final bottomContext = tester.element(find.byKey(_bottomKey));
      final sideContext = tester.element(find.byKey(_sideKey));
      expect(TickerMode.valuesOf(bottomContext).enabled, isFalse);
      expect(TickerMode.valuesOf(sideContext).enabled, isTrue);
      expect(
        bottomContext.findAncestorWidgetOfExactType<HeroMode>()!.enabled,
        isFalse,
      );
      expect(
        sideContext.findAncestorWidgetOfExactType<HeroMode>()!.enabled,
        isTrue,
      );
      expect(
        bottomContext
            .findAncestorWidgetOfExactType<ExcludeSemantics>()!
            .excluding,
        isTrue,
      );
      expect(
        sideContext
            .findAncestorWidgetOfExactType<ExcludeSemantics>()!
            .excluding,
        isFalse,
      );
      await tester.tap(find.byKey(_sideKey));
      expect(sideTaps, 1);
      expect(bottomTaps, 0);

      Navigator.of(sideContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Hero(
              tag: 'mini_player_art',
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps dock state when an upper sibling disappears with the mode change',
    (tester) async {
      await setLandscape(tester);

      // Mirrors MainShell: a conditional overlay above the dock (the nav-inset
      // blocker) is removed in the same rebuild that engages the side player.
      Widget shellHost({required bool sideDocked}) => ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 400)),
            child: Scaffold(
              body: Stack(
                children: [
                  if (!sideDocked)
                    Positioned(
                      left: 76,
                      right: 0,
                      bottom: 0,
                      height: 90,
                      child: const ColoredBox(
                        color: Colors.black,
                        child: SizedBox.expand(key: ValueKey('blocker')),
                      ),
                    ),
                  Positioned.fill(
                    key: const ValueKey('landscape_mini_player_dock'),
                    left: 76,
                    child: LandscapeMiniPlayerDock(
                      sideDocked: sideDocked,
                      bottomPlayerHeight: 80,
                      bottomPlayer: const SizedBox.expand(key: _bottomKey),
                      sidePlayer: const SizedBox.expand(key: _sideKey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(shellHost(sideDocked: false));
      final start = tester.getRect(find.byKey(_bottomKey));

      // The blocker vanishes as the side dock engages; the glide must still
      // start from the bottom instead of remounting at the target.
      await tester.pumpWidget(shellHost(sideDocked: true));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_bottomKey), findsOneWidget);
      expect(find.byKey(_sideKey), findsOneWidget);
      final mid = tester.getRect(find.byKey(_bottomKey));
      expect(mid.center.dx, greaterThan(start.center.dx));
      expect(mid.center.dx, lessThan(762));

      await tester.pump(const Duration(milliseconds: 204));
      expect(find.byKey(_bottomKey), findsNothing);
      expect(tester.getCenter(find.byKey(_sideKey)), const Offset(762, 200));

      // Returning to the bottom re-inserts the blocker; the outgoing side
      // strip must still glide back instead of vanishing instantly.
      await tester.pumpWidget(shellHost(sideDocked: false));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_sideKey), findsOneWidget);
      expect(find.byKey(_bottomKey), findsOneWidget);
      final back = tester.getCenter(find.byKey(_sideKey));
      expect(back.dy, greaterThan(200));
      expect(back.dy, lessThan(360));

      await tester.pump(const Duration(milliseconds: 204));
      expect(find.byKey(_sideKey), findsNothing);
      expect(tester.getRect(find.byKey(_bottomKey)), start);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
