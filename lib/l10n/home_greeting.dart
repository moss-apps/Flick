import 'package:flutter/widgets.dart';

import 'package:flick/l10n/generated/app_localizations.dart';

enum FilipinoGreetingPeriod { morning, afternoon, evening, lateNight }

/// Native-speaker supplied Taglish hooks, exclusive to the Filipino locale.
/// The supplied wording is verbatim and its review status remains draft.
/// Kept together so this small collection can be reviewed as a coherent voice.
const filipinoHomeGreetingHooks = <FilipinoGreetingPeriod, List<String>>{
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
};

FilipinoGreetingPeriod filipinoGreetingPeriod(DateTime now) {
  if (now.hour < 5 || now.hour >= 22) {
    return FilipinoGreetingPeriod.lateNight;
  }
  if (now.hour < 12) return FilipinoGreetingPeriod.morning;
  if (now.hour < 18) return FilipinoGreetingPeriod.afternoon;
  return FilipinoGreetingPeriod.evening;
}

/// Stable throughout a local calendar day and time period: rebuilds, refreshes
/// and restarts must not randomly replace the welcome line. No profile, network
/// request, listening-history inference or persisted counter is needed.
String homeGreetingFor({
  required DateTime now,
  required Locale locale,
  required AppLocalizations l10n,
}) {
  if (locale.languageCode == 'tl' || locale.languageCode == 'fil') {
    final hooks = filipinoHomeGreetingHooks[filipinoGreetingPeriod(now)]!;
    final day =
        DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return hooks[day % hooks.length];
  }
  // Preserve the incumbent time boundaries and wording in other languages.
  if (now.hour < 12) return l10n.goodMorning;
  if (now.hour < 18) return l10n.goodAfternoon;
  return l10n.goodEvening;
}
