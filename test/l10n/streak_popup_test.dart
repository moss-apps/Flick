// The streak popup's Taglish copy is screen-specific: the count label and both
// buttons stay English, while the message rotates through six supplied lines.
// These checks do not certify the Tagalog wording.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/milestone/widgets/streak_popup.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/l10n/streak_greeting.dart';

Future<void> _pumpStreak(
  WidgetTester tester, {
  required Locale locale,
  required int streak,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      localeResolutionCallback: resolveAppLocale,
      builder: (context, child) {
        LocaleController.instance.bind(AppLocalizations.of(context));
        return child!;
      },
      home: Scaffold(
        body: Center(child: StreakPopup(streak: streak)),
      ),
    ),
  );
  // Fire the delayed pulse start so no timer is left pending at teardown.
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _disposeStreak(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

String _visibleGreeting(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .where(taglishStreakGreetings.contains)
      .toList();
  expect(texts, hasLength(1));
  return texts.single;
}

void main() {
  test(
    'the six supplied Taglish streak greetings are verbatim, random and documented',
    () {
      expect(taglishStreakGreetings, <String>[
        'Uy oh, may nagbabalik!',
        'Welcome back po. Tara music jam na ulit.',
        'Handa mo na earphones mo ulit. Hahaha.',
        'Hobby mo talaga music, maem?',
        'Share your music with?',
        'Baka mamaya puro ka relapse ha?',
      ]);

      final seen = <String>{};
      final random = Random(7);
      for (var i = 0; i < 120; i++) {
        seen.add(randomTaglishStreakGreeting(random));
      }
      expect(seen, taglishStreakGreetings.toSet());

      final review = File('docs/BAYBAYIN_REVIEW.md').readAsStringSync();
      for (final greeting in taglishStreakGreetings) {
        expect(review, contains('| $greeting | draft |'));
      }
    },
  );

  testWidgets(
    'Taglish keeps the count label and buttons English and rotates the message',
    (tester) async {
      addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
      final taglish = lookupFlickLocalizations(kFilipinoLocale);
      final english = lookupFlickLocalizations(kFallbackLocale);

      for (final streak in [1, 8, 99]) {
        await _pumpStreak(tester, locale: kFilipinoLocale, streak: streak);

        expect(find.text('$streak'), findsOneWidget);
        expect(find.text(english.dayStreak), findsOneWidget);
        expect(find.text(english.continueLabel), findsOneWidget);
        expect(find.text(english.donTShowAgainToday), findsOneWidget);

        expect(find.text(taglish.dayStreak), findsNothing);
        expect(find.text(taglish.continueLabel), findsNothing);
        expect(find.text(taglish.donTShowAgainToday), findsNothing);
        expect(find.text(taglish.welcomeBackLetSStartA), findsNothing);
        expect(find.text(taglish.keepItGoingOpenTomorrowTo), findsNothing);
        expect(find.text(taglish.aWeekAndCountingYourDedication), findsNothing);
        expect(find.text(taglish.incredibleOverAMonthOfDaily), findsNothing);

        expect(_visibleGreeting(tester), isIn(taglishStreakGreetings));
        await _disposeStreak(tester);
      }
    },
  );

  testWidgets('English keeps its existing count label, message and buttons', (
    tester,
  ) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    final english = lookupFlickLocalizations(kFallbackLocale);

    await _pumpStreak(tester, locale: kFallbackLocale, streak: 1);

    expect(find.text('1'), findsOneWidget);
    expect(find.text(english.dayStreak), findsOneWidget);
    expect(find.text(english.continueLabel), findsOneWidget);
    expect(find.text(english.donTShowAgainToday), findsOneWidget);
    expect(find.text(english.welcomeBackLetSStartA), findsOneWidget);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .where(taglishStreakGreetings.contains),
      isEmpty,
    );

    await _disposeStreak(tester);
  });

  testWidgets('Chinese keeps its localized count label, message and buttons', (
    tester,
  ) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    final chinese = lookupFlickLocalizations(const Locale('zh', 'CN'));

    await _pumpStreak(tester, locale: const Locale('zh', 'CN'), streak: 1);

    expect(find.text('1'), findsOneWidget);
    expect(find.text(chinese.dayStreak), findsOneWidget);
    expect(find.text(chinese.continueLabel), findsOneWidget);
    expect(find.text(chinese.donTShowAgainToday), findsOneWidget);
    expect(find.text(chinese.welcomeBackLetSStartA), findsOneWidget);
    expect(find.text('day streak'), findsNothing);

    await _disposeStreak(tester);
  });
}
