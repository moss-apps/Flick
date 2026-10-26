// Playlist creation is an English surface in Taglish. English and Chinese keep
// their own copy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/features/playlists/screens/playlists_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/sources/network_source_service.dart';

class _EmptyPlaylists extends PlaylistsNotifier {
  @override
  Future<PlaylistsState> build() async =>
      const PlaylistsState(playlists: [], isLoading: false);
}

Widget _host({List<NetworkServerEntity> servers = const []}) => ProviderScope(
  overrides: [
    playlistsProvider.overrideWith(_EmptyPlaylists.new),
    networkServersProvider.overrideWith((ref) async => servers),
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
    home: const PlaylistsScreen(),
  ),
);

void _setPhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openCreateDialog(
  WidgetTester tester,
  AppLocalizations copy,
) async {
  await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
  await tester.pumpAndSettle();
  // The header popup's icon + label row overflows with the test font's wide
  // metrics. That layout is not part of the dialog under test.
  tester.takeException();
  await tester.tap(find.text(copy.createPlaylist));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'playlist creation dialog');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('Taglish playlist creation dialog uses English copy', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'playlists screen');
    await _openCreateDialog(tester, en);

    expect(find.text(en.createPlaylist), findsOneWidget);
    expect(find.text(en.playlistName), findsOneWidget);
    expect(find.text(en.cancel), findsOneWidget);
    expect(find.text(en.create), findsOneWidget);
    expect(find.text(tl.createPlaylist), findsNothing);
    expect(find.text(tl.playlistName), findsNothing);
    expect(find.text(tl.cancel), findsNothing);
    expect(find.text(tl.create), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Taglish playlist storage options use English copy', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    final server = NetworkServerEntity()
      ..id = 1
      ..label = 'Home server'
      ..protocol = NetworkProtocol.subsonic
      ..baseUrl = 'https://music.example.com';
    await tester.pumpWidget(_host(servers: [server]));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaylistsScreen)),
    );
    await tester.runAsync(() => container.read(networkServersProvider.future));
    await _openCreateDialog(tester, en);

    expect(find.text(en.storeOn), findsOneWidget);
    expect(find.text(en.thisDevice), findsOneWidget);
    expect(find.text(tl.storeOn), findsNothing);
    expect(find.text(tl.thisDevice), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
