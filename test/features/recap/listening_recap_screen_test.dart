import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/features/recap/screens/listening_recap_screen.dart';
import 'package:flick/features/recap/screens/replay_studio_screen.dart';
import 'package:flick/features/recap/widgets/replay_artwork.dart';
import 'package:flick/features/recap/widgets/replay_card_options.dart';
import 'package:flick/features/recap/widgets/replay_graphics.dart';
import 'package:flick/features/recap/widgets/replay_poster.dart';
import 'package:flick/features/recap/widgets/replay_sections.dart';
import 'package:flick/features/recap/widgets/replay_style.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements RecentlyPlayedRepository {
  final changes = StreamController<void>.broadcast();
  late Future<Map<ListeningRecapPeriod, ListeningRecap>> Function() load;

  _Repository(Map<ListeningRecapPeriod, ListeningRecap> data) {
    load = () async => data;
  }

  @override
  Future<Map<ListeningRecapPeriod, ListeningRecap>> getListeningRecaps({
    Iterable<ListeningRecapPeriod>? periods,
    DateTime? now,
  }) => load();

  @override
  Stream<void> watchHistory() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ListeningRecap _fixture(
  ListeningRecapPeriod period, {
  bool longText = false,
  String? art,
}) {
  final date = DateTime(2026, 10, 9);
  final songs = List.generate(
    5,
    (i) => RankedRecapSong(
      song: Song(
        id: '$i',
        title: longText
            ? 'An unusually long song title that must remain readable without breaking the layout — track $i'
            : [
                'Everything In Its Right Place',
                'Reckoner',
                'Nude',
                'Weird Fishes / Arpeggi',
                'How to Disappear Completely',
              ][i],
        artist: longText
            ? 'An artist with an exceptionally long name and more words'
            : 'Radiohead',
        album: 'Kid A',
        albumArt: art,
        duration: const Duration(minutes: 4),
        fileType: 'FLAC',
      ),
      plays: 25 - i * 3,
      listeningTime: Duration(minutes: (25 - i * 3) * 4),
      lastPlayedAt: date,
    ),
  );
  final artists = List.generate(
    5,
    (i) => RankedRecapArtist(
      artist: longText
          ? 'An exceptionally long artist name which spans several lines — artist $i'
          : [
              'Radiohead',
              'Björk',
              'Massive Attack',
              'Portishead',
              'James Blake',
            ][i],
      plays: 50 - i * 8,
      uniqueSongs: 5 - i,
      listeningTime: Duration(minutes: (50 - i * 8) * 4),
      lastPlayedAt: date,
    ),
  );
  final album = RankedRecapAlbum(
    album: longText
        ? 'An album title which stretches comfortably across more than one line'
        : 'Kid A',
    artist: artists.first.artist,
    plays: 48,
    uniqueSongs: 5,
    listeningTime: const Duration(minutes: 192),
    lastPlayedAt: date,
    representativeSong: songs.first.song,
  );
  final range = period.rangeFor(date);
  return ListeningRecap(
    period: period,
    start: range.start,
    endExclusive: range.endExclusive,
    totalPlays: 128,
    totalListeningTime: const Duration(minutes: 512),
    uniqueSongs: 24,
    uniqueArtists: 12,
    activeDays: 4,
    peakHour: 21,
    topSong: songs.first,
    topArtist: artists.first,
    topAlbum: album,
    topSongs: songs,
    topArtists: artists,
    topAlbums: [album],
  );
}

Map<ListeningRecapPeriod, ListeningRecap> _all({
  bool longText = false,
  String? art,
}) => {
  for (final period in ListeningRecapPeriod.values)
    period: _fixture(period, longText: longText, art: art),
};

final _screenKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = true,
  bool floatingNav = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          final media = MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          );
          return RepaintBoundary(
            key: _screenKey,
            child: MediaQuery(
              data: media,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // An obvious test backdrop makes an opaque navigation slab
                  // detectable. It is not a replacement for production ambient art.
                  ColoredBox(
                    color: floatingNav
                        ? const Color(0xFF222A2D)
                        : ReplayStyle.ink,
                  ),
                  MediaQuery(
                    data: floatingNav
                        ? media.copyWith(
                            padding: media.padding.copyWith(bottom: 160),
                            viewPadding: media.viewPadding.copyWith(
                              bottom: 160,
                            ),
                          )
                        : media,
                    child: child!,
                  ),
                  if (floatingNav)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: FlickNavBar(
                        currentIndex: 0,
                        onTap: (_) {},
                        config: NavBarConfig.defaultConfig,
                        showMiniPlayer: true,
                        // The real nav shell, with a deliberately simple player
                        // fixture so the test never initializes the audio engine.
                        miniPlayerWidget: const DefaultTextStyle(
                          style: TextStyle(
                            color: ReplayStyle.paper,
                            fontFamily: 'ProductSans',
                            fontSize: 14,
                          ),
                          child: SizedBox(
                            height: 56,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.music_note_rounded, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Everything In Its Right Place',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.pause_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        home: ListeningRecapScreen(repository: repository),
      ),
    ),
  );
  if (reducedMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REPLAY_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final boundary =
        _screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/opencode/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('ProductSans')
      ..addFont(rootBundle.load('assets/fonts/Product_Sans_Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Product_Sans_Bold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  testWidgets('living card overview and frozen studio snapshot', (
    tester,
  ) async {
    final repository = _Repository(_all());
    addTearDown(repository.changes.close);
    await _pump(tester, repository);
    expect(find.text('Flick Replay'), findsNWidgets(2));
    expect(find.text('128'), findsOneWidget);
    expect(find.text('Your most replayed track'), findsOneWidget);
    await _snapshot(tester, 'replay-overview');
    await tester.tap(find.byTooltip('Save / customize Replay'));
    await tester.pumpAndSettle();
    expect(find.byType(ReplayStudioScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .widget<ReplayStudioScreen>(find.byType(ReplayStudioScreen))
          .recap
          .totalPlays,
      128,
    );
    repository.load = () async => {
      for (final p in ListeningRecapPeriod.values)
        p: ListeningRecap.empty(p, p.rangeFor(DateTime(2026, 10, 9))),
    };
    repository.changes.add(null);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ReplayStudioScreen>(find.byType(ReplayStudioScreen))
          .recap
          .totalPlays,
      128,
    );
    await tester.tap(find.byTooltip('Back to Replay'));
    await tester.pumpAndSettle();
    expect(find.text('Your next favorite\nis waiting.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid period changes never share scroll positions', (
    tester,
  ) async {
    final repository = _Repository(_all());
    addTearDown(repository.changes.close);
    await _pump(tester, repository);
    for (final label in ['Weekly', 'Monthly', 'Daily', 'Yearly', 'Daily']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _snapshot(tester, 'replay-rankings');
  });

  testWidgets(
    'small phone, long metadata, and double text size can scroll all sections',
    (tester) async {
      final repository = _Repository(_all(longText: true));
      addTearDown(repository.changes.close);
      await _pump(
        tester,
        repository,
        size: const Size(320, 640),
        textScale: 2,
        reducedMotion: true,
      );
      await _snapshot(tester, 'replay-large-text-overview');
      await tester.scrollUntilVisible(
        find.text('Save / customize Replay'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save / customize Replay'), findsOneWidget);
      await tester.ensureVisible(find.text('Save / customize Replay'));
      await tester.pumpAndSettle();
      await _snapshot(tester, 'replay-large-text');
      await tester.tap(find.text('Save / customize Replay'));
      await tester.pumpAndSettle();
      for (final type in ['Top songs', 'Top artists', 'Top album', 'Replay']) {
        final choice = find.widgetWithText(ChoiceChip, type);
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReplayPoster>(find.byType(ReplayPoster)).type.label,
          type,
        );
        expect(tester.takeException(), isNull);
      }
      await _snapshot(tester, 'replay-studio-large-text');
    },
  );

  testWidgets('load failures are not empty history and retry recovers', (
    tester,
  ) async {
    final repository = _Repository(_all());
    addTearDown(repository.changes.close);
    repository.load = () async => throw StateError('Database unavailable');
    await _pump(tester, repository);
    expect(find.text('Replay couldn’t load.'), findsOneWidget);
    expect(find.text('Your next favorite\nis waiting.'), findsNothing);
    repository.load = () async => _all();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('128'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late refreshes cannot overwrite a newer recap', (tester) async {
    final repository = _Repository(_all());
    addTearDown(repository.changes.close);
    await _pump(tester, repository);
    final pending = Completer<Map<ListeningRecapPeriod, ListeningRecap>>();
    repository.load = () => pending.future;
    repository.changes.add(null);
    await tester.pump(const Duration(milliseconds: 250));
    repository.load = () async => {
      for (final p in ListeningRecapPeriod.values)
        p: ListeningRecap.empty(p, p.rangeFor(DateTime(2026, 10, 9))),
    };
    repository.changes.add(null);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    pending.complete(_all());
    await tester.pumpAndSettle();
    expect(find.text('Your next favorite\nis waiting.'), findsOneWidget);
  });

  testWidgets(
    'all static posters fit long titles and render 1260 x 2280 PNGs',
    (tester) async {
      final boundaryKey = GlobalKey();
      for (final type in ReplayPosterType.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ReplayPoster(
                      recap: _fixture(
                        ListeningRecapPeriod.monthly,
                        longText: true,
                      ),
                      type: type,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          try {
            expect(image.width, 1260);
            expect(image.height, 2280);
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            // Export preserves the studio's rounded card, including alpha.
            expect(pixels!.getUint8(3), 0);
            // A point safely inside the card remains fully opaque.
            expect(pixels.getUint8((80 * image.width + 80) * 4 + 3), 255);
          } finally {
            image.dispose();
          }
        });
      }
    },
  );

  testWidgets('artwork-led reference render', (tester) async {
    // An intentionally synthetic album-art fixture, never production content.
    Directory? directory;
    String? art;
    await tester.runAsync(() async {
      final root = Directory('/tmp/opencode');
      directory = await (root.existsSync() ? root : Directory.systemTemp)
          .createTemp('replay-art-');
      final image = img.Image(width: 320, height: 320);
      img.fill(image, color: img.ColorRgb8(191, 181, 158));
      img.fillRect(
        image,
        x1: 20,
        y1: 90,
        x2: 300,
        y2: 250,
        color: img.ColorRgb8(138, 61, 49),
      );
      img.fillRect(
        image,
        x1: 90,
        y1: 50,
        x2: 230,
        y2: 290,
        color: img.ColorRgb8(63, 72, 61),
      );
      art = '${directory!.path}/cover.png';
      await File(art!).writeAsBytes(img.encodePng(image));
    });
    addTearDown(() async => directory?.delete(recursive: true));
    final repository = _Repository(_all(art: art));
    addTearDown(repository.changes.close);
    await tester.runAsync(() async {
      final decoded = Completer<void>();
      final stream = FileImage(File(art!)).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, synchronous) => decoded.complete(),
        onError: (Object error, StackTrace? stack) =>
            decoded.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        await decoded.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await _snapshot(tester, 'replay-artwork-overview');
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    for (final section in [
      find.byWidgetPredicate(
        (widget) => widget is ReplayRankings && !widget.artists,
      ),
      find.byType(ReplayArtistFeature),
      find.byType(ReplayAlbumFeature),
    ]) {
      await tester.scrollUntilVisible(section, 280, scrollable: scrollable);
      await tester.ensureVisible(section);
      await tester.pumpAndSettle();
      await _snapshot(
        tester,
        'replay-section-${tester.widget(section).runtimeType}',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Save / customize Replay'));
    await tester.pumpAndSettle();
    await _snapshot(tester, 'replay-export');
    for (final type in ['Top songs', 'Top artists', 'Top album']) {
      await tester.tap(find.widgetWithText(ChoiceChip, type));
      await tester.pumpAndSettle();
      await _snapshot(tester, 'replay-export-$type');
    }
    // Warm the existing color service in a real async zone: image decoding is
    // native work, not Flutter's widget-test fake timer queue.
    await tester.runAsync(() async {
      expect(
        await ColorExtractionService().extractDominantColor(art),
        isNotNull,
      );
    });
    await tester.tap(find.widgetWithText(ChoiceChip, 'Artwork'));
    await tester.pumpAndSettle();
    final artworkPoster = tester.widget<ReplayPoster>(
      find.byType(ReplayPoster),
    );
    expect(artworkPoster.options.look, ReplayLook.artwork);
    expect(artworkPoster.options.artworkColor, isNotNull);
    await _snapshot(tester, 'replay-studio-artwork');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'covers settle once, ornaments live, and app motion preference stops tickers',
    (tester) async {
      final repository = _Repository(_all());
      addTearDown(repository.changes.close);
      await _pump(tester, repository, reducedMotion: false);
      final cover = find
          .descendant(
            of: find.byType(ReplayArtworkStage).first,
            matching: find.byType(ReplayArtwork),
          )
          .last;
      final settledCover = tester.getRect(cover);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(seconds: 8));
      expect(tester.getRect(cover), settledCover);
      repository.changes.add(null);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(tester.getRect(cover), settledCover);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListeningRecapScreen)),
      );
      await container
          .read(appPreferencesProvider.notifier)
          .setAnimationsEnabled(false);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'curated colors maintain body contrast across artwork hues and surface shading',
    () {
      for (final look in ReplayLook.values) {
        for (var hue = 0; hue < 360; hue += 15) {
          final options = ReplayCardOptions(
            look: look,
            artworkColor: HSLColor.fromAHSL(
              1,
              hue.toDouble(),
              0.7,
              0.5,
            ).toColor(),
          );
          for (final kind in ReplayCardKind.values) {
            for (final photo in [false, true]) {
              final palette = ReplayCardPalette.resolve(
                options,
                kind,
                photo: photo,
              );
              final shaded = palette.shadedBackground;
              expect(
                ReplayCardPalette.contrast(
                  palette.background,
                  palette.foreground,
                ),
                greaterThanOrEqualTo(4.5),
              );
              expect(
                ReplayCardPalette.contrast(shaded, palette.secondary),
                greaterThanOrEqualTo(4.5),
              );
              if (photo) {
                final brightestPhoto = Color.alphaBlend(
                  const Color(0xB8000000),
                  Colors.white,
                );
                expect(
                  ReplayCardPalette.contrast(brightestPhoto, palette.secondary),
                  greaterThanOrEqualTo(4.5),
                );
              }
            }
          }
        }
      }
    },
  );

  testWidgets(
    'ornaments stop offscreen, on covered routes, and immediately in the background',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: ReplayOrnament(
                      color: ReplayStyle.acid,
                      animated: true,
                      scrollController: scroll,
                    ),
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      scroll.jumpTo(700);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.binding.transientCallbackCount, 0);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'authored SVG contours remain inside their view at both motion extremes',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 240,
                height: 190,
                child: ReplayOrnament(color: Colors.white, animated: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final step in [
        const Duration(seconds: 1),
        const Duration(seconds: 7),
        const Duration(seconds: 16),
      ]) {
        await tester.pump(step);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          try {
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            int alpha(int x, int y) =>
                pixels!.getUint8((y * image.width + x) * 4 + 3);
            for (var x = 0; x < image.width; x++) {
              expect(alpha(x, 0), 0);
              expect(alpha(x, image.height - 1), 0);
            }
            for (var y = 0; y < image.height; y++) {
              expect(alpha(0, y), 0);
              expect(alpha(image.width - 1, y), 0);
            }
            var painted = 0;
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                if (alpha(x, y) > 0) painted++;
              }
            }
            expect(painted, greaterThan(500));
          } finally {
            image.dispose();
          }
        });
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'print capture settles the ornament in its first disabled paint',
    (tester) async {
      final key = GlobalKey();
      var animated = false;
      Widget host() => MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 240,
              height: 190,
              child: ReplayOrnament(color: Colors.white, animated: animated),
            ),
          ),
        ),
      );
      Future<List<int>> frame() async => (await tester.runAsync<List<int>>(
        () async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          try {
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            return pixels!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        },
      ))!;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final settled = await frame();
      animated = true;
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      expect(listEquals(await frame(), settled), isFalse);
      animated = false;
      await tester.pumpWidget(host());
      // No second pump: this is the same frame the studio's save can capture.
      expect(listEquals(await frame(), settled), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'studio customization survives system Back with period and scroll intact',
    (tester) async {
      final repository = _Repository(_all());
      addTearDown(repository.changes.close);
      await _pump(tester, repository);
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      final position = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      await tester.tap(find.byTooltip('Save / customize Replay'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Night'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Single'));
      await tester.pumpAndSettle();
      final poster = tester.widget<ReplayPoster>(find.byType(ReplayPoster));
      expect(poster.options.look, ReplayLook.night);
      expect(poster.options.layered, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReplayStudioScreen), findsNothing);
      final overview = tester.widget<ReplayOverview>(
        find.byType(ReplayOverview),
      );
      expect(overview.recap.period, ListeningRecapPeriod.weekly);
      expect(overview.options.look, ReplayLook.night);
      expect(overview.options.layered, isFalse);
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        position,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail choices are bounded, inspection matches the print, and exports remain reachable',
    (tester) async {
      final repository = _Repository(_all());
      addTearDown(repository.changes.close);
      await _pump(tester, repository);
      await tester.tap(find.byTooltip('Save / customize Replay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Peak hour'))
            .onSelected,
        isNull,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Track time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Peak hour'));
      await tester.pumpAndSettle();
      final poster = tester.widget<ReplayPoster>(find.byType(ReplayPoster));
      expect(poster.options.metrics, [
        ReplayMetric.songs,
        ReplayMetric.artists,
        ReplayMetric.peakHour,
      ]);
      await tester.tap(find.text('Tap to inspect · 1260 × 2280 PNG'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ReplayPoster>(find.byType(ReplayPoster))
            .every((p) => p.options.metrics.contains(ReplayMetric.peakHour)),
        isTrue,
      );
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More export options'));
      await tester.pumpAndSettle();
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Export TXT'), findsOneWidget);
      expect(find.text('Support Flick on Ko-fi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'floating navigation keeps its backdrop and studio dock stays above it',
    (tester) async {
      final repository = _Repository(_all());
      addTearDown(repository.changes.close);
      await _pump(tester, repository, floatingNav: true);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
      await _snapshot(tester, 'replay-floating-navigation');
      await tester.tap(find.byTooltip('Save / customize Replay'));
      await tester.pumpAndSettle();
      expect(find.byType(FlickNavBar), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
      final saveButton = tester.getRect(
        find.widgetWithText(FilledButton, 'Save PNG'),
      );
      final bar = tester.getRect(find.byType(FlickNavBar));
      expect(saveButton.bottom, lessThan(bar.top));
      await _snapshot(tester, 'replay-studio-floating-navigation');
      final boundary =
          _screenKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          // The transparent outer inset, far enough from the bar's shadow.
          final offset = (800 * image.width + 2) * 4;
          expect(pixels!.getUint8(offset), 0x22);
          expect(pixels.getUint8(offset + 1), 0x2A);
          expect(pixels.getUint8(offset + 2), 0x2D);
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'time and peak-hour copy describe existing data without implying elapsed tracking',
    () {
      expect(ReplayStyle.durationLabel(const Duration(minutes: 81)), '1h 21m');
      expect(ReplayStyle.peakHour(0), '12 AM');
      expect(ReplayStyle.peakHour(12), '12 PM');
      expect(ReplayStyle.peakHour(null), '—');
    },
  );
}
