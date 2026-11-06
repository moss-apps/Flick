import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/orbit_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/providers.dart';

Widget _host() => ProviderScope(
  overrides: [currentSongProvider.overrideWithValue(null)],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    home: const OrbitSettingsScreen(),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile selector switches without rotating the window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final copy = lookupFlickLocalizations(kFallbackLocale);
    expect(find.text(copy.portrait), findsOneWidget);
    expect(find.text(copy.landscape), findsOneWidget);
    expect(find.text(copy.horizontalReach), findsOneWidget);
    expect(find.text(copy.cardSize), findsOneWidget);

    await tester.tap(find.text(copy.landscape));
    await tester.pumpAndSettle();

    expect(find.text(copy.horizontalReach), findsNothing);
    expect(find.text(copy.cardSize), findsNothing);
    expect(find.text(copy.cardWidth), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
