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
}
