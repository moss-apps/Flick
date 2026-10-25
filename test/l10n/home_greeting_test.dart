import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/l10n/home_greeting.dart';
import 'package:flick/l10n/l10n.dart';

void main() {
  test(
    'Filipino hooks follow the four local time periods at their boundaries',
    () {
      final cases = <(int, int, FilipinoGreetingPeriod)>[
        (0, 0, FilipinoGreetingPeriod.lateNight),
        (4, 59, FilipinoGreetingPeriod.lateNight),
        (5, 0, FilipinoGreetingPeriod.morning),
        (11, 59, FilipinoGreetingPeriod.morning),
        (12, 0, FilipinoGreetingPeriod.afternoon),
        (17, 59, FilipinoGreetingPeriod.afternoon),
        (18, 0, FilipinoGreetingPeriod.evening),
        (21, 59, FilipinoGreetingPeriod.evening),
        (22, 0, FilipinoGreetingPeriod.lateNight),
        (23, 59, FilipinoGreetingPeriod.lateNight),
      ];
      final strings = lookupFlickLocalizations(kFilipinoLocale);
      for (final (hour, minute, period) in cases) {
        final now = DateTime(2026, 10, 24, hour, minute);
        expect(filipinoGreetingPeriod(now), period);
        expect(
          filipinoHomeGreetingHooks[period],
          contains(
            homeGreetingFor(now: now, locale: kFilipinoLocale, l10n: strings),
          ),
        );
      }
    },
  );

  test('hooks rotate daily but remain stable across rebuilds and aliases', () {
    final strings = lookupFlickLocalizations(kFilipinoLocale);
    for (final hour in [8, 14, 19, 23]) {
      final seen = <String>{};
      final hooks =
          filipinoHomeGreetingHooks[filipinoGreetingPeriod(
            DateTime(2026, 10, 24, hour),
          )]!;
      for (var day = 24; day < 24 + hooks.length; day++) {
        final now = DateTime(2026, 10, day, hour);
        final hook = homeGreetingFor(
          now: now,
          locale: kFilipinoLocale,
          l10n: strings,
        );
        seen.add(hook);
        for (final locale in [kFilipinoLocale, const Locale('fil', 'PH')]) {
          expect(
            homeGreetingFor(
              now: DateTime(2026, 10, day, hour, 59),
              locale: locale,
              l10n: strings,
            ),
            hook,
          );
        }
      }
      expect(seen, hooks.toSet());
    }
  });

  test('English and Chinese keep their existing words and time boundaries', () {
    for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
      final strings = lookupFlickLocalizations(locale);
      for (final hour in [0, 4, 5, 11, 12, 17, 18, 21, 22, 23]) {
        expect(
          homeGreetingFor(
            now: DateTime(2026, 10, 24, hour),
            locale: locale,
            l10n: strings,
          ),
          hour < 12
              ? strings.goodMorning
              : hour < 18
              ? strings.goodAfternoon
              : strings.goodEvening,
        );
      }
    }
  });

  test(
    'all fifteen native-speaker hooks are verbatim and listed for review',
    () {
      final review = File('docs/BAYBAYIN_REVIEW.md').readAsStringSync();
      final hooks = filipinoHomeGreetingHooks.values
          .expand((hooks) => hooks)
          .toList();
      expect(
        filipinoHomeGreetingHooks.keys.toSet(),
        FilipinoGreetingPeriod.values.toSet(),
      );
      expect(filipinoHomeGreetingHooks, {
        FilipinoGreetingPeriod.morning: [
          'Uy, good morning!',
          'Kape muna.',
          'Almusal plus music? G!',
          'Good morning, sunshine.',
        ],
        FilipinoGreetingPeriod.afternoon: [
          'Break time music?',
          'Coffee break? After work or studies?',
          'Sunset na naman.',
          'Pahinga-pahinga rin.',
        ],
        FilipinoGreetingPeriod.evening: [
          'Dinner with music?',
          'Commuting pauwi with music?',
          'Ingat lagi! Listen well!',
        ],
        FilipinoGreetingPeriod.lateNight: [
          'Oh, walang magrerelapse ha?',
          'Hatinggabi na boss, itulog mo yan.',
          'Luh, puyat yarn?',
          'Listen for a bit tapos sleep na ha?',
        ],
      });
      expect(hooks.toSet().length, 15);
      for (final hook in hooks) {
        expect(hook.length, lessThanOrEqualTo(50));
        expect(RegExp(r'[\u1700-\u1736]').hasMatch(hook), isFalse);
        expect(review, contains('| $hook | draft |'));
      }
    },
  );
}
