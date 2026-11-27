import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/settings/widgets/settings_scroll_target.dart';

Widget _body(
  ScrollController controller, {
  String? target,
  bool showTarget = true,
}) {
  return SettingsScrollTarget(
    initialSection: target,
    child: SingleChildScrollView(
      controller: controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 1000),
          if (showTarget)
            const SettingsSectionAnchor(
              id: 'volume',
              child: SizedBox(height: 50, child: Text('Volume')),
            ),
          const SizedBox(height: 1000),
        ],
      ),
    ),
  );
}

Widget _searchBody(
  ScrollController controller, {
  required String arrivalTitle,
  String rowTitle = 'Ignore tracks under 60 seconds',
  String? target = 'volume',
}) {
  return SettingsSearchArrival(
    itemTitle: arrivalTitle,
    child: SettingsScrollTarget(
      initialSection: target,
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 1000),
            const SettingsSectionAnchor(
              id: 'volume',
              child: SizedBox(
                key: ValueKey('section'),
                height: 50,
                child: Text('Volume'),
              ),
            ),
            SettingsSearchAnchor(
              titles: [rowTitle],
              child: SizedBox(
                key: const ValueKey('row'),
                height: 80,
                child: Text(rowTitle),
              ),
            ),
            const SizedBox(height: 1000),
          ],
        ),
      ),
    ),
  );
}

Color? _frameColor(WidgetTester tester, Finder child) {
  final frame = tester.widget<AnimatedContainer>(
    find.ancestor(of: child, matching: find.byType(AnimatedContainer)).first,
  );
  return (frame.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets(
    'reveals a stable ID once and does not override later scrolling',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _body(controller, target: 'volume')),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(1000, 1));
      controller.jumpTo(200);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _body(controller, target: 'volume')),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown or absent targets leave the page at the top', (
    tester,
  ) async {
    for (final target in [null, 'missing']) {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: ValueKey(target),
            body: _body(controller, target: target),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });

  testWidgets('late-built conditional sections are revealed safely', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _body(controller, target: 'volume', showTarget: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _body(controller, target: 'volume')),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(1000, 1));
  });

  testWidgets('user scrolling cancels a pending conditional section jump', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _body(controller, target: 'volume', showTarget: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final offset = controller.offset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _body(controller, target: 'volume')),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
  });

  testWidgets(
    'route animation finishes before scrolling and disposed routes are safe',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: _body(controller, target: 'volume')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 0);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(1000, 1));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: _body(controller, target: 'volume')),
        ),
      );
      await tester.pump();
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced-motion navigation jumps without animating', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: _body(controller, target: 'volume')),
        ),
      ),
    );
    expect(controller.offset, closeTo(1000, 1));
    expect(controller.position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('search arrival scrolls to the exact row and highlights it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _searchBody(
            controller,
            arrivalTitle: 'Ignore tracks under 60 seconds',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(956.4, 1));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('row'))).dy,
      closeTo(93.6, 1),
    );
    expect(
      _frameColor(tester, find.byKey(const ValueKey('row'))),
      isNot(Colors.transparent),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      _frameColor(tester, find.byKey(const ValueKey('row'))),
      Colors.transparent,
    );
  });

  testWidgets('repeated row titles resolve to the selected section', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSearchArrival(
            itemTitle: 'Text Size',
            child: SettingsScrollTarget(
              initialSection: 'second',
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 100),
                    const SettingsSectionAnchor(
                      id: 'first',
                      child: SizedBox(height: 40, child: Text('First')),
                    ),
                    SettingsSearchAnchor(
                      titles: const ['Text Size'],
                      child: const SizedBox(
                        key: ValueKey('firstRow'),
                        height: 80,
                        child: Text('Text Size'),
                      ),
                    ),
                    const SizedBox(height: 300),
                    const SettingsSectionAnchor(
                      id: 'second',
                      child: SizedBox(
                        key: ValueKey('secondSection'),
                        height: 40,
                        child: Text('Second'),
                      ),
                    ),
                    SettingsSearchAnchor(
                      titles: const ['Text Size'],
                      child: const SizedBox(
                        key: ValueKey('secondRow'),
                        height: 80,
                        child: Text('Text Size'),
                      ),
                    ),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('secondRow'))).dy,
      closeTo(93.6, 1),
    );
    expect(
      _frameColor(tester, find.byKey(const ValueKey('firstRow'))),
      Colors.transparent,
    );
    expect(
      _frameColor(tester, find.byKey(const ValueKey('secondRow'))),
      isNot(Colors.transparent),
    );
  });

  testWidgets('missing rows fall back to their section and highlight it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _searchBody(controller, arrivalTitle: 'Hidden control'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(1000, 1));
    expect(
      _frameColor(tester, find.byKey(const ValueKey('section'))),
      isNot(Colors.transparent),
    );
  });

  testWidgets('reduced motion highlights the arrived row immediately', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: _searchBody(
              controller,
              arrivalTitle: 'Ignore tracks under 60 seconds',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.offset, closeTo(956.4, 1));
    expect(
      _frameColor(tester, find.byKey(const ValueKey('row'))),
      isNot(Colors.transparent),
    );
  });
}
