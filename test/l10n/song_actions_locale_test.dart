// The song long-press sheet and everything it opens are an English surface in
// Taglish. English and Chinese keep their own copy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/songs/widgets/metadata_editor_bottom_sheet.dart';
import 'package:flick/features/songs/widgets/song_actions_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/favorites_provider.dart';
import 'package:flick/providers/player_provider.dart';

const _song = Song(
  id: 'song-1',
  title: 'Test Song',
  artist: 'Test Artist',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: '/tmp/test-song.flac',
);

class _EmptyFavorites extends FavoritesNotifier {
  @override
  Future<FavoritesState> build() async =>
      const FavoritesState(favoriteIds: {}, isLoading: false);
}

Widget _host(Widget child) => ProviderScope(
  overrides: [
    favoritesProvider.overrideWith(_EmptyFavorites.new),
    currentSongProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: kFilipinoLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    localeResolutionCallback: resolveAppLocale,
    builder: (context, child) {
      LocaleController.instance.bind(AppLocalizations.of(context));
      return child!;
    },
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void _setLargePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('Taglish song long-press sheet uses English actions', (
    tester,
  ) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => SongActionsBottomSheet(
            song: _song,
            rootContext: context,
            onSelect: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final english = [
      en.addToFavorites2,
      en.select,
      en.addToQueue,
      en.addToPlaylist2,
      en.setAlbumArt,
      en.editMetadata,
      en.viewMetadata,
      en.share,
      en.deleteSong,
    ];
    for (final copy in english) {
      expect(find.text(copy), findsOneWidget);
    }
    for (final copy in [
      tl.addToFavorites2,
      tl.select,
      tl.addToQueue,
      tl.addToPlaylist2,
      tl.setAlbumArt,
      tl.editMetadata,
      tl.viewMetadata,
      tl.share,
      tl.deleteSong,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish metadata editor is fully English', (tester) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _host(const MetadataEditorBottomSheet(song: _song)),
    );
    await tester.pumpAndSettle();

    final english = [
      en.editMetadata,
      en.title,
      en.artist,
      en.album,
      en.albumArtist,
      en.genre,
      en.year,
      en.track3,
      en.disc2,
      en.fileInformation,
      en.duration,
      en.format,
      en.filePath,
      en.saveChanges,
    ];
    for (final copy in english) {
      expect(find.text(copy), findsWidgets);
    }
    for (final copy in [
      tl.editMetadata,
      tl.title,
      tl.artist,
      tl.albumArtist,
      tl.genre,
      tl.year,
      tl.track3,
      tl.fileInformation,
      tl.saveChanges,
    ]) {
      expect(find.text(copy), findsNothing);
    }

    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text(en.discardChanges2), findsOneWidget);
    expect(find.text(en.youHaveUnsavedChangesAreYou), findsOneWidget);
    expect(find.text(en.cancel), findsOneWidget);
    expect(find.text(tl.discardChanges2), findsNothing);
    expect(find.text(tl.cancel), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
