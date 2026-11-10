import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/orbit_settings_screen.dart';
import 'package:flick/features/songs/widgets/orbit_scroll.dart';
import 'package:flick/features/songs/widgets/song_card.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/orbit_card_background_style.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';

class _PreviewSongs extends SongsNotifier {
  _PreviewSongs(this.songs);

  final List<Song> songs;

  @override
  Future<SongsState> build() async => SongsState(songs: songs);
}

class _PreviewPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences();

  void setRadius(double value) {
    state = state.copyWith(orbitRadiusRatio: value);
  }
}

Widget _host({double textScale = 1, List<Song> songs = const []}) =>
    ProviderScope(
      overrides: [
        currentSongProvider.overrideWithValue(null),
        songsProvider.overrideWith(() => _PreviewSongs(songs)),
        appPreferencesProvider.overrideWith(_PreviewPreferences.new),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: kFallbackLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OrbitSettingsScreen(),
      ),
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(411, 900),
  double textScale = 1,
  List<Song> songs = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(textScale: textScale, songs: songs));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile selector switches without rotating the window', (
    tester,
  ) async {
    await _pumpScreen(tester);

    final copy = lookupFlickLocalizations(kFallbackLocale);
    expect(find.text(copy.orbitHeaderBoundaryTitle), findsOneWidget);
    expect(find.text(copy.orbitHeaderBoundaryBody), findsOneWidget);
    expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
    expect(find.byType(SongCard), findsWidgets);
    expect(
      tester.widget<OrbitScroll>(find.byType(OrbitScroll)).scrollDirection,
      Axis.vertical,
    );

    expect(find.text(copy.portrait), findsOneWidget);
    expect(find.text(copy.landscape), findsOneWidget);
    expect(find.text(copy.horizontalReach), findsOneWidget);
    expect(find.text(copy.cardSize), findsOneWidget);

    await tester.tap(find.text(copy.landscape));
    await tester.pumpAndSettle();

    expect(find.text(copy.horizontalReach), findsNothing);
    expect(find.text(copy.cardSize), findsNothing);
    expect(find.text(copy.cardWidth), findsOneWidget);
    expect(
      tester.widget<OrbitScroll>(find.byType(OrbitScroll)).scrollDirection,
      Axis.horizontal,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait card background selector follows preference', (
    tester,
  ) async {
    await _pumpScreen(tester);
    final copy = lookupFlickLocalizations(kFallbackLocale);

    expect(
      tester
          .widget<OrbitScroll>(find.byType(OrbitScroll))
          .cardBackgroundStyle,
      OrbitCardBackgroundStyle.blackGradient,
    );
    expect(find.text(copy.cardBackground.toUpperCase()), findsOneWidget);
    expect(find.text(copy.blackGradient), findsOneWidget);
    expect(find.text(copy.albumArtColorGradient), findsOneWidget);

    await tester.ensureVisible(find.text(copy.albumArtColorGradient));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.albumArtColorGradient));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OrbitScroll>(find.byType(OrbitScroll))
          .cardBackgroundStyle,
      OrbitCardBackgroundStyle.albumColorGradient,
    );

    await tester.ensureVisible(find.text(copy.landscape));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.landscape));
    await tester.pumpAndSettle();

    expect(find.text(copy.albumArtColorGradient), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview updates with preferences and can collapse', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
    expect(
      tester.widget<OrbitScroll>(find.byType(OrbitScroll)).radiusRatio,
      1.0,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrbitSettingsScreen)),
    );
    (container.read(appPreferencesProvider.notifier) as _PreviewPreferences)
        .setRadius(1.6);
    await tester.pump();

    expect(
      tester.widget<OrbitScroll>(find.byType(OrbitScroll)).radiusRatio,
      1.6,
    );

    await tester.tap(find.byKey(const Key('orbit_preview_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_preview')), findsNothing);
    expect(find.byType(OrbitScroll), findsNothing);

    await tester.tap(find.byKey(const Key('orbit_preview_toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
    expect(find.byType(OrbitScroll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview browsing never leaves settings or starts playback', (
    tester,
  ) async {
    await _pumpScreen(tester);

    final cards = tester
        .widgetList<SongCard>(find.byType(SongCard))
        .toList(growable: false);
    expect(cards, isNotEmpty);
    expect(cards.every((card) => !card.swipeActionsEnabled), isTrue);

    final selected = cards.firstWhere((card) => card.isSelected);
    await tester.tap(find.text(selected.song.title));
    await tester.pumpAndSettle();

    expect(find.byType(OrbitSettingsScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrbitSettingsScreen)),
    );
    expect(container.read(currentSongProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full-screen preview uses the real screen and can be closed', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(const Key('orbit_preview_fullscreen_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_preview_fullscreen')), findsOneWidget);
    final size = tester.getSize(
      find.byKey(const Key('orbit_preview_fullscreen')),
    );
    expect(size.width, 411);
    expect(size.height, greaterThan(300));
    expect(
      tester
          .widget<OrbitScroll>(
            find.descendant(
              of: find.byKey(const Key('orbit_preview_fullscreen')),
              matching: find.byType(OrbitScroll),
            ),
          )
          .scrollDirection,
      Axis.vertical,
    );

    await tester.tap(find.byKey(const Key('orbit_preview_close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_preview_fullscreen')), findsNothing);
    expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full-screen preview follows the landscape profile', (
    tester,
  ) async {
    await _pumpScreen(tester);
    final copy = lookupFlickLocalizations(kFallbackLocale);

    await tester.tap(find.text(copy.landscape));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orbit_preview_fullscreen_button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OrbitScroll>(
            find.descendant(
              of: find.byKey(const Key('orbit_preview_fullscreen')),
              matching: find.byType(OrbitScroll),
            ),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    expect(find.text(copy.landscape), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview uses a real library when enough songs are available', (
    tester,
  ) async {
    final songs = List.generate(
      5,
      (index) => Song(
        id: 'library-$index',
        title: 'Library track $index',
        artist: 'Library artist',
        duration: const Duration(minutes: 3),
        fileType: 'FLAC',
      ),
    );

    await _pumpScreen(tester, songs: songs);

    final cards = tester.widgetList<SongCard>(find.byType(SongCard));
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.song.id.startsWith('library-')), isTrue);
    expect(find.textContaining('Library track'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(900, 411), Size(1280, 800)]) {
    testWidgets(
      'preview fits a ${size.width.toInt()}x${size.height.toInt()} window',
      (tester) async {
        await _pumpScreen(tester, size: size);

        if (size.height < 620) {
          expect(find.byKey(const Key('orbit_preview')), findsNothing);
        } else {
          expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
          expect(
            tester
                .widget<OrbitScroll>(find.byType(OrbitScroll))
                .scrollDirection,
            Axis.horizontal,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('preview remains usable with enlarged text', (tester) async {
    await _pumpScreen(tester, textScale: 1.5);

    expect(find.byKey(const Key('orbit_preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
