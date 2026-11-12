import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/visualizer_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/visualizer_source.dart';

class _FakeVisualizerSource extends VisualizerSource {
  @override
  VisualizerSourceMode get mode => VisualizerSourceMode.rustFft;

  @override
  List<double>? get bars => null;

  @override
  bool get isAvailable => true;

  @override
  bool get needsPermission => false;

  @override
  Future<bool> prepare() async => isAvailable;

  @override
  void acquire() {}

  @override
  void release() {}
}

class _PreviewPreferences extends AppPreferencesNotifier {
  _PreviewPreferences(this.preferences);

  final AppPreferences preferences;

  @override
  AppPreferences build() => preferences;
}

Widget _host({
  bool animationsEnabled = true,
  bool systemReducedMotion = false,
}) => ProviderScope(
  overrides: [
    currentSongProvider.overrideWithValue(null),
    visualizerSourceProvider.overrideWith((ref) => _FakeVisualizerSource()),
    appPreferencesProvider.overrideWith(
      () => _PreviewPreferences(
        AppPreferences(animationsEnabled: animationsEnabled),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: systemReducedMotion),
      child: child!,
    ),
    home: const VisualizerSettingsScreen(),
  ),
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool animationsEnabled = true,
  bool systemReducedMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _host(
      animationsEnabled: animationsEnabled,
      systemReducedMotion: systemReducedMotion,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('explains that Flick animations keep the visualizer still', (
    tester,
  ) async {
    await _pumpScreen(tester, animationsEnabled: false);
    final copy = lookupFlickLocalizations(kFallbackLocale);

    expect(find.text(copy.visualizerAnimationsOffTitle), findsOneWidget);
    expect(find.text(copy.visualizerAnimationsOffApp), findsOneWidget);
    expect(find.text(copy.visualizerAnimationsOffSystem), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains that Android accessibility settings keep it still', (
    tester,
  ) async {
    await _pumpScreen(tester, systemReducedMotion: true);
    final copy = lookupFlickLocalizations(kFallbackLocale);

    expect(find.text(copy.visualizerAnimationsOffTitle), findsOneWidget);
    expect(find.text(copy.visualizerAnimationsOffSystem), findsOneWidget);
    expect(find.text(copy.visualizerAnimationsOffApp), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show the notice while motion is allowed', (
    tester,
  ) async {
    await _pumpScreen(tester);
    final copy = lookupFlickLocalizations(kFallbackLocale);

    expect(find.text(copy.visualizerAnimationsOffTitle), findsNothing);
    expect(find.text(copy.visualizerAnimationsOffApp), findsNothing);
    expect(find.text(copy.visualizerAnimationsOffSystem), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
