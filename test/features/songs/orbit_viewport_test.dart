import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/core/utils/adaptive_layout.dart';
import 'package:flick/features/songs/screens/songs_screen.dart';
import 'package:flick/features/songs/widgets/orbit_scroll.dart';
import 'package:flick/features/songs/widgets/song_card.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _songs = List.generate(
  40,
  (i) => Song(
    id: 'orbit-$i',
    title: 'Song ${i.toString().padLeft(2, '0')}',
    artist: 'Artist',
    duration: const Duration(minutes: 4),
    fileType: 'FLAC',
  ),
);

class _OrbitSongs extends SongsNotifier {
  @override
  Future<SongsState> build() async =>
      SongsState(songs: _songs, sortOption: SongSortOption.title);
}

class _OrbitPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(
    fastIndexEnabled: false,
    orbitShowPath: false,
    orbitShowGlow: false,
    orbitLandscapeItemSpacing: 0.22,
    orbitLandscapeDepth: 0.2,
  );

  void update({bool? path, double? depth}) {
    state = state.copyWith(orbitShowPath: path, orbitLandscapeDepth: depth);
  }
}

const _shotKey = ValueKey('orbit_viewport_screenshot');
const _screenshots = bool.fromEnvironment('ORBIT_VIEWPORT_SCREENSHOTS');

Future<Uint8List> _pixels(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      if (_screenshots) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/orbit_viewport_shots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      }
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  Size size, {
  double railWidth = AdaptiveLayout.navigationRailWidth,
  double bottomInset = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songsProvider.overrideWith(_OrbitSongs.new),
        appPreferencesProvider.overrideWith(_OrbitPreferences.new),
        currentSongProvider.overrideWith((ref) => _songs[15]),
        isCastingProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: kFallbackLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: RepaintBoundary(
            key: _shotKey,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.background),
                ),
                Positioned.fill(
                  left: railWidth,
                  child: MediaQuery(
                    // Mirror the shell's content pane, including Android side
                    // safe areas and the full-height, clipped PageView.
                    data: MediaQueryData(
                      size: Size(size.width - railWidth, size.height),
                      padding: const EdgeInsets.only(left: 12, right: 20),
                    ),
                    child: PageView(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: RepaintBoundary(
                            child: SongsScreen(pathOverflowBottom: bottomInset),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SongsScreen)));
}

int _paintedPixels(Uint8List pixels, int width, Rect area) {
  var count = 0;
  for (var y = area.top.ceil(); y < area.bottom.floor(); y++) {
    for (var x = area.left.ceil(); x < area.right.floor(); x++) {
      if (pixels[(y * width + x) * 4] > 11) count++;
    }
  }
  return count;
}

int _changedPixels(
  Uint8List before,
  Uint8List after,
  int width,
  Rect area,
) {
  var count = 0;
  for (var y = area.top.ceil(); y < area.bottom.floor(); y++) {
    for (var x = area.left.ceil(); x < area.right.floor(); x++) {
      final index = (y * width + x) * 4;
      for (var channel = 0; channel < 3; channel++) {
        if ((before[index + channel] - after[index + channel]).abs() > 2) {
          count++;
          break;
        }
      }
    }
  }
  return count;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(900, 411), Size(1280, 800)]) {
    testWidgets('landscape cards and ribbon reach both edges at $size', (
      tester,
    ) async {
      final container = await _pumpScreen(tester, size);
      final prefs =
          container.read(appPreferencesProvider.notifier) as _OrbitPreferences;
      final stage = tester.getRect(find.byType(OrbitScroll));
      final width = size.width.toInt();
      final height = size.height.toInt();
      final cards = await _pixels(tester, '${width}_cards');

      // With the ribbon/glow disabled, these can only be card pixels. They
      // must survive outside both 28dp gutters, up to the page's real edges.
      expect(
        _paintedPixels(
          cards,
          width,
          Rect.fromLTRB(76, stage.top, stage.left + 27, height.toDouble()),
        ),
        greaterThan(20),
        reason: 'left cards must not stop at the gesture gutter',
      );
      expect(
        _paintedPixels(
          cards,
          width,
          Rect.fromLTRB(
            stage.right - 27,
            stage.top,
            width.toDouble(),
            height.toDouble(),
          ),
        ),
        greaterThan(20),
        reason: 'right cards must continue through the mini-player reservation',
      );

      // Shrink distant cards so they do not cover the rim at the screen edges.
      prefs.update(depth: 1);
      await tester.pumpAndSettle();
      final withoutPath = await _pixels(tester, '${width}_without_path');
      prefs.update(path: true);
      await tester.pumpAndSettle();
      final withPath = await _pixels(tester, '${width}_with_path');

      for (final x in [77, width - 2]) {
        var changed = 0;
        for (var y = stage.top.ceil(); y < height; y++) {
          final index = (y * width + x) * 4;
          if (withPath[index] > withoutPath[index] + 2) changed++;
        }
        expect(changed, greaterThan(3), reason: 'ribbon must reach x=$x');
      }
      expect(
        _changedPixels(
          withoutPath,
          withPath,
          width,
          Rect.fromLTRB(
            0,
            0,
            AdaptiveLayout.navigationRailWidth,
            height.toDouble(),
          ),
        ),
        0,
        reason: 'the ribbon must stay inside the Songs page',
      );
      expect(
        tester
            .widget<SongCard>(
              find.byWidgetPredicate((w) => w is SongCard && w.isSelected),
            )
            .song
            .id,
        'orbit-15',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('portrait orbit paints behind the library header', (tester) async {
    final container = await _pumpScreen(
      tester,
      const Size(411, 900),
      railWidth: 0,
    );
    final prefs =
        container.read(appPreferencesProvider.notifier) as _OrbitPreferences;
    prefs.update(path: true);
    await tester.pumpAndSettle();

    final stage = tester.getRect(find.byType(OrbitScroll));
    final cardTops = [
      for (var i = 0; i < find.byType(SongCard).evaluate().length; i++)
        tester.getRect(find.byType(SongCard).at(i)).top,
    ];
    expect(
      cardTops.any((top) => top < stage.top),
      isTrue,
      reason: 'the top orbit card should paint into the header area',
    );

    final withPath = await _pixels(tester, 'portrait_overlap');
    prefs.update(path: false);
    await tester.pumpAndSettle();
    final withoutPath = await _pixels(tester, 'portrait_overlap_without_path');
    expect(
      _changedPixels(
        withoutPath,
        withPath,
        411,
        Rect.fromLTRB(0, 0, 411, stage.top),
      ),
      greaterThan(100),
      reason: 'the orbit path should be visible behind the header/search',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait ribbon still paints through the shell bottom inset', (
    tester,
  ) async {
    final container = await _pumpScreen(
      tester,
      const Size(800, 1280),
      railWidth: 0,
      bottomInset: 180,
    );
    (container.read(appPreferencesProvider.notifier) as _OrbitPreferences)
        .update(path: true);
    await tester.pumpAndSettle();
    final pixels = await _pixels(tester, 'portrait_bottom_overflow');
    expect(
      _paintedPixels(pixels, 800, const Rect.fromLTRB(0, 1101, 800, 1280)),
      greaterThan(100),
    );
    expect(tester.takeException(), isNull);
  });
}
