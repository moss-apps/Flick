// Language roles, not linguistic approval: the manual remains draft Taglish.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/onboarding/widgets/tutorial_overlay.dart';
import 'package:flick/features/settings/screens/app_info_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';
import 'package:flick/providers/update_check_provider.dart';

class _ActiveTutorial extends TutorialNotifier {
  @override
  TutorialState build() => const TutorialState(active: true);
}

class _OfflineUpdates extends UpdateCheckNotifier {
  @override
  UpdateCheckState build() => const UpdateCheckState();
}

Widget _host(Widget child, {Locale locale = kFilipinoLocale}) => ProviderScope(
  overrides: [
    currentSongProvider.overrideWithValue(null),
    tutorialProvider.overrideWith(_ActiveTutorial.new),
    updateCheckProvider.overrideWith(_OfflineUpdates.new),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    builder: (context, child) {
      LocaleController.instance.bind(AppLocalizations.of(context));
      return child!;
    },
    home: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConstants.setAnimationsEnabled(false);
  });

  tearDown(() {
    AppConstants.setAnimationsEnabled(true);
    LocaleController.instance.bindLocale(kFallbackLocale);
  });

  testWidgets(
    'all Taglish interactive tutorial steps and controls are English',
    (tester) async {
      final english = lookupFlickLocalizations(kFallbackLocale);
      final taglish = lookupFlickLocalizations(kFilipinoLocale);
      await tester.pumpWidget(_host(const Scaffold(body: TutorialOverlay())));
      await tester.pump();

      for (var i = 0; i < TutorialStep.values.length; i++) {
        final step = TutorialStep.values[i];
        expect(find.text(step.title(english)), findsOneWidget);
        expect(find.text(step.description(english)), findsOneWidget);
        expect(find.text(step.description(taglish)), findsNothing);
        expect(find.text(english.skip), findsOneWidget);
        expect(find.text(taglish.skip), findsNothing);
        if (i > 0) expect(find.text(english.back), findsOneWidget);

        if (i == TutorialStep.values.length - 1) {
          expect(find.text(english.openManual), findsOneWidget);
        } else {
          await tester.tap(find.text(english.next));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Taglish licenses are English; Chinese stays localized', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    // Keep both visits in one test: LicenseRegistry is reset between tests,
    // while AppInfoSettingsScreen registers Flick's license once per process.
    for (final locale in [kFilipinoLocale, const Locale('zh', 'CN')]) {
      await tester.pumpWidget(
        _host(const AppInfoSettingsScreen(), locale: locale),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final copy = lookupFlickLocalizations(locale).englishForFilipino;
      final expectedLocale = locale == kFilipinoLocale
          ? kFallbackLocale
          : locale;
      await tester.ensureVisible(find.text(copy.licenses));
      await tester.tap(find.text(copy.licenses));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final pageContext = tester.element(find.byType(LicensePage));
      expect(Localizations.localeOf(pageContext), expectedLocale);
      expect(
        find.text(MaterialLocalizations.of(pageContext).licensesPageTitle),
        findsOneWidget,
      );

      final flickEntry = find.widgetWithText(ListTile, 'Flick');
      await tester.scrollUntilVisible(flickEntry, 300);
      await tester.tap(flickEntry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final detailContext = tester.element(find.byType(BackButton).last);
      expect(Localizations.localeOf(detailContext), expectedLocale);
      final licenseHeading = copy.mitLicenseCopyrightC2026Flick
          .trim()
          .split('\n')
          .first;
      expect(find.textContaining(licenseHeading), findsWidgets);
      // The screen-scoped override must not change the app-wide locale.
      expect(l10n.localeName, lookupFlickLocalizations(locale).localeName);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
