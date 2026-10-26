// Milestones are an English surface in Taglish. The streak popup's greeting is
// intentionally excluded: it follows its own supplied Taglish copy.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/milestone/screens/milestones_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/milestone_service.dart';

MilestoneService _service() => MilestoneService(
  playCountOverride: () async => 12,
  listenSecondsOverride: () async => 5 * 3600,
  dayStreakOverride: () async => 3,
  uniqueArtistsOverride: () async => 8,
);

Widget _host(Widget child, {Locale locale = kFilipinoLocale}) => ProviderScope(
  overrides: [currentSongProvider.overrideWithValue(null)],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    localeResolutionCallback: resolveAppLocale,
    builder: (context, child) {
      LocaleController.instance.bind(AppLocalizations.of(context));
      return child!;
    },
    home: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'shown_milestones': jsonEncode([
        {
          'type': 'songs100',
          'achievedAt': DateTime(2026, 10, 26).toIso8601String(),
        },
      ]),
    });
  });

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('Taglish milestones screen uses English copy and units', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final english = lookupFlickLocalizations(kFallbackLocale);
    final taglish = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host(MilestonesScreen(service: _service())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(english.milestones), findsOneWidget);
    expect(
      find.text(english.unlocked(1, MilestoneType.values.length)),
      findsOneWidget,
    );
    expect(find.text(english.songs14), findsOneWidget);
    expect(find.text(english.listeningHours), findsOneWidget);
    expect(find.text(english.dayStreak3), findsOneWidget);
    expect(find.text(english.uniqueArtists), findsOneWidget);
    expect(find.text(english.currentStreak), findsOneWidget);
    expect(find.text(english.dayUnit(3)), findsWidgets);
    expect(find.text('12 / 500 songs'), findsOneWidget);
    expect(find.text('0 / 10 hours'), findsOneWidget);
    expect(find.text('3 / 7 days'), findsOneWidget);
    expect(find.text('8 / 25 artists'), findsOneWidget);
    expect(find.text(english.achieved('Oct 26, 2026')), findsOneWidget);

    for (final copy in [
      taglish.milestones,
      taglish.songs14,
      taglish.listeningHours,
      taglish.dayStreak3,
      taglish.uniqueArtists,
      taglish.currentStreak,
      taglish.moreTo(4, '7-Day Streak'),
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(find.text('Okt 26, 2026'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish celebration card and locked sheet are English', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final english = lookupFlickLocalizations(kFallbackLocale);
    await tester.pumpWidget(_host(MilestonesScreen(service: _service())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('100 Songs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(english.achievementUnlocked), findsOneWidget);
    expect(find.text(MilestoneType.songs100.message), findsOneWidget);
    expect(find.text(english.achieved('Oct 26, 2026')), findsOneWidget);
    expect(
      find.text(
        '${english.achieved('Oct 26, 2026')} · '
        '${english.nextToGo('500 songs', 488, 'songs')}',
      ),
      findsOneWidget,
    );
    expect(find.text(english.close), findsOneWidget);
    expect(find.text(english.done), findsOneWidget);
    expect(find.text('Tapos'), findsNothing);

    await tester.tap(find.text(english.close));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('500 Songs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(english.moreToUnlock(488, 'songs')), findsOneWidget);
    expect(find.text(english.locked), findsWidgets);
    expect(find.text('Naka-lock'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('milestone units are English while Taglish is active', () {
    LocaleController.instance.bindLocale(kFilipinoLocale);
    expect(MilestoneCategory.songs.unitLabel(1), 'song');
    expect(MilestoneCategory.songs.unitLabel(2), 'songs');
    expect(MilestoneCategory.hours.unitLabel(1), 'hour');
    expect(MilestoneCategory.dayStreak.unitLabel(3), 'days');
    expect(MilestoneCategory.uniqueArtists.unitLabel(8), 'artists');
  });
}
