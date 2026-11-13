import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/visualizer_settings_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/lock_screen_visualizer_provider.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/lock_screen_visualizer_service.dart';
import 'package:flick/services/visualizer_source.dart';

class _FakeVisualizerSource extends VisualizerSource {
  _FakeVisualizerSource(this.mode);

  @override
  final VisualizerSourceMode mode;

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

  @override
  Future<void> get loaded async {}
}

class _Viewer implements LockScreenVisualizerService {
  final result = Completer<bool>();
  int opened = 0;

  @override
  Future<bool> open() {
    opened++;
    return result.future;
  }

  @override
  void configure(AppPreferences preferences, {Color? albumColor}) {}

  @override
  void dispose() {}
}

Widget _host({
  bool animationsEnabled = true,
  bool systemReducedMotion = false,
  bool lockScreenEnabled = false,
  bool simulatedAodEnabled = false,
  bool inAppEnabled = true,
  VisualizerSourceMode sourceMode = VisualizerSourceMode.rustFft,
  Locale locale = kFallbackLocale,
  double textScale = 1,
  _Viewer? viewer,
}) => ProviderScope(
  overrides: [
    currentSongProvider.overrideWithValue(null),
    visualizerSourceProvider.overrideWith(
      (ref) => _FakeVisualizerSource(sourceMode),
    ),
    if (viewer != null) lockScreenVisualizerProvider.overrideWithValue(viewer),
    appPreferencesProvider.overrideWith(
      () => _PreviewPreferences(
        AppPreferences(
          animationsEnabled: animationsEnabled,
          lockScreenVisualizerEnabled: lockScreenEnabled,
          simulatedAodEnabled: simulatedAodEnabled,
          visualizerEnabled: inAppEnabled,
        ),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: systemReducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: const VisualizerSettingsScreen(),
  ),
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  bool animationsEnabled = true,
  bool systemReducedMotion = false,
  bool lockScreenEnabled = false,
  bool simulatedAodEnabled = false,
  bool inAppEnabled = true,
  VisualizerSourceMode sourceMode = VisualizerSourceMode.rustFft,
  Locale locale = kFallbackLocale,
  double textScale = 1,
  Size size = const Size(411, 900),
  _Viewer? viewer,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _host(
      animationsEnabled: animationsEnabled,
      systemReducedMotion: systemReducedMotion,
      lockScreenEnabled: lockScreenEnabled,
      simulatedAodEnabled: simulatedAodEnabled,
      inAppEnabled: inAppEnabled,
      sourceMode: sourceMode,
      locale: locale,
      textScale: textScale,
      viewer: viewer,
    ),
  );
  await tester.pumpAndSettle();
}

const _overlayChannel = MethodChannel('com.mossapps.flick/overlay');

void _mockOverlayPermission(bool allowed) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_overlayChannel, (call) async {
    return switch (call.method) {
      'canDrawOverlays' || 'requestOverlayPermission' => allowed,
      _ => null,
    };
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_overlayChannel, null));
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

  testWidgets(
    'lock-screen opt-in is independent and never opens automatically',
    (tester) async {
      final viewer = _Viewer();
      await _pumpScreen(tester, inAppEnabled: false, viewer: viewer);
      final copy = lookupFlickLocalizations(kFallbackLocale);
      final action = find.widgetWithText(
        ActionButton,
        copy.lockScreenVisualizerOpen,
      );
      expect(tester.widget<ActionButton>(action).onTap, isNull);
      final toggle = find.widgetWithText(
        ToggleSetting,
        copy.lockScreenVisualizerTitle,
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<ActionButton>(action).onTap, isNotNull);
      expect(tester.widget<ToggleSetting>(toggle).value, isTrue);
      final inApp = find.widgetWithText(ToggleSetting, copy.visualizer);
      expect(tester.widget<ToggleSetting>(inApp).value, isFalse);
      expect(viewer.opened, 0);
    },
  );

  for (final mode in [
    VisualizerSourceMode.unavailable,
    VisualizerSourceMode.dsdUnavailable,
  ]) {
    testWidgets('$mode cannot open the viewer even when enabled', (
      tester,
    ) async {
      await _pumpScreen(tester, lockScreenEnabled: true, sourceMode: mode);
      final copy = lookupFlickLocalizations(kFallbackLocale);
      final action = find.widgetWithText(
        ActionButton,
        copy.lockScreenVisualizerOpen,
      );
      expect(tester.widget<ActionButton>(action).onTap, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'simulated AOD enables the required lock-screen opt-in without opening',
    (tester) async {
      _mockOverlayPermission(true);
      final viewer = _Viewer();
      await _pumpScreen(tester, viewer: viewer);
      final copy = lookupFlickLocalizations(kFallbackLocale);
      final mainToggle = find.widgetWithText(
        ToggleSetting,
        copy.lockScreenVisualizerTitle,
      );
      final simulatedToggle = find.widgetWithText(
        ToggleSetting,
        copy.lockScreenVisualizerSimulatedTitle,
      );
      await tester.ensureVisible(simulatedToggle);
      expect(tester.widget<ToggleSetting>(simulatedToggle).value, isFalse);
      await tester.tap(simulatedToggle);
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSetting>(mainToggle).value, isTrue);
      expect(tester.widget<ToggleSetting>(simulatedToggle).value, isTrue);
      expect(viewer.opened, 0);

      await tester.ensureVisible(mainToggle);
      await tester.tap(mainToggle);
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSetting>(mainToggle).value, isFalse);
      expect(tester.widget<ToggleSetting>(simulatedToggle).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('simulated AOD stays off when overlay permission is denied', (
    tester,
  ) async {
    _mockOverlayPermission(false);
    await _pumpScreen(tester);
    final copy = lookupFlickLocalizations(kFallbackLocale);
    final mainToggle = find.widgetWithText(
      ToggleSetting,
      copy.lockScreenVisualizerTitle,
    );
    final simulatedToggle = find.widgetWithText(
      ToggleSetting,
      copy.lockScreenVisualizerSimulatedTitle,
    );
    await tester.ensureVisible(simulatedToggle);
    await tester.tap(simulatedToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<ToggleSetting>(mainToggle).value, isFalse);
    expect(tester.widget<ToggleSetting>(simulatedToggle).value, isFalse);
    expect(
      find.text(copy.lockScreenVisualizerSimulatedPermission),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit open is single-flight and explains a failed launch', (
    tester,
  ) async {
    final viewer = _Viewer();
    await _pumpScreen(tester, lockScreenEnabled: true, viewer: viewer);
    final copy = lookupFlickLocalizations(kFallbackLocale);
    final action = find.widgetWithText(
      ActionButton,
      copy.lockScreenVisualizerOpen,
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    expect(viewer.opened, 1);
    expect(tester.widget<ActionButton>(action).onTap, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    viewer.result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text(copy.lockScreenVisualizerOpenFailed), findsOneWidget);
    expect(tester.widget<ActionButton>(action).onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [
    const Locale('en'),
    const Locale('es'),
    const Locale('zh', 'CN'),
  ]) {
    testWidgets(
      '$locale lock-screen copy fits a narrow screen with large text',
      (tester) async {
        await _pumpScreen(
          tester,
          locale: locale,
          textScale: 1.8,
          size: const Size(320, 640),
        );
        final copy = lookupFlickLocalizations(locale);
        final action = find.widgetWithText(
          ActionButton,
          copy.lockScreenVisualizerOpen,
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(
          find.text(copy.lockScreenVisualizerInstructions),
          findsOneWidget,
        );
        expect(
          find.text(copy.lockScreenVisualizerSimulatedTitle),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
