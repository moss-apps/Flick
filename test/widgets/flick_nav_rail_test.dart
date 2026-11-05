import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    locale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    localeResolutionCallback: resolveAppLocale,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(568, 320),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(height: 320, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rail scrolls every configured destination in a short window', (
    tester,
  ) async {
    final config = NavBarConfig(enabledButtons: NavBarButton.values);

    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(
        _host(
          FlickNavRail(
            currentIndex: NavBarButton.menu.pageIndex,
            config: config,
            onTap: (_) {},
            onBottomBarSettings: () {},
          ),
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'textScale=$scale');
      expect(find.byIcon(LucideIcons.search), findsOneWidget);

      await tester.ensureVisible(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scrolled scale=$scale');
    }
  });

  testWidgets('missing essential destinations stay reachable from the rail', (
    tester,
  ) async {
    const config = NavBarConfig(
      enabledButtons: [NavBarButton.albums, NavBarButton.favorites],
    );

    await tester.pumpWidget(
      _host(
        FlickNavRail(
          currentIndex: NavBarButton.albums.pageIndex,
          config: config,
          onTap: (_) {},
          onBottomBarSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Menu, Songs and Settings are supplied by the overflow sheet.
    expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
    expect(find.byIcon(LucideIcons.music), findsOneWidget);
    expect(find.byIcon(LucideIcons.settings), findsWidgets);
  });
}
