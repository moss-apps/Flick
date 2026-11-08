import 'dart:math';

/// Native-speaker supplied Taglish greetings for the launch-day streak popup.
/// One is chosen at random each time the popup opens. The supplied wording is
/// verbatim and its review status remains draft.
const taglishStreakGreetings = <String>[
  'Uy oh, may nagbabalik!',
  'Welcome back po. Tara music jam na ulit.',
  'Handa mo na earphones mo ulit. Hahaha.',
  'Hobby mo talaga music, maem?',
  'Share your music with?',
];

/// Template for the day-count greeting. The popup fills in the active streak.
const taglishStreakDaysGreetingTemplate = '{days} days na ha? Keep it up!';

String taglishStreakDaysGreeting(int streak) =>
    taglishStreakDaysGreetingTemplate.replaceFirst('{days}', '$streak');

String randomTaglishStreakGreeting(int streak, [Random? random]) {
  final source = random ?? Random();
  final index = source.nextInt(taglishStreakGreetings.length + 1);
  if (index == taglishStreakGreetings.length) {
    return taglishStreakDaysGreeting(streak);
  }
  return taglishStreakGreetings[index];
}
