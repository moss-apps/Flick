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
  'Baka mamaya puro ka relapse ha?',
];

String randomTaglishStreakGreeting([Random? random]) {
  final source = random ?? Random();
  return taglishStreakGreetings[source.nextInt(taglishStreakGreetings.length)];
}
