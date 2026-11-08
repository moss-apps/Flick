// The streak popup's Taglish copy is screen-specific: the count label and both
// buttons stay English, while the message rotates through five supplied lines
// and one line that includes the current streak. These checks do not certify
// the Tagalog wording.
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

// The calendar can contain the same number; only the header is the streak count.
Finder _streakCount(int streak, String dayStreakLabel) => find.descendant(
  of: find.widgetWithText(Row, dayStreakLabel),
  matching: find.text('$streak'),
);

bool _isTaglishGreeting(String text) =>
    taglishStreakGreetings.contains(text) ||
    RegExp(r'^\d+ days na ha\? Keep it up!$').hasMatch(text);

String _visibleGreeting(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .where(_isTaglishGreeting)
      .toList();
  expect(texts, hasLength(1));
  return texts.single;
}

void main() {
  test(
    'the five supplied Taglish streak greetings and day-count line are verbatim, random and documented',
    () {
      expect(taglishStreakGreetings, <String>[
        'Uy oh, may nagbabalik!',
        'Welcome back po. Tara music jam na ulit.',
        'Handa mo na earphones mo ulit. Hahaha.',
        'Hobby mo talaga music, maem?',
        'Share your music with?',
      ]);
      expect(
        taglishStreakDaysGreetingTemplate,
        '{days} days na ha? Keep it up!',
      );
      expect(taglishStreakDaysGreeting(12), '12 days na ha? Keep it up!');

      final seen = <String>{};
      final random = Random(7);
      for (var i = 0; i < 120; i++) {
        seen.add(randomTaglishStreakGreeting(8, random));
      }
      expect(seen, {...taglishStreakGreetings, taglishStreakDaysGreeting(8)});

      final review = File('docs/BAYBAYIN_REVIEW.md').readAsStringSync();
      for (final greeting in taglishStreakGreetings) {
        expect(review, contains('| $greeting | draft |'));
      }
      expect(
        review,
        contains('| $taglishStreakDaysGreetingTemplate | draft |'),
      );
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

        expect(_streakCount(streak, english.dayStreak), findsOneWidget);
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

        expect(
          _visibleGreeting(tester),
          isIn([...taglishStreakGreetings, taglishStreakDaysGreeting(streak)]),
        );
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

    expect(_streakCount(1, english.dayStreak), findsOneWidget);
    expect(find.text(english.dayStreak), findsOneWidget);
    expect(find.text(english.continueLabel), findsOneWidget);
    expect(find.text(english.donTShowAgainToday), findsOneWidget);
    expect(find.text(english.welcomeBackLetSStartA), findsOneWidget);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .where(_isTaglishGreeting),
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

    expect(_streakCount(1, chinese.dayStreak), findsOneWidget);
    expect(find.text(chinese.dayStreak), findsOneWidget);
    expect(find.text(chinese.continueLabel), findsOneWidget);
    expect(find.text(chinese.donTShowAgainToday), findsOneWidget);
    expect(find.text(chinese.welcomeBackLetSStartA), findsOneWidget);
    expect(find.text('day streak'), findsNothing);

    await _disposeStreak(tester);
  });

  testWidgets('streak count is distinct from a matching calendar day', (
    tester,
  ) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    // Force the collision on every run, not just when a fixed count happens to
    // appear in the rolling calendar window.
    final streak = DateTime.now().day;

    for (final locale in [
      kFilipinoLocale,
      kFallbackLocale,
      const Locale('zh', 'CN'),
    ]) {
      final strings = lookupFlickLocalizations(locale).englishForFilipino;
      await _pumpStreak(tester, locale: locale, streak: streak);

      expect(find.text('$streak'), findsNWidgets(2));
      expect(_streakCount(streak, strings.dayStreak), findsOneWidget);

      await _disposeStreak(tester);
    }
  });
}
