import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flick/widgets/common/flick_option_tile.dart';

Widget _host(Widget child) {
  return MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: child));
}

Future<void> _openConfirm(
  WidgetTester tester, {
  bool destructive = false,
}) async {
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => FlickDialogs.confirm(
              context,
              title: 'Delete thing?',
              message: 'This cannot be undone.',
              confirmLabel: 'Delete',
              destructive: destructive,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openInput(
  WidgetTester tester, {
  String? Function(String)? validator,
}) async {
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => FlickDialogs.input(
              context,
              title: 'Name it',
              hintText: 'Playlist name',
              validator: validator,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlickDialogs.confirm', () {
    testWidgets('returns true when confirm is tapped', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await FlickDialogs.confirm(
                    context,
                    title: 'Sure?',
                    confirmLabel: 'Yes',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Sure?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result = true;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await FlickDialogs.confirm(
                    context,
                    title: 'Sure?',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('destructive variant shows warning icon', (tester) async {
      await _openConfirm(tester, destructive: true);
      expect(
        find.byIcon(Icons.warning_amber_rounded),
        findsOneWidget,
      );
    });
  });

  group('FlickDialogs.input', () {
    testWidgets('returns trimmed text and closes on submit', (tester) async {
      String? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await FlickDialogs.input(
                    context,
                    title: 'Name it',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(FlickTextField), '  Roadhouse  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, 'Roadhouse');
    });

    testWidgets('stays open on empty submit, returns null on cancel',
        (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await FlickDialogs.input(
                    context,
                    title: 'Name it',
                    hintText: 'Playlist name',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Name it'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Name it'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('shows validator error and keeps dialog open', (tester) async {
      await _openInput(
        tester,
        validator: (value) =>
            value.length < 3 ? 'Too short' : null,
      );
      await tester.enterText(find.byType(FlickTextField), 'ab');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Too short'), findsOneWidget);
      expect(find.text('Name it'), findsOneWidget);
    });
  });

  group('FlickDialog', () {
    testWidgets('renders title, content and actions', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showFlickDialog<void>(
                  context: context,
                  barrierLabel: 'info',
                  builder: (_) => FlickDialog(
                    title: 'Hello',
                    icon: Icons.info_outline,
                    content: const Text('Body copy'),
                    actions: [
                      FlickDialogButton(
                        label: 'OK',
                        style: FlickDialogButtonStyle.primary,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Body copy'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('two buttons share one line with equal widths', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showFlickDialog<void>(
                  context: context,
                  barrierLabel: 'confirm',
                  builder: (_) => FlickDialog(
                    title: 'Delete?',
                    actions: [
                      FlickDialogButton(label: 'Cancel', onPressed: () {}),
                      FlickDialogButton(
                        label: 'Delete Files',
                        style: FlickDialogButtonStyle.destructive,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The two button slots (the title row also uses Expanded).
      final buttonSlots = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .where((e) => e.child is FlickDialogButton)
          .map((e) => tester.getRect(find.byElementPredicate(
                (el) => el.widget == e,
              )))
          .toList();
      expect(buttonSlots.length, 2);
      final first = buttonSlots.first;
      final second = buttonSlots.last;

      // Equal width, stretched across the dialog, on one shared line.
      expect(first.width, second.width);
      expect(first.width, greaterThan(150));
      expect(first.top, lessThan(second.bottom));
      expect(second.top, lessThan(first.bottom));

      // Labels centered symmetrically about the dialog center.
      final cancelRect = tester.getRect(find.text('Cancel'));
      final deleteRect = tester.getRect(find.text('Delete Files'));
      final screenCenter =
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
      expect(
        (screenCenter - cancelRect.center.dx).abs(),
        moreOrLessEquals((deleteRect.center.dx - screenCenter).abs()),
      );
    });

    testWidgets('three buttons stack full-width with equal sizes', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showFlickDialog<void>(
                  context: context,
                  barrierLabel: 'three',
                  builder: (_) => FlickDialog(
                    title: 'Delete 5 songs?',
                    icon: Icons.warning_amber_rounded,
                    destructive: true,
                    content: const Text('Remove or delete'),
                    actions: [
                      FlickDialogButton(label: 'Cancel', onPressed: () {}),
                      FlickDialogButton(
                        label: 'Remove from Library',
                        onPressed: () {},
                      ),
                      FlickDialogButton(
                        label: 'Delete Files',
                        style: FlickDialogButtonStyle.destructive,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancelRect = tester.getRect(
        find.widgetWithText(FlickDialogButton, 'Cancel'),
      );
      final removeRect = tester.getRect(
        find.widgetWithText(FlickDialogButton, 'Remove from Library'),
      );
      final deleteRect = tester.getRect(
        find.widgetWithText(FlickDialogButton, 'Delete Files'),
      );

      // Stacked vertically, left-aligned, equal width/height.
      expect(removeRect.top, greaterThan(cancelRect.bottom - 1));
      expect(deleteRect.top, greaterThan(removeRect.bottom - 1));
      expect(cancelRect.left, moreOrLessEquals(removeRect.left, epsilon: 1.5));
      expect(
        removeRect.left,
        moreOrLessEquals(deleteRect.left, epsilon: 1.5),
      );
      expect(
        cancelRect.width,
        moreOrLessEquals(removeRect.width, epsilon: 1.5),
      );
      expect(
        removeRect.width,
        moreOrLessEquals(deleteRect.width, epsilon: 1.5),
      );
      expect(cancelRect.width, greaterThan(250));
      expect(
        cancelRect.height,
        moreOrLessEquals(removeRect.height, epsilon: 1.0),
      );
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('FlickOptionTile', () {
    testWidgets('fires tap and shows selection state', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              FlickOptionTile(
                title: 'Highest Quality',
                description: 'Best output available',
                selected: true,
                onTap: () => taps++,
              ),
              FlickOptionTile(title: 'Compatibility', onTap: () {}),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Highest Quality'), findsOneWidget);
      expect(find.text('Compatibility'), findsOneWidget);

      await tester.tap(find.text('Highest Quality'));
      expect(taps, 1);
    });
  });
}
