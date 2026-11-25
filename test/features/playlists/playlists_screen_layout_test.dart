import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/features/playlists/screens/playlists_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/services/sources/network_source_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _playlistDate = DateTime(2026, 11, 25);
final _playlists = [
  Playlist(id: '1', name: 'Road trip', createdAt: _playlistDate),
  Playlist(
    id: '2',
    name: 'Server favorites',
    createdAt: _playlistDate,
    songIds: const ['remote-track'],
    sourcePath: 'subsonic://1/remote-list',
  ),
  Playlist(
    id: '3',
    name: 'A playlist with a very long title for a narrow screen',
    createdAt: _playlistDate,
  ),
];

class _TestPlaylists extends PlaylistsNotifier {
  _TestPlaylists(this.playlists);

  final List<Playlist> playlists;

  @override
  Future<PlaylistsState> build() async =>
      PlaylistsState(playlists: playlists, isLoading: false);
}

class _TestSongs extends SongsNotifier {
  _TestSongs(this.songs);

  final List<Song> songs;

  @override
  Future<SongsState> build() async => SongsState(songs: songs);
}

Future<void> _pumpPlaylists(
  WidgetTester tester, {
  double textScale = 1,
  List<Playlist>? playlists,
  List<Song> songs = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistsProvider.overrideWith(
          () => _TestPlaylists(playlists ?? _playlists),
        ),
        songsProvider.overrideWith(() => _TestSongs(songs)),
        currentSongProvider.overrideWithValue(null),
        networkServersProvider.overrideWith(
          (ref) async => [
            NetworkServerEntity()
              ..id = 1
              ..label = 'Music server'
              ..protocol = NetworkProtocol.subsonic
              ..baseUrl = 'https://music.example.com',
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: kAppLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        builder: (context, child) {
          LocaleController.instance.bind(AppLocalizations.of(context));
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const PlaylistsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setPhoneSize(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 850);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('switches from lists to two columns and remembers the choice', (
    tester,
  ) async {
    _setPhoneSize(tester, 390);
    await _pumpPlaylists(tester);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    await tester.tap(find.byTooltip('View as grid'));
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.text('Road trip'));
    final second = tester.getTopLeft(find.text('Server favorites'));
    final third = tester.getTopLeft(find.text(_playlists[2].name));
    expect(first.dy, second.dy);
    expect(first.dx, lessThan(second.dx));
    expect(third.dx, first.dx);
    expect(third.dy, greaterThan(first.dy));
    expect(find.text('Music server'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPlaylists(tester);
    expect(find.byTooltip('View as list'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.byTooltip('View as list'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 640.0]) {
    testWidgets('grid aligns with the list edges at ${width.toInt()}dp', (
      tester,
    ) async {
      _setPhoneSize(tester, width);
      await _pumpPlaylists(tester);

      Rect tileBounds(String title) => tester.getRect(
        find
            .ancestor(of: find.text(title), matching: find.byType(InkWell))
            .first,
      );

      final listTile = tileBounds('Road trip');
      await tester.tap(find.byTooltip('View as grid'));
      await tester.pumpAndSettle();

      expect(tileBounds('Road trip').left, listTile.left);
      expect(tileBounds('Server favorites').right, listTile.right);
    });
  }

  testWidgets('the card menu has playlist actions and fits large text', (
    tester,
  ) async {
    _setPhoneSize(tester, 320);
    await _pumpPlaylists(tester, textScale: 2);
    await tester.tap(find.byTooltip('View as grid'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final firstCard = find
        .ancestor(of: find.text('Road trip'), matching: find.byType(InkWell))
        .first;
    await tester.tap(
      find.descendant(
        of: firstCard,
        matching: find.byIcon(LucideIcons.ellipsisVertical),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Set cover'), findsOneWidget);
    expect(find.text('Export as .m3u'), findsOneWidget);
    expect(find.text('Export as .m3u8'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Road trip',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist collages do not reset the saved grid scroll offset', (
    tester,
  ) async {
    _setPhoneSize(tester, 390);
    final songs = [
      for (var i = 1; i <= 4; i++)
        Song(
          id: '$i',
          title: 'Track $i',
          artist: 'Artist $i',
          duration: const Duration(minutes: 3),
          fileType: 'FLAC',
          albumArt: '/missing-test-artwork-$i.png',
        ),
    ];
    await _pumpPlaylists(
      tester,
      songs: songs,
      playlists: [
        for (var i = 0; i < 40; i++)
          Playlist(
            id: '$i',
            name: 'Playlist $i',
            createdAt: _playlistDate,
            songIds: ['1', '2', '3', '4'],
          ),
      ],
    );
    await tester.tap(find.byTooltip('View as grid'));
    await tester.pumpAndSettle();
    expect(find.text('Artist 1 + 3 more'), findsWidgets);
    final scrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('playlists_grid')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(1210);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('View as list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View as grid'));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable).position.pixels, 1210);
  });
}
