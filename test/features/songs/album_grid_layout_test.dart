import 'dart:io';
import 'dart:ui' as ui;

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/songs/screens/songs_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _songs = [
  for (final (index, (album, artist)) in const [
    ('#3 Deluxe Version', 'The Script'),
    (
      'A very long album title that needs an ellipsis',
      'A very long artist name',
    ),
    ('Échos, Ångström & gjpqy', 'Björk'),
    ('很长的专辑标题用来测试小屏幕', '一位名字很长的艺术家'),
  ].indexed)
    Song(
      id: '$index',
      title: 'Track $index',
      artist: artist,
      album: album,
      duration: const Duration(minutes: 4),
      fileType: 'FLAC',
    ),
];

class _AlbumSongsNotifier extends SongsNotifier {
  @override
  Future<SongsState> build() async =>
      SongsState(songs: _songs, sortOption: SongSortOption.album);
}

const _screenshotKey = ValueKey('album_grid_screenshot');
const _screenshots = bool.fromEnvironment('ALBUM_GRID_SCREENSHOTS');

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_screenshots) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screenshotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/album_grid_shots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songsProvider.overrideWith(_AlbumSongsNotifier.new),
        currentSongProvider.overrideWith((ref) => null),
        isCastingProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: kFallbackLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        localeResolutionCallback: resolveAppLocale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: RepaintBoundary(key: _screenshotKey, child: SongsScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectMetadataFits(WidgetTester tester, int columns, double width) {
  expect(tester.takeException(), isNull);
  final grid = tester.widget<GridView>(find.byType(GridView));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, columns);
  final artworkWidth =
      (width -
          AppConstants.spacingLg * 2 -
          AppConstants.spacingMd * (columns - 1)) /
      columns;

  for (final song in _songs) {
    final titleFinder = find.text(song.album!);
    final artistFinder = find.text(song.artist);
    final tileFinder = find
        .ancestor(of: titleFinder, matching: find.byType(InkWell))
        .first;
    final tile = tester.renderObject<RenderBox>(tileFinder);
    final title = tester.renderObject<RenderParagraph>(titleFinder);
    final artist = tester.renderObject<RenderParagraph>(artistFinder);
    final artwork = tester.getSize(
      find.descendant(of: tileFinder, matching: find.byType(AspectRatio)),
    );

    expect(artwork.width, closeTo(artworkWidth, 0.01));
    expect(artwork.height, closeTo(artwork.width, 0.01));
    expect(tile.size.height, closeTo(delegate.mainAxisExtent!, 0.01));
    expect(
      title.localToGlobal(Offset.zero, ancestor: tile).dy,
      closeTo(artwork.height + AppConstants.spacingMd, 0.01),
    );
    expect(
      artist.localToGlobal(Offset(0, artist.size.height), ancestor: tile).dy +
          AppConstants.spacingSm,
      lessThanOrEqualTo(tile.size.height + 0.01),
      reason: '${song.album}: artist and bottom padding must fit in the tile',
    );
    expect(
      artist.localToGlobal(Offset.zero, ancestor: tile).dy,
      greaterThanOrEqualTo(
        title.localToGlobal(Offset(0, title.size.height), ancestor: tile).dy +
            2,
      ),
    );
    for (final finder in [titleFinder, artistFinder]) {
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        find.ancestor(of: finder, matching: find.byType(ClipRRect)),
        findsNothing,
        reason: 'rounded clipping must apply to artwork, not metadata',
      );
    }
    expect(
      find.descendant(of: tileFinder, matching: find.byType(ClipRRect)),
      findsOneWidget,
    );
  }
}

Future<void> _pinchToColumns(WidgetTester tester, int columns) async {
  final center =
      tester.getTopLeft(find.byType(GridView)) + const Offset(198, 50);
  final first = await tester.startGesture(
    center - const Offset(50, 0),
    pointer: 1,
  );
  final second = await tester.startGesture(
    center + const Offset(50, 0),
    pointer: 2,
  );
  final halfDistance = 100 / columns;
  await first.moveTo(center - Offset(halfDistance, 0));
  await second.moveTo(center + Offset(halfDistance, 0));
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Real font metrics matter: the default test font hides clipped glyphs.
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

  for (final width in [360.0, 393.0, 396.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('album metadata fits at ${width}dp and ${scale}x text', (
        tester,
      ) async {
        await _pumpGrid(tester, width: width, textScale: scale);
        _expectMetadataFits(tester, 2, width);
        if (width == 396) await _snapshot(tester, '396dp_${scale}x_2columns');
      });
    }
  }

  for (final columns in [1, 3, 4]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('$columns-column pinch grid fits at ${scale}x text', (
        tester,
      ) async {
        await _pumpGrid(tester, width: 396, textScale: scale);
        await _pinchToColumns(tester, columns);
        _expectMetadataFits(tester, columns, 396);
        await _snapshot(tester, '396dp_${scale}x_${columns}columns');
      });
    }
  }
}
