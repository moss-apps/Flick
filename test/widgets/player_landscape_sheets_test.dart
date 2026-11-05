import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/player/widgets/player_layout_sheet.dart';
import 'package:flick/features/player/widgets/song_metadata_sheet.dart';
import 'package:flick/features/player/widgets/speed_bottom_sheet.dart';
import 'package:flick/features/player/widgets/pitch_bottom_sheet.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/player_service.dart';

class _Player extends Fake implements PlayerService {
  @override
  final currentSongNotifier = ValueNotifier<Song?>(null);
  @override
  final playbackSpeedNotifier = ValueNotifier(1.0);
  @override
  final pitchSemitonesNotifier = ValueNotifier(0.0);
  @override
  final sleepTimerRemainingNotifier = ValueNotifier<Duration?>(null);

  @override
  Future<void> setPlaybackSpeed(double value) async =>
      playbackSpeedNotifier.value = value;
  @override
  Future<void> setPitchSemitones(double value) async =>
      pitchSemitonesNotifier.value = value;
  @override
  void setSleepTimer(Duration duration) =>
      sleepTimerRemainingNotifier.value = duration;
  @override
  void cancelSleepTimer() => sleepTimerRemainingNotifier.value = null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  Widget host(Widget child, Locale locale, double scale) => ProviderScope(
    overrides: [currentSongProvider.overrideWithValue(null)],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      builder: (context, child) {
        LocaleController.instance.bind(AppLocalizations.of(context));
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: Scaffold(body: child),
    ),
  );

  for (final locale in kSupportedLocales) {
    for (final size in const [Size(640, 320), Size(1280, 800)]) {
      testWidgets('layout editor uses landscape columns at $size $locale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            PlayerLayoutSheet(
              playerService: _Player(),
              initialMode: PlayerScreenMode.immersive,
              onModeChanged: (_) async {},
              song: null,
            ),
            locale,
            2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final text = lookupFlickLocalizations(
          locale == kFilipinoLocale ? kFallbackLocale : locale,
        );
        final artwork = tester.getRect(find.text(text.artworkCard).first);
        final fullscreen = tester.getRect(find.text(text.fullscreen).first);
        expect(artwork.left, greaterThan(fullscreen.right));
      });
    }
  }

  testWidgets('short landscape utility sheets remain scrollable at 2x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Player();
    for (final child in [
      SpeedBottomSheet(playerService: service),
      PitchBottomSheet(playerService: service),
      SleepTimerBottomSheet(playerService: service),
      const SongMetadataSheet(
        song: Song(
          id: 'test',
          title: 'A long song title',
          artist: 'A long artist name',
          album: 'A long album name',
          duration: Duration(minutes: 4),
          fileType: 'FLAC',
        ),
      ),
    ]) {
      await tester.pumpWidget(host(child, kFallbackLocale, 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${child.runtimeType}');
      // Do not drag across a slider: its end callback deliberately closes the
      // modal in production, while this fixture hosts each surface directly.
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
