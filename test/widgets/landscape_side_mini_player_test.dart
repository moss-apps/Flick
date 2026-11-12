import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/mini_player_config_provider.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_source.dart';
import 'package:flick/widgets/common/embedded_mini_player.dart';
import 'package:flick/widgets/common/landscape_mini_player_dock.dart';
import 'package:flick/widgets/common/landscape_side_mini_player.dart';
import 'package:flick/widgets/navigation/bottom_bar_geometry.dart';

const _song = Song(
  id: 'side-player-track',
  title: 'A title that should not appear',
  artist: 'An artist that should not appear',
  duration: Duration(minutes: 4),
  fileType: 'FLAC',
);

class _Player extends Fake implements PlayerService {
  @override
  final isPlayingNotifier = ValueNotifier(true);
  @override
  final positionNotifier = ValueNotifier(const Duration(seconds: 48));
  @override
  final currentSongNotifier = ValueNotifier<Song?>(_song);
  @override
  final usingRustBackendNotifier = ValueNotifier(false);

  @override
  void dispose() {
    isPlayingNotifier.dispose();
    positionNotifier.dispose();
    currentSongNotifier.dispose();
    usingRustBackendNotifier.dispose();
  }
}

class _FakeVisualizerSource extends VisualizerSource {
  @override
  VisualizerSourceMode get mode => VisualizerSourceMode.rustFft;

  @override
  List<double>? get bars => null;

  @override
  bool get isAvailable => true;

  @override
  bool get needsPermission => false;

  @override
  Future<bool> prepare() async => true;

  @override
  void acquire() {}

  @override
  void release() {}
}

Widget _host(
  ProviderContainer container, {
  required bool animationsEnabled,
  double height = 360,
  Widget child = const LandscapeSideMiniPlayer(),
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    localeResolutionCallback: resolveAppLocale,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(640, height),
        disableAnimations: !animationsEnabled,
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: height,
            child: TickerMode(enabled: animationsEnabled, child: child),
          ),
        ),
      ),
    ),
  ),
);

ProviderContainer _container(_Player player) {
  final container = ProviderContainer(
    overrides: [
      visualizerSourceProvider.overrideWith((ref) => _FakeVisualizerSource()),
      currentSongProvider.overrideWithValue(_song),
      isPlayingProvider.overrideWithValue(true),
      progressProvider.overrideWithValue(0.42),
      playerServiceProvider.overrideWithValue(player),
      albumDominantColorSyncProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<int> _visibleVisualizerPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(AudioVisualizer),
      matching: find.byType(RepaintBoundary),
    ),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    var visible = 0;
    for (var offset = 3; offset < data.lengthInBytes; offset += 4) {
      if (data.getUint8(offset) > 30) visible++;
    }
    return visible;
  }))!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('keeps the compact orbit controls in one vertical strip', (
    tester,
  ) async {
    final player = _Player();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      _host(_container(player), animationsEnabled: false),
    );
    await tester.pump();

    expect(find.byType(LandscapeSideMiniPlayer), findsOneWidget);
    expect(find.text(_song.title), findsNothing);
    expect(find.text(_song.artist), findsNothing);
    expect(find.byType(AudioVisualizer), findsNothing);
    expect(
      find.byKey(const ValueKey('side_mini_player_divider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('side_mini_player_progress')),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.pause), findsOneWidget);

    final strip = tester.getRect(find.byType(LandscapeSideMiniPlayer));
    final artwork = tester.getRect(find.byType(Hero));
    final divider = tester.getRect(
      find.byKey(const ValueKey('side_mini_player_divider')),
    );
    final progress = tester.getRect(
      find.byKey(const ValueKey('side_mini_player_progress')),
    );
    final play = tester.getRect(find.byTooltip(l10n.pause));

    expect(strip.width, 64);
    expect(artwork.top, lessThan(divider.top));
    expect(divider.bottom, lessThanOrEqualTo(play.top));
    expect(progress.left, strip.left);
    expect(progress.right, lessThan(play.center.dx));
    expect(progress.bottom, closeTo(strip.bottom - 8, 0.1));
  });

  testWidgets('rotates the visualizer so it grows from the right edge', (
    tester,
  ) async {
    final player = _Player();
    addTearDown(player.dispose);

    await tester.pumpWidget(_host(_container(player), animationsEnabled: true));
    await tester.pump();

    final visualizerFinder = find.byKey(
      const ValueKey('side_mini_player_visualizer'),
    );
    final visualizer = tester.widget<RotatedBox>(visualizerFinder);
    expect(visualizer.quarterTurns, 3);
    final painter = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(AudioVisualizer),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(painter.size.width, greaterThan(0));
    expect(painter.size.height, 48);

    final bounds = tester.getRect(visualizerFinder);
    final lowFrequencyBase = painter.localToGlobal(
      Offset(0, painter.size.height),
    );
    final highFrequencyBase = painter.localToGlobal(
      Offset(painter.size.width, painter.size.height),
    );
    expect(lowFrequencyBase.dx, closeTo(bounds.right, 0.01));
    expect(lowFrequencyBase.dy, closeTo(bounds.bottom, 0.01));
    expect(highFrequencyBase.dx, closeTo(bounds.right, 0.01));
    expect(highFrequencyBase.dy, closeTo(bounds.top, 0.01));
  });

  testWidgets('paints every style with and without artwork in short windows', (
    tester,
  ) async {
    final player = _Player();
    addTearDown(player.dispose);
    final container = _container(player);
    await tester.pumpWidget(_host(container, animationsEnabled: true));
    await tester.pump();

    for (final showArtwork in [true, false]) {
      await container
          .read(miniPlayerConfigProvider.notifier)
          .update((config) => config.copyWith(showArtwork: showArtwork));
      for (final style in [
        'bars',
        'wave',
        'curved_wave',
        'mirrored',
        'dots',
        'blocks',
      ]) {
        await container
            .read(appPreferencesProvider.notifier)
            .setVisualizerAnimationStyle(style);
        await tester.pumpWidget(
          _host(
            container,
            animationsEnabled: true,
            height: showArtwork ? 320 : 411,
          ),
        );
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        final bounds = tester.getRect(
          find.byKey(const ValueKey('side_mini_player_visualizer')),
        );
        final strip = tester.getRect(find.byType(LandscapeSideMiniPlayer));
        final divider = tester.getRect(
          find.byKey(const ValueKey('side_mini_player_divider')),
        );
        expect(bounds.width, 48);
        expect(bounds.height, greaterThan(100));
        expect(bounds.left, greaterThan(strip.left));
        expect(bounds.right, lessThan(strip.right));
        expect(bounds.bottom, lessThan(divider.top));
        if (showArtwork) {
          expect(
            bounds.top,
            greaterThan(tester.getRect(find.byType(Hero)).bottom),
          );
        }
        expect(
          await _visibleVisualizerPixels(tester),
          greaterThan(20),
          reason: '$style, artwork: $showArtwork',
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('visualizer visibility still follows the preference', (
    tester,
  ) async {
    final player = _Player();
    addTearDown(player.dispose);
    final container = _container(player);
    await tester.pumpWidget(_host(container, animationsEnabled: true));
    await tester.pump();

    await container
        .read(appPreferencesProvider.notifier)
        .setVisualizerEnabled(false);
    await tester.pump();
    expect(find.byType(AudioVisualizer), findsNothing);

    await container
        .read(appPreferencesProvider.notifier)
        .setVisualizerEnabled(true);
    await tester.pump();
    expect(find.byType(AudioVisualizer), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('side_mini_player_visualizer')))
          .width,
      48,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final separated in [false, true]) {
    testWidgets('dock preserves real player layouts, separated: $separated', (
      tester,
    ) async {
      final player = _Player();
      addTearDown(player.dispose);
      final container = _container(player);
      await container
          .read(miniPlayerConfigProvider.notifier)
          .update(
            (config) =>
                config.copyWith(height: 72, navigationGap: 20, textScale: 1.8),
          );

      Future<void> show(bool sideDocked) => tester.pumpWidget(
        _host(
          container,
          animationsEnabled: true,
          child: Builder(
            builder: (context) {
              final config = container.read(miniPlayerConfigProvider);
              return LandscapeMiniPlayerDock(
                sideDocked: sideDocked,
                bottomPlayerHeight:
                    BottomBarGeometry.miniPlayerHeight(context, config) +
                    12 +
                    (separated ? config.navigationGap : 8),
                bottomPlayer: EmbeddedMiniPlayer(separated: separated),
                sidePlayer: const LandscapeSideMiniPlayer(),
              );
            },
          ),
        ),
      );

      await show(false);
      await tester.pump();
      final bottomSurface = tester.getRect(
        find.byKey(const ValueKey('mini_player_surface')),
      );
      expect(bottomSurface.height, 72);

      await show(true);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(EmbeddedMiniPlayer), findsOneWidget);
      expect(find.byType(LandscapeSideMiniPlayer), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('mini_player_surface'))),
        bottomSurface.size,
      );
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 140));
      expect(find.byType(EmbeddedMiniPlayer), findsNothing);
      expect(tester.getSize(find.byType(LandscapeSideMiniPlayer)).width, 64);

      await show(false);
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byType(LandscapeSideMiniPlayer), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('mini_player_surface'))),
        bottomSurface,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
