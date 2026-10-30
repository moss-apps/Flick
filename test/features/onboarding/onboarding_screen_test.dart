import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/onboarding_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';

/// The screen's copy is localized now, so the test reads the same `l10n` the
/// screen does instead of matching English literals. It used to assert
/// `find.text('Welcome to\nFlick Player')`, which both froze the copy in
/// English and made the screen untestable in any other locale.
Future<void> _pumpOnboarding(
  WidgetTester tester,
  Locale locale, {
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: const OnboardingScreen(),
      ),
    ),
  );
  // The real entry flow resolves these preferences before showing this route.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(OnboardingScreen)),
  );
  container.read(onboardingCompletedProvider);
  container.read(tutorialProvider);
  // Keep the initial entrance in progress for the motion-specific tests.
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final display = FontLoader('GoogleSansFlex')
      ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Italic.ttf'))
      ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-BoldItalic.ttf'));
    final chinese = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Bold.ttf'));
    final tagalog = FontLoader('NotoSansTagalog')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTagalog-Regular.ttf'));
    await Future.wait([display.load(), chinese.load(), tagalog.load()]);
  });
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  for (final locale in const [Locale('en'), Locale('zh', 'CN')]) {
    final l10n = lookupAppLocalizations(locale);

    testWidgets('Next advances to the following page ($locale)', (
      tester,
    ) async {
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
        expect(
          find.text(titles[i]),
          findsOneWidget,
          reason: 'title of page $i',
        );
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

  testWidgets(
    'Taglish onboarding is English except the supplied welcome title',
    (tester) async {
      final en = lookupFlickLocalizations(kFallbackLocale);
      final tl = lookupFlickLocalizations(kFilipinoLocale);
      AppConstants.setAnimationsEnabled(false);
      await _pumpOnboarding(tester, kFilipinoLocale);

      const welcome = 'Kumusta! Greetings from Flick!';
      expect(tl.onboardingWelcomeTitle, welcome);
      final titles = [
        welcome,
        en.onboardingLibraryTitle,
        en.onboardingBrowseTitle,
        en.onboardingPlaybackTitle,
        en.onboardingReadyTitle,
      ];
      final bodies = [
        en.onboardingWelcomeBody,
        en.onboardingLibraryBody,
        en.onboardingBrowseBody,
        en.onboardingPlaybackBody,
        en.onboardingReadyBody,
      ];
      for (var i = 0; i < titles.length; i++) {
        expect(find.text(titles[i]), findsOneWidget);
        expect(find.text(bodies[i]), findsOneWidget);
        final isLastPage = i == titles.length - 1;
        expect(find.text(isLastPage ? en.getStarted : en.next), findsOneWidget);
        expect(find.text(tl.skip), findsNothing);
        if (!isLastPage) {
          expect(find.text(en.skip), findsOneWidget);
          await _tapNext(tester, en.next);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

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

  testWidgets('swiping updates progress and can return to the welcome', (
    tester,
  ) async {
    await _pumpOnboarding(tester, const Locale('en'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('02 / 05'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('01 / 05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system reduced motion presents static art and jumps immediately',
    (tester) async {
      AppConstants.setAnimationsEnabled(true);
      await _pumpOnboarding(
        tester,
        const Locale('en'),
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('02 / 05'), findsOneWidget);
      // Material's tap feedback can still be settling; the page already jumped.
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('Skip persists completion and preserves the tutorial handoff', (
    tester,
  ) async {
    await _pumpOnboarding(tester, const Locale('en'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingScreen)),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(container.read(tutorialProvider).autoStartPending, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('Get Started completes only after the final page', (
    tester,
  ) async {
    AppConstants.setAnimationsEnabled(false);
    await _pumpOnboarding(tester, const Locale('en'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingScreen)),
    );
    for (var page = 0; page < 4; page++) {
      expect(container.read(onboardingCompletedProvider), isFalse);
      await _tapNext(tester, 'Next');
    }
    expect(find.text('Skip'), findsNothing);
    expect(find.text('05 / 05'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(container.read(tutorialProvider).autoStartPending, isTrue);
  });

  testWidgets('completion pops onboarding when it was opened as a route', (
    tester,
  ) async {
    await _pumpOnboarding(tester, const Locale('en'));
    final navigator = Navigator.of(
      tester.element(find.byType(OnboardingScreen)),
    );
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
    );
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isTrue);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('short windows scroll the copy without moving the action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpOnboarding(
      tester,
      const Locale('en'),
      textScaler: TextScaler.linear(2),
    );
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Next');
    final before = tester.getRect(action);
    await tester.drag(
      find.byKey(const PageStorageKey('onboarding-poster-0')),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(action), before);
    final body = lookupFlickLocalizations(
      const Locale('en'),
    ).onboardingWelcomeBody;
    final viewport = tester.getRect(
      find.byKey(const PageStorageKey('onboarding-poster-0')),
    );
    final bodyRect = tester.getRect(find.text(body));
    expect(bodyRect.overlaps(viewport), isTrue);
    expect(bodyRect.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('tl')]) {
    testWidgets('enlarged headlines keep whole words with bundled fonts '
        '($locale)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppConstants.setAnimationsEnabled(false);
      await _pumpOnboarding(tester, locale, textScaler: TextScaler.linear(2));
      final localized = lookupFlickLocalizations(locale);
      final l10n = localized.englishForFilipino;
      final titles = [
        localized.onboardingWelcomeTitle,
        l10n.onboardingLibraryTitle,
        l10n.onboardingBrowseTitle,
        l10n.onboardingPlaybackTitle,
        l10n.onboardingReadyTitle,
      ];
      for (var page = 0; page < titles.length; page++) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(titles[page]),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.textScaler.scale(16), 32);
        for (final word in RegExp(r'\S+').allMatches(titles[page])) {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          );
          expect(boxes, isNotEmpty);
          expect(
            boxes.every((box) => (box.top - boxes.first.top).abs() < 1),
            isTrue,
            reason: '${word.group(0)} must stay on one line at 2x text',
          );
        }
        if (page < titles.length - 1) await _tapNext(tester, l10n.next);
      }
    });
  }

  for (final size in const [Size(320, 568), Size(800, 360), Size(800, 1280)]) {
    for (final locale in const [
      Locale('en'),
      Locale('zh', 'CN'),
      Locale('tl'),
    ]) {
      testWidgets('all posters fit $size with 2x text ($locale)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppConstants.setAnimationsEnabled(false);
        await _pumpOnboarding(tester, locale, textScaler: TextScaler.linear(2));
        final l10n = lookupFlickLocalizations(locale).englishForFilipino;
        for (var page = 0; page < 5; page++) {
          expect(tester.takeException(), isNull, reason: 'page $page');
          final action = find.widgetWithText(
            FilledButton,
            page == 4 ? l10n.getStarted : l10n.next,
          );
          expect(action.hitTestable(), findsOneWidget);
          final rect = tester.getRect(action);
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          if (page < 4) await _tapNext(tester, l10n.next);
        }
      });
    }
  }
}
