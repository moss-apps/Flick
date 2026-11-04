// Player Layout is an English surface in Taglish, both in the full-player
// bottom sheet and in its settings screen. English and Chinese keep their own
// copy; the test checks the nested action picker too.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/player/widgets/player_layout_sheet.dart';
import 'package:flick/features/settings/screens/player_layout_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/player_service.dart';

class _FakePlayerService extends Fake implements PlayerService {
  @override
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);
}

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
    home: Scaffold(body: child),
  ),
);

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

const _quickActionLabels = [
  'none',
  'lyrics',
  'favorites',
  'visualizer',
  'rating',
  'queue',
  'sleepTimer2',
  'share',
  'usbVolume',
  'equalizer',
  'volume',
  'cast',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets(
    'Taglish player layout sheet uses English labels and descriptions',
    (tester) async {
      _setTallView(tester);
      final en = lookupFlickLocalizations(kFallbackLocale);
      final tl = lookupFlickLocalizations(kFilipinoLocale);
      await tester.pumpWidget(
        _host(
          PlayerLayoutSheet(
            playerService: _FakePlayerService(),
            initialMode: PlayerScreenMode.immersive,
            onModeChanged: (_) async {},
            song: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final copy in [
        en.playerLayout,
        en.fullscreen,
        en.immersive,
        en.fullBleedAlbumArtWithThe,
        en.artworkCard,
        en.roundedAlbumArtCardWithA,
        en.quickActions,
        en.albumColors,
        en.leftTop,
        en.leftBottom,
        en.rightTop,
        en.rightBottom,
      ]) {
        expect(find.text(copy), findsWidgets);
      }
      for (final copy in [en.off, en.subtle, en.moderate, en.vibrant]) {
        expect(find.text(copy), findsOneWidget);
      }
      for (final key in _quickActionLabels) {
        expect(find.text(_localized(en, key)), findsWidgets);
      }

      for (final copy in [
        tl.playerLayout,
        tl.fullBleedAlbumArtWithThe,
        tl.artworkCard,
        tl.roundedAlbumArtCardWithA,
        tl.quickActions,
        tl.albumColors,
        tl.leftTop,
        tl.leftBottom,
        tl.rightTop,
        tl.rightBottom,
        tl.off,
        tl.subtle,
        tl.moderate,
        tl.vibrant,
      ]) {
        expect(find.text(copy), findsNothing);
      }
      for (final key in _quickActionLabels) {
        final taglish = _localized(tl, key);
        if (taglish != _localized(en, key)) {
          expect(find.text(taglish), findsNothing);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Taglish player layout settings and action picker are English', (
    tester,
  ) async {
    _setTallView(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host(const PlayerLayoutSettingsScreen()));
    await tester.pumpAndSettle();

    for (final copy in [
      en.playerLayout,
      en.layoutMode.toUpperCase(),
      en.immersive,
      en.fullBleedAlbumArtWithThe,
      en.artworkCard,
      en.roundedAlbumArtCardWithA,
      en.quickActions.toUpperCase(),
      en.leftTopButton,
      en.leftBottomButton,
      en.rightTopButton,
      en.rightBottomButton,
    ]) {
      expect(find.text(copy), findsWidgets);
    }
    for (final copy in [
      tl.playerLayout,
      tl.layoutMode.toUpperCase(),
      tl.fullBleedAlbumArtWithThe,
      tl.roundedAlbumArtCardWithA,
      tl.quickActions.toUpperCase(),
      tl.leftTopButton,
      tl.leftBottomButton,
      tl.rightTopButton,
      tl.rightBottomButton,
    ]) {
      expect(find.text(copy), findsNothing);
    }

    await tester.ensureVisible(find.text(en.leftTopButton));
    await tester.tap(find.text(en.leftTopButton));
    await tester.pumpAndSettle();

    expect(find.text(en.chooseAction.toUpperCase()), findsOneWidget);
    for (final key in _quickActionLabels) {
      expect(find.text(_localized(en, key)), findsWidgets);
    }
    for (final key in _quickActionLabels) {
      final taglish = _localized(tl, key);
      if (taglish != _localized(en, key)) {
        expect(find.text(taglish), findsNothing);
      }
    }
    expect(find.text(tl.chooseAction.toUpperCase()), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese player layout sheet keeps its own labels', (
    tester,
  ) async {
    _setTallView(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    await tester.pumpWidget(
      _host(
        PlayerLayoutSheet(
          playerService: _FakePlayerService(),
          initialMode: PlayerScreenMode.immersive,
          onModeChanged: (_) async {},
          song: null,
        ),
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      zh.playerLayout,
      zh.fullscreen,
      zh.immersive,
      zh.fullBleedAlbumArtWithThe,
      zh.artworkCard,
      zh.roundedAlbumArtCardWithA,
      zh.quickActions,
      zh.albumColors,
      zh.off,
      zh.subtle,
      zh.moderate,
      zh.vibrant,
      zh.leftTop,
      zh.leftBottom,
      zh.rightTop,
      zh.rightBottom,
    ]) {
      expect(find.text(copy), findsWidgets);
    }
    for (final key in _quickActionLabels) {
      expect(find.text(_localized(zh, key)), findsWidgets);
    }
    for (final copy in [
      en.playerLayout,
      en.layoutMode,
      en.fullBleedAlbumArtWithThe,
      en.roundedAlbumArtCardWithA,
      en.quickActions,
      en.albumColors,
      en.leftTop,
      en.leftBottom,
      en.rightTop,
      en.rightBottom,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese player layout settings and action picker stay Chinese', (
    tester,
  ) async {
    _setTallView(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    await tester.pumpWidget(
      _host(
        const PlayerLayoutSettingsScreen(),
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      zh.playerLayout,
      zh.layoutMode,
      zh.immersive,
      zh.fullBleedAlbumArtWithThe,
      zh.artworkCard,
      zh.roundedAlbumArtCardWithA,
      zh.quickActions,
      zh.leftTopButton,
      zh.leftBottomButton,
      zh.rightTopButton,
      zh.rightBottomButton,
    ]) {
      expect(find.text(copy), findsWidgets);
    }
    for (final copy in [
      en.playerLayout,
      en.fullBleedAlbumArtWithThe,
      en.roundedAlbumArtCardWithA,
      en.quickActions,
      en.leftTopButton,
      en.leftBottomButton,
      en.rightTopButton,
      en.rightBottomButton,
    ]) {
      expect(find.text(copy), findsNothing);
    }

    await tester.ensureVisible(find.text(zh.leftTopButton));
    await tester.tap(find.text(zh.leftTopButton));
    await tester.pumpAndSettle();

    expect(find.text(zh.chooseAction), findsOneWidget);
    for (final key in _quickActionLabels) {
      expect(find.text(_localized(zh, key)), findsWidgets);
    }
    expect(find.text(en.chooseAction), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

String _localized(AppLocalizations copy, String key) => switch (key) {
  'none' => copy.none,
  'lyrics' => copy.lyrics,
  'favorites' => copy.favorites,
  'visualizer' => copy.visualizer,
  'rating' => copy.rating,
  'queue' => copy.queue,
  'sleepTimer2' => copy.sleepTimer2,
  'share' => copy.share,
  'usbVolume' => copy.usbVolume,
  'equalizer' => copy.equalizer,
  'volume' => copy.volume,
  'cast' => copy.cast,
  _ => throw ArgumentError('unknown action $key'),
};
