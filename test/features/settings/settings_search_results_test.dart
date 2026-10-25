import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/features/settings/data/settings_search.dart';
import 'package:flick/features/settings/widgets/settings_search_results.dart';
import 'package:flick/l10n/settings_l10n.dart';

void main() {
  testWidgets(
    'empty state is centered below the header with or without keyboard',
    (tester) async {
      const query = 'unknown';
      const headerKey = ValueKey('header');
      for (final keyboardInset in [0.0, 300.0]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(key: headerKey, height: 120),
                  Expanded(
                    child: SettingsSearchResults(
                      query: query,
                      results: const [],
                      onOpen: (_, _) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final screen = tester.getRect(find.byType(Scaffold));
        final area = Rect.fromLTRB(
          screen.left,
          tester.getRect(find.byKey(headerKey)).bottom,
          screen.right,
          screen.bottom - keyboardInset,
        );
        final icon = tester.getRect(find.byIcon(LucideIcons.searchX));
        final message = tester.getRect(find.text(l10n.noMatchesFor(query)));
        final content = icon.expandToInclude(message);
        expect(content.center.dx, closeTo(area.center.dx, 0.1));
        expect(content.center.dy, closeTo(area.center.dy, 0.1));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('empty state remains scrollable when space is limited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SettingsSearchResults(
            query: 'a very long query that does not match any setting',
            results: const [],
            onOpen: (_, _) {},
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('page and setting taps only return navigation targets', (
    tester,
  ) async {
    var built = false;
    final page = SettingsSearchPage(
      id: 'audio',
      title: 'Audio',
      category: 'Media',
      icon: Icons.headphones,
      buildPage: (_) {
        built = true;
        return const SizedBox();
      },
      sections: const [
        SettingsSearchSection('gain', 'ReplayGain', [
          SettingsSearchItem('preamp', 'Pre-amp'),
        ]),
      ],
    );
    final opened = <(String, String?)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSearchResults(
            query: 'preamp',
            results: searchSettings('preamp', [page]),
            onOpen: (page, section) => opened.add((page.id, section)),
          ),
        ),
      ),
    );
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('ReplayGain'), findsOneWidget);
    await tester.tap(find.text('Pre-amp'));
    await tester.tap(find.text('Audio'));
    expect(opened, [('audio', 'gain'), ('audio', null)]);
    expect(built, isFalse);
  });

  testWidgets(
    'empty state and long text fit a narrow screen at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const query = 'a very long query that does not match any setting';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SettingsSearchResults(
              query: query,
              results: const [],
              onOpen: (_, _) {},
            ),
          ),
        ),
      );
      expect(find.text(l10n.noMatchesFor(query)), findsOneWidget);
      expect(tester.takeException(), isNull);

      final page = SettingsSearchPage(
        id: 'long',
        title: 'Playback and display customization',
        category: 'Music and media preferences',
        icon: Icons.play_arrow,
        buildPage: (_) => const SizedBox(),
        sections: const [
          SettingsSearchSection('background', 'Background playback options', [
            SettingsSearchItem(
              'keepPlaying',
              'Keep playing after closing the app',
            ),
          ]),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SettingsSearchResults(
              query: 'keep playing',
              results: searchSettings('keep playing', [page]),
              onOpen: (_, _) {},
            ),
          ),
        ),
      );
      expect(find.text('Keep playing after closing the app'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
