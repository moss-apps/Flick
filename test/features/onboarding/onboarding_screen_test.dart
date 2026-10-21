import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';
import 'package:flick/l10n/l10n.dart';

/// The screen's copy is localized now, so the test reads the same `l10n` the
/// screen does instead of matching English literals. It used to assert
/// `find.text('Welcome to\nFlick Player')`, which both froze the copy in
/// English and made the screen untestable in any other locale.
Future<void> _pumpOnboarding(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        locale: locale,
        home: const OnboardingScreen(),
      ),
    ),
  );
  // The backdrop runs a repeating 6-second controller, so `pumpAndSettle` would
  // never return; a fixed pump is what the animations need.
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  for (final locale in const [Locale('en'), Locale('zh', 'CN')]) {
    final l10n = lookupAppLocalizations(locale);

    testWidgets('Next advances to the following page ($locale)', (tester) async {
      AppConstants.setAnimationsEnabled(true);
      await _pumpOnboarding(tester, locale);

      expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);

      await _tapNext(tester, l10n.next);

      expect(find.text(l10n.onboardingLibraryTitle), findsOneWidget);
    });

    testWidgets('Next advances when animations are disabled ($locale)', (
      tester,
    ) async {
      AppConstants.setAnimationsEnabled(false);
      await _pumpOnboarding(tester, locale);

      expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);

      await tester.tap(find.text(l10n.next));
      await tester.pump();

      expect(find.text(l10n.onboardingLibraryTitle), findsOneWidget);
    });

    testWidgets('every page and both buttons are in the active locale '
        '($locale)', (tester) async {
      AppConstants.setAnimationsEnabled(false);
      await _pumpOnboarding(tester, locale);

      final titles = <String>[
        l10n.onboardingWelcomeTitle,
        l10n.onboardingLibraryTitle,
        l10n.onboardingBrowseTitle,
        l10n.onboardingPlaybackTitle,
        l10n.onboardingReadyTitle,
      ];
      final bodies = <String>[
        l10n.onboardingWelcomeBody,
        l10n.onboardingLibraryBody,
        l10n.onboardingBrowseBody,
        l10n.onboardingPlaybackBody,
        l10n.onboardingReadyBody,
      ];

      for (var i = 0; i < titles.length; i++) {
        expect(find.text(titles[i]), findsOneWidget, reason: 'title of page $i');
        expect(find.text(bodies[i]), findsOneWidget, reason: 'body of page $i');

        // The last page swaps the CTA, so check both states of the button.
        final onLastPage = i == titles.length - 1;
        expect(
          find.text(onLastPage ? l10n.getStarted : l10n.next),
          findsOneWidget,
        );

        if (!onLastPage) await _tapNext(tester, l10n.next);
      }
    });
  }

  testWidgets('the onboarding copy is not left in English in zh', (
    tester,
  ) async {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh', 'CN'));

    // If a key were translated by copying the English value, the test above
    // would still pass in both locales -- these five pairs are the real guard.
    for (final pair in <List<String>>[
      [en.onboardingWelcomeTitle, zh.onboardingWelcomeTitle],
      [en.onboardingLibraryTitle, zh.onboardingLibraryTitle],
      [en.onboardingBrowseTitle, zh.onboardingBrowseTitle],
      [en.onboardingPlaybackTitle, zh.onboardingPlaybackTitle],
      [en.onboardingReadyTitle, zh.onboardingReadyTitle],
      [en.onboardingWelcomeBody, zh.onboardingWelcomeBody],
      [en.onboardingLibraryBody, zh.onboardingLibraryBody],
      [en.onboardingBrowseBody, zh.onboardingBrowseBody],
      [en.onboardingPlaybackBody, zh.onboardingPlaybackBody],
      [en.onboardingReadyBody, zh.onboardingReadyBody],
    ]) {
      expect(pair[1], isNot(pair[0]));
    }

    AppConstants.setAnimationsEnabled(false);
    await _pumpOnboarding(tester, const Locale('zh', 'CN'));
    expect(find.text(en.onboardingWelcomeTitle), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Next'), findsNothing);
  });
}
