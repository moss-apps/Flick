// Songs sorting and multiselection are English surfaces in Taglish, not a
// screen-wide locale override. Chinese keeps its own copy and metadata is data.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/songs/screens/songs_screen.dart';
import 'package:flick/features/songs/widgets/sort_filter_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/song_view_mode.dart';
import 'package:flick/providers/providers.dart';

// Latin track titles avoid the existing CJK fixed-height list-row overflow;
// the album and playlist names still exercise preservation of original metadata.
const _songs = [
  Song(
    id: 'song-1',
    title: 'Unang kanta',
    artist: 'Original Artist',
    album: 'Original Album',
    duration: Duration(minutes: 3),
    fileType: 'FLAC',
    filePath: '/music/original-song.flac',
  ),
  Song(
    id: 'song-2',
    title: 'Ikalawang kanta',
    artist: 'Original Artist',
    album: '第二张专辑',
    duration: Duration(minutes: 4),
    fileType: 'MP3',
  ),
];

class _FixtureSongs extends SongsNotifier {
  _FixtureSongs(this.sort);

  final SongSortOption sort;

  @override
  Future<SongsState> build() async =>
      SongsState(songs: _songs, sortOption: sort);
}

class _ListViewMode extends SongsViewModeNotifier {
  @override
  SongViewMode build() => SongViewMode.list;
}

class _FixturePlaylists extends PlaylistsNotifier {
  _FixturePlaylists(this.fail);

  final bool fail;

  @override
  Future<PlaylistsState> build() async {
    if (fail) throw StateError('playlist load failed');
    return PlaylistsState(
      playlists: [
        Playlist(
          id: 'playlist-1',
          name: 'Mga paborito ko',
          createdAt: DateTime(2026),
        ),
      ],
      isLoading: false,
    );
  }
}

Widget _host(
  Locale locale, {
  SongSortOption sort = SongSortOption.albumArtist,
  bool playlistError = false,
}) => ProviderScope(
  overrides: [
    songsProvider.overrideWith(() => _FixtureSongs(sort)),
    songsViewModeProvider.overrideWith(_ListViewMode.new),
    playlistsProvider.overrideWith(() => _FixturePlaylists(playlistError)),
    currentSongProvider.overrideWithValue(null),
    isCastingProvider.overrideWithValue(false),
  ],
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
    home: const Scaffold(body: SongsScreen()),
  ),
);

void _setPhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SongsScreen)));

Map<SongSortOption, String> _sortLabels(AppLocalizations copy) => {
  SongSortOption.albumArtist: copy.albumArtist,
  SongSortOption.title: copy.title,
  SongSortOption.artist: copy.artist,
  SongSortOption.dateAdded: copy.dateAdded,
  SongSortOption.fileType: copy.format,
  SongSortOption.album: copy.album,
  SongSortOption.year: copy.year,
  SongSortOption.genre: copy.genre,
};

Finder _sortText(String text) => find.descendant(
  of: find.byType(SortFilterBottomSheet),
  matching: find.text(text),
);

void _expectSortCopy(AppLocalizations copy) {
  expect(find.byType(SortFilterBottomSheet), findsOneWidget);
  for (final label in [
    copy.sortBy,
    copy.filterByFormat,
    copy.allFormats,
    ..._sortLabels(copy).values,
  ]) {
    expect(_sortText(label), findsOneWidget);
  }
  for (final format in SongFileTypeFilter.values.where(
    (filter) => filter != SongFileTypeFilter.all,
  )) {
    expect(_sortText(format.displayNameFor(copy)), findsOneWidget);
  }
}

Future<void> _openSort(WidgetTester tester, AppLocalizations copy) async {
  final sort = _container(tester).read(songsProvider).requireValue.sortOption;
  if (sort == SongSortOption.album) {
    await tester.tap(find.byTooltip(copy.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.sortFilter));
  } else {
    await tester.tap(find.byIcon(Icons.sort_rounded));
  }
  await tester.pumpAndSettle();
}

Future<void> _openMore(WidgetTester tester, AppLocalizations copy) async {
  await tester.tap(find.byTooltip(copy.moreActions));
  await tester.pumpAndSettle();
}

void _expectCreateDialog(AppLocalizations copy) {
  for (final label in [
    copy.createPlaylist,
    copy.playlistName,
    copy.create,
    copy.cancel,
  ]) {
    expect(find.text(label), findsOneWidget);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Use the shipped fonts so popup/selection labels use real phone metrics.
    for (final family in ['GoogleSansFlex', 'NotoSansSC']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  for (final locale in [
    kFilipinoLocale,
    kFallbackLocale,
    const Locale('zh', 'CN'),
  ]) {
    final active = lookupFlickLocalizations(locale);
    final copy = active.englishForFilipino;

    testWidgets(
      'sort/filter copy and callbacks work from every sort ($locale)',
      (tester) async {
        _setPhoneSize(tester);
        await tester.pumpWidget(_host(locale));
        await tester.pumpAndSettle();
        final container = _container(tester);

        for (final option in SongSortOption.values) {
          await _openSort(tester, copy);
          _expectSortCopy(copy);
          if (locale == kFilipinoLocale) {
            expect(find.text(active.sortBy), findsNothing);
            expect(find.text(active.filterByFormat), findsNothing);
            expect(find.text(active.allFormats), findsNothing);
          }
          final label = _sortText(_sortLabels(copy)[option]!);
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(container.read(songsProvider).requireValue.sortOption, option);
          expect(find.byType(SortFilterBottomSheet), findsNothing);
        }

        await _openSort(tester, copy);
        await tester.ensureVisible(_sortText('MP3'));
        await tester.tap(_sortText('MP3'));
        await tester.pumpAndSettle();
        expect(
          container.read(songsProvider).requireValue.fileTypeFilter,
          SongFileTypeFilter.mp3,
        );
        expect(container.read(songsProvider).requireValue.sortedSongs, [
          _songs[1],
        ]);

        await _openSort(tester, copy);
        await tester.ensureVisible(_sortText(copy.allFormats));
        await tester.tap(_sortText(copy.allFormats));
        await tester.pumpAndSettle();
        expect(
          container.read(songsProvider).requireValue.fileTypeFilter,
          SongFileTypeFilter.all,
        );
        expect(find.text(active.songs2(_songs.length)), findsOneWidget);
        expect(find.text(active.searchSongsArtists), findsOneWidget);
        for (final song in _songs) {
          expect(find.text(song.title), findsOneWidget);
        }
        expect(l10n.localeName, active.localeName);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'album overflow menu and option sheet keep their copy role ($locale)',
      (tester) async {
        _setPhoneSize(tester);
        await tester.pumpWidget(_host(locale, sort: SongSortOption.album));
        await tester.pumpAndSettle();
        final container = _container(tester);

        await _openMore(tester, copy);
        for (final label in [
          copy.viewAsList,
          copy.albumOptions,
          copy.sortFilter,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        if (locale == kFilipinoLocale) {
          for (final label in [
            active.viewAsList,
            active.albumOptions,
            active.sortFilter,
          ]) {
            expect(find.text(label), findsNothing);
          }
        }
        await tester.tap(find.text(copy.viewAsList));
        await tester.pumpAndSettle();
        await _openMore(tester, copy);
        expect(find.text(copy.viewAsGrid), findsOneWidget);
        await tester.tap(find.text(copy.viewAsGrid));
        await tester.pumpAndSettle();
        await _openMore(tester, copy);
        await tester.tap(find.text(copy.albumOptions));
        await tester.pumpAndSettle();

        for (final label in [
          copy.sortBy,
          copy.albumName,
          copy.albumArtist,
          copy.trackCount,
          copy.filterByFormat,
          copy.allFormats,
          copy.albumLimit,
          copy.albumsShownPerPage,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        if (locale == kFilipinoLocale) {
          for (final label in [
            active.sortBy,
            active.filterByFormat,
            active.allFormats,
            active.albumLimit,
            active.albumsShownPerPage,
          ]) {
            expect(find.text(label), findsNothing);
          }
        }

        await tester.tap(find.text(copy.trackCount));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text(copy.trackCount)).style?.fontWeight,
          FontWeight.w600,
        );
        await tester.ensureVisible(find.text('MP3'));
        await tester.tap(find.text('MP3'));
        await tester.pumpAndSettle();
        expect(
          container.read(songsProvider).requireValue.fileTypeFilter,
          SongFileTypeFilter.mp3,
        );
        await tester.ensureVisible(find.byType(Slider));
        expect(find.byType(Slider), findsOneWidget);
        Navigator.of(tester.element(find.byType(Slider))).pop();
        await tester.pumpAndSettle();

        expect(find.text('第二张专辑'), findsOneWidget);
        expect(find.text(active.songs2(_songs.length)), findsOneWidget);
        expect(l10n.localeName, active.localeName);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'multiselection and its playlist/delete subflows keep their copy role ($locale)',
      (tester) async {
        _setPhoneSize(tester);
        await tester.pumpWidget(_host(locale, sort: SongSortOption.title));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(LucideIcons.checkCheck));
        await tester.pumpAndSettle();
        expect(find.text(copy.selected(0)), findsOneWidget);
        await tester.tap(find.text(_songs.first.title));
        await tester.pumpAndSettle();
        expect(find.text(copy.selected(1)), findsOneWidget);
        for (final label in [
          copy.addToQueue2,
          copy.addToFavorites,
          copy.addToPlaylist,
          copy.moreActions,
        ]) {
          expect(find.byTooltip(label), findsOneWidget);
        }
        if (locale == kFilipinoLocale) {
          expect(find.text(active.selected(1)), findsNothing);
          expect(find.byTooltip(active.moreActions), findsNothing);
        }

        await tester.tap(find.byTooltip(copy.addToPlaylist));
        await tester.pumpAndSettle();
        expect(find.text(copy.addSongsToPlaylist(1)), findsOneWidget);
        expect(find.text(copy.createNewPlaylist), findsOneWidget);
        expect(find.text('Mga paborito ko'), findsOneWidget);
        await tester.tap(find.text(copy.createNewPlaylist));
        await tester.pumpAndSettle();
        _expectCreateDialog(copy);
        await tester.tap(find.text(copy.cancel));
        await tester.pumpAndSettle();

        await _openMore(tester, copy);
        for (final label in [
          copy.moreActions,
          copy.selectAll2,
          copy.createPlaylistFromSelected,
          copy.deleteSelected,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text(copy.selectAll2));
        await tester.pumpAndSettle();
        expect(find.text(copy.selected(2)), findsOneWidget);
        await _openMore(tester, copy);
        expect(find.text(copy.deselectAll), findsOneWidget);
        await tester.tap(find.text(copy.createPlaylistFromSelected));
        await tester.pumpAndSettle();
        _expectCreateDialog(copy);
        await tester.tap(find.text(copy.cancel));
        await tester.pumpAndSettle();

        await _openMore(tester, copy);
        await tester.tap(find.text(copy.deleteSelected));
        await tester.pumpAndSettle();
        for (final label in [
          copy.deleteSongs(2),
          copy.removeTheDatabaseEntriesOrDelete,
          copy.cancel,
          copy.removeFromLibrary,
          copy.deleteFiles,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        if (locale == kFilipinoLocale) {
          expect(find.text(active.deleteSongs(2)), findsNothing);
          expect(find.text(active.cancel), findsNothing);
        }
        // Only inspect and cancel the warning; never delete fixture files.
        await tester.tap(find.text(copy.cancel));
        await tester.pumpAndSettle();
        expect(find.text(copy.selected(2)), findsOneWidget);
        await _openMore(tester, copy);
        await tester.tap(find.text(copy.deselectAll));
        await tester.pumpAndSettle();
        expect(find.text(copy.selected(2)), findsNothing);
        expect(find.text(active.songs2(_songs.length)), findsOneWidget);
        expect(find.text(active.searchSongsArtists), findsOneWidget);
        expect(l10n.localeName, active.localeName);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Taglish multiselection playlist loading errors are English', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    await tester.pumpWidget(_host(kFilipinoLocale, playlistError: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.checkCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_songs.first.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(en.addToPlaylist));
    await tester.pumpAndSettle();
    expect(
      find.text(en.errorLoadingPlaylists2(StateError('playlist load failed'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish library-only selection has an English removal warning', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    await tester.pumpWidget(_host(kFilipinoLocale));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.checkCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_songs.last.title));
    await tester.pumpAndSettle();
    await _openMore(tester, en);
    await tester.tap(find.text(en.deleteSelected));
    await tester.pumpAndSettle();
    expect(find.text(en.deleteSongs(1)), findsOneWidget);
    expect(find.text(en.removeTheseSongsFromYourLibrary), findsOneWidget);
    expect(find.text(en.removeFromLibrary), findsOneWidget);
    expect(find.text(en.deleteFiles), findsNothing);
    await tester.tap(find.text(en.cancel));
    await tester.pumpAndSettle();
    expect(find.text(en.selected(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('caller-selected format labels do not replace the active locale', () {
    LocaleController.instance.bindLocale(kFilipinoLocale);
    final en = lookupFlickLocalizations(kFallbackLocale);
    expect(SongFileTypeFilter.all.displayNameFor(en), en.allFormats);
    expect(SongFileTypeFilter.all.displayName, l10n.allFormats);
    expect(SongFileTypeFilter.all.displayName, isNot(en.allFormats));
    for (final format in SongFileTypeFilter.values.skip(1)) {
      expect(format.displayNameFor(en), format.displayName);
    }
  });
}
