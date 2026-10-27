// Full-player lyrics and three-dot sub-interfaces are English surfaces in
// Taglish. English and Chinese keep their own copy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/player/widgets/add_to_playlist_sheet.dart';
import 'package:flick/features/player/widgets/inline_lyrics_panel.dart';
import 'package:flick/features/player/widgets/pitch_bottom_sheet.dart';
import 'package:flick/features/player/widgets/player_navigation.dart';
import 'package:flick/features/player/widgets/sleep_timer_bottom_sheet.dart';
import 'package:flick/features/player/widgets/song_actions_sheet.dart';
import 'package:flick/features/player/widgets/song_metadata_sheet.dart';
import 'package:flick/features/player/widgets/speed_bottom_sheet.dart';
import 'package:flick/features/player/widgets/share/share_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';

const _song = Song(
  id: 'player-song-1',
  title: 'Original Title',
  artist: 'Original Artist',
  album: 'Original Album',
  albumArtist: 'Original Album Artist',
  duration: Duration(minutes: 3, seconds: 5),
  fileType: 'FLAC',
  resolution: '24-bit/96kHz',
  trackNumber: 4,
  discNumber: 2,
  year: 1999,
  genre: 'Original Genre',
  filePath: '/music/original.flac',
);

const _shareSong = Song(
  id: 'player-song-2',
  title: 'Share Title',
  artist: 'Share Artist',
  duration: Duration(minutes: 4),
  fileType: 'MP3',
);

class _EmptyPlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _EmptyPlaylists extends PlaylistsNotifier {
  @override
  Future<PlaylistsState> build() async =>
      const PlaylistsState(playlists: [], isLoading: false);
}

class _FixturePlaylists extends PlaylistsNotifier {
  _FixturePlaylists(this.playlists);

  final List<Playlist> playlists;

  @override
  Future<PlaylistsState> build() async =>
      PlaylistsState(playlists: playlists, isLoading: false);
}

class _EmptyLyricsService extends LyricsService {
  @override
  Future<LyricsData?> loadLyricsForSong(
    Song song, {
    bool forceRefresh = false,
  }) async => null;

  @override
  Future<String?> getManualLyricsPathForSong(Song song) async => null;
}

class _FakePlayerService extends Fake implements PlayerService {
  @override
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);

  @override
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.5);

  @override
  final ValueNotifier<double> pitchSemitonesNotifier = ValueNotifier(0.0);

  @override
  final ValueNotifier<Duration?> sleepTimerRemainingNotifier = ValueNotifier(
    null,
  );
}

class _FakeSongRepository extends Fake implements SongRepository {}

Widget _host(Widget child, {Locale locale = kFilipinoLocale}) => ProviderScope(
  overrides: [
    playerProvider.overrideWith(_EmptyPlayer.new),
    currentSongProvider.overrideWithValue(null),
    playlistsProvider.overrideWith(_EmptyPlaylists.new),
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Widget _playlistHost(Widget child) => ProviderScope(
  overrides: [
    playerProvider.overrideWith(_EmptyPlayer.new),
    currentSongProvider.overrideWithValue(null),
    playlistsProvider.overrideWith(
      () => _FixturePlaylists([
        Playlist(
          id: 'playlist-1',
          name: 'Mga paborito ko',
          songIds: const ['player-song-1', 'player-song-2'],
          createdAt: DateTime(2026, 10, 27),
        ),
      ]),
    ),
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

  testWidgets('Taglish full-player three-dot sheet uses English actions', (
    tester,
  ) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    final service = _FakePlayerService();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => SongActionsSheet(
            parentContext: context,
            playerService: service,
            song: _song,
            isVisualizationMode: false,
            onShowLyrics: () {},
            onToggleVisualization: (_) {},
            onShowPlayerLayout: (_) {},
            navigation: PlayerNavigation(
              playerService: service,
              songRepository: _FakeSongRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final english = [
      en.playerMenuAddToQueue,
      en.playerMenuAddToPlaylist,
      en.playerMenuSetAlbumArt,
      en.playerMenuRefreshAlbumArt,
      en.playerMenuEditMetadata,
      en.viewMetadata,
      en.lyrics,
      en.visualizer,
      en.goToArtist,
      en.goToAlbum,
      en.playerLayout,
      en.playbackSpeed,
      en.pitch,
      en.playerMenuSleepTimer,
      en.playerMenuShare,
    ];
    for (final copy in english) {
      expect(find.text(copy), findsOneWidget);
    }
    for (final copy in [
      tl.playerMenuAddToQueue,
      tl.playerMenuAddToPlaylist,
      tl.playerMenuSetAlbumArt,
      tl.playerMenuEditMetadata,
      tl.viewMetadata,
      tl.lyrics,
      tl.playerLayout,
      tl.playbackSpeed,
      tl.playerMenuSleepTimer,
      tl.playerMenuShare,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(find.text('Original Title'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish metadata sheet is English and keeps original metadata', (
    tester,
  ) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host(const SongMetadataSheet(song: _song)));
    await tester.pumpAndSettle();

    for (final copy in [
      en.songMetadata,
      en.title,
      en.artist,
      en.album,
      en.duration,
      en.format,
      en.resolution,
      en.albumArtist,
      en.genre,
      en.year,
      en.track,
      en.disc,
      en.filePath,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    for (final copy in [
      tl.songMetadata,
      tl.title,
      tl.artist,
      tl.duration,
      tl.albumArtist,
      tl.genre,
      tl.year,
      tl.track,
      tl.filePath,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    for (final value in [
      'Original Title',
      'Original Artist',
      'Original Album',
      '03:05',
      'FLAC',
      '24-bit/96kHz',
      'Original Album Artist',
      'Original Genre',
      '1999',
      '4',
      '2',
      '/music/original.flac',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish add-to-playlist flow is English', (tester) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _playlistHost(const AddToPlaylistSheet(songs: [_song])),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.addToPlaylist2), findsOneWidget);
    expect(find.text(tl.addToPlaylist2), findsNothing);
    expect(find.text('Mga paborito ko'), findsOneWidget);
    expect(find.text(en.songs9(2)), findsOneWidget);
    expect(find.text(tl.songs9(2)), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish empty add-to-playlist copy is English', (tester) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _host(const AddToPlaylistSheet(songs: [_song, _shareSong])),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.addSongsToPlaylist2(2)), findsOneWidget);
    expect(find.text(en.noPlaylistsYetNcreateOneIn), findsOneWidget);
    expect(find.text(tl.noPlaylistsYetNcreateOneIn), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish share sheet uses English copy and templates', (
    tester,
  ) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => MediaQuery(
            // The share previews are fixed 240x300 cards; the test font's
            // wider metrics overflow them at the default scale.
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: const ShareBottomSheet(song: _shareSong),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.share), findsWidgets);
    expect(find.text(tl.share), findsNothing);
    expect(find.text(en.lyric), findsOneWidget);
    expect(find.text(tl.lyric), findsNothing);
    expect(find.text(en.auto), findsOneWidget);
    expect(find.text(en.save), findsOneWidget);
    expect(find.text(tl.save), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish inline lyrics empty state is English', (tester) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 700,
          child: InlineLyricsPanel(
            playerService: _FakePlayerService(),
            lyricsService: _EmptyLyricsService(),
            song: _shareSong,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      en.noLyricsYet,
      en.searchOnlineCreateYourOwnSynced,
      en.createLyrics,
      en.useExistingFile,
      en.searchOnline,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    for (final copy in [
      tl.noLyricsYet,
      tl.searchOnlineCreateYourOwnSynced,
      tl.createLyrics,
      tl.useExistingFile,
      tl.searchOnline,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish playback speed, pitch and sleep timer are English', (
    tester,
  ) async {
    _setLargePhone(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    final service = _FakePlayerService();

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            SpeedBottomSheet(playerService: service),
            PitchBottomSheet(playerService: service),
            SleepTimerBottomSheet(playerService: service),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      en.playbackSpeed,
      en.x(0.5),
      en.x2(2.0),
      en.x3(1.5),
      en.pitch,
      en.off,
      en.sleepTimer2,
      en.m(5),
      en.m2(120),
      en.min(30),
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    for (final copy in [tl.playbackSpeed, tl.sleepTimer2, tl.off]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese metadata and lyrics stay Chinese', (tester) async {
    _setLargePhone(tester);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    final en = lookupFlickLocalizations(kFallbackLocale);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            const SongMetadataSheet(song: _song),
            SizedBox(
              height: 700,
              child: InlineLyricsPanel(
                playerService: _FakePlayerService(),
                lyricsService: _EmptyLyricsService(),
                song: _shareSong,
              ),
            ),
          ],
        ),
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      zh.songMetadata,
      zh.title,
      zh.artist,
      zh.albumArtist,
      zh.filePath,
      zh.noLyricsYet,
      zh.createLyrics,
      zh.useExistingFile,
      zh.searchOnline,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(en.songMetadata), findsNothing);
    expect(find.text(en.noLyricsYet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese share and timer copy stay Chinese', (tester) async {
    _setLargePhone(tester);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    final en = lookupFlickLocalizations(kFallbackLocale);
    final service = _FakePlayerService();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: Column(
              children: [
                const ShareBottomSheet(song: _shareSong),
                SpeedBottomSheet(playerService: service),
                SleepTimerBottomSheet(playerService: service),
              ],
            ),
          ),
        ),
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.share), findsWidgets);
    for (final copy in [zh.lyric, zh.save, zh.playbackSpeed, zh.sleepTimer2]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(en.share), findsNothing);
    expect(find.text(en.save), findsNothing);
    expect(find.text(en.playbackSpeed), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
