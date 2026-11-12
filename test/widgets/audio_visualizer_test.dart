import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/album_color_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/visualizer_source_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_service.dart';
import 'package:flick/services/visualizer_source.dart';
import 'package:flick/src/rust/api/visualizer_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Player extends Fake implements PlayerService {
  @override
  final isPlayingNotifier = ValueNotifier(true);
  @override
  final positionNotifier = ValueNotifier(const Duration(seconds: 60));
  @override
  final currentSongNotifier = ValueNotifier<Song?>(
    const Song(
      id: 'track',
      title: 'Track',
      artist: 'Artist',
      duration: Duration(minutes: 3),
      fileType: 'FLAC',
    ),
  );
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

class _CapturePlayer extends _Player {
  _CapturePlayer(this.currentEngineType);

  @override
  final AudioEngineType currentEngineType;
  @override
  late final selectedPlaybackModeNotifier = ValueNotifier(currentEngineType);
  @override
  final initializedPlaybackModeNotifier = ValueNotifier<AudioEngineType?>(null);
  final _bitPerfectProcessingLocked = ValueNotifier(false);
  @override
  ValueNotifier<bool> get bitPerfectProcessingLockedNotifier =>
      _bitPerfectProcessingLocked;
  @override
  bool get isCurrentTrackDoP => false;
  @override
  int get androidAudioSessionId => 42;

  @override
  void dispose() {
    selectedPlaybackModeNotifier.dispose();
    initializedPlaybackModeNotifier.dispose();
    bitPerfectProcessingLockedNotifier.dispose();
    super.dispose();
  }
}

class _CaptureAndroidService extends VisualizerService {
  int attaches = 0;
  int detaches = 0;

  @override
  Future<bool> attach(int sessionId) async {
    attaches++;
    return true;
  }

  @override
  Future<void> detach() async {
    detaches++;
    barHeightsNotifier.value = null;
  }

  @override
  void dispose() => barHeightsNotifier.dispose();
}

const _boundaryKey = Key('visualizer-pixels');

class _FakeVisualizerSource extends VisualizerSource {
  _FakeVisualizerSource([List<double>? bars])
    : _bars = bars,
      _mode = bars == null
          ? VisualizerSourceMode.unavailable
          : VisualizerSourceMode.rustFft;

  List<double>? _bars;
  VisualizerSourceMode _mode;
  int acquires = 0;
  int releases = 0;

  void emit(List<double>? bars) {
    _bars = bars;
    notifyListeners();
  }

  void setMode(VisualizerSourceMode mode) {
    _mode = mode;
    notifyListeners();
  }

  @override
  VisualizerSourceMode get mode => _mode;

  @override
  List<double>? get bars => _bars;

  @override
  bool get isAvailable =>
      _mode == VisualizerSourceMode.rustFft ||
      _mode == VisualizerSourceMode.android;

  @override
  bool get needsPermission => false;

  @override
  Future<bool> prepare() async => isAvailable;

  @override
  void acquire() => acquires++;

  @override
  void release() => releases++;
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    visualizerSourceProvider.overrideWith((ref) => _FakeVisualizerSource()),
  ],
);

class _BlockCanvas extends Fake implements Canvas {
  final blocks = <Rect>[];
  int drawCalls = 0;

  @override
  void drawRect(Rect rect, Paint paint) {
    drawCalls++;
    blocks.add(rect);
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    expect(pointMode, ui.PointMode.points);
    expect(paint.strokeCap, isNot(StrokeCap.round));
    drawCalls++;
    for (var i = 0; i < points.length; i += 2) {
      blocks.add(
        Rect.fromCenter(
          center: Offset(points[i], points[i + 1]),
          width: paint.strokeWidth,
          height: paint.strokeWidth,
        ),
      );
    }
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    drawCalls++;
    for (var sprite = 0; sprite < rstTransforms.length ~/ 4; sprite++) {
      final color = colors?[sprite] ?? 0xFFFFFFFF;
      if ((color >>> 24) == 0) continue;
      final index = sprite * 4;
      final scale = rstTransforms[index];
      final translateX = rstTransforms[index + 2];
      final translateY = rstTransforms[index + 3];
      blocks.add(
        Rect.fromLTWH(
          translateX + scale * rects[index],
          translateY + scale * rects[index + 1],
          scale * (rects[index + 2] - rects[index]),
          scale * (rects[index + 3] - rects[index + 1]),
        ),
      );
    }
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Player player,
  ProviderContainer container, {
  String style = 'bars',
  String frequencyMode = 'full',
  String movementMode = 'smooth',
  String? colorMode,
  Size size = const Size(360, 120),
  bool reducedMotion = false,
  bool enabled = true,
  bool ticking = true,
  bool simulationFallback = true,
}) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: ticking,
          child: Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox.fromSize(
                size: size,
                child: AudioVisualizer(
                  playerService: player,
                  animationStyle: style,
                  frequencyMode: frequencyMode,
                  movementMode: movementMode,
                  colorMode: colorMode,
                  enabled: enabled,
                  simulationFallback: simulationFallback,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<({int colored, Set<int> hues})> _pixelColors(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    var colored = 0;
    final hues = <int>{};
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final red = data.getUint8(i);
      final green = data.getUint8(i + 1);
      final blue = data.getUint8(i + 2);
      final chroma =
          math.max(red, math.max(green, blue)) -
          math.min(red, math.min(green, blue));
      if (data.getUint8(i + 3) < 30 || chroma < 20) continue;
      colored++;
      hues.add(
        (HSLColor.fromColor(Color.fromARGB(255, red, green, blue)).hue / 60)
            .floor(),
      );
    }
    return (colored: colored, hues: hues);
  }))!;
}

dynamic _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(AudioVisualizer),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every style renders rainbow, cover colors, and monochrome', (
    tester,
  ) async {
    final player = _Player();
    final container = ProviderContainer(
      overrides: [
        visualizerSourceProvider.overrideWith((ref) => _FakeVisualizerSource()),
        albumDominantColorSyncProvider.overrideWith((ref) => Colors.orange),
      ],
    );
    for (final style in [
      'bars',
      'wave',
      'curved_wave',
      'mirrored',
      'dots',
      'blocks',
    ]) {
      for (final mode in ['rainbow', 'album_art', 'monochrome']) {
        await _mount(tester, player, container, style: style, colorMode: mode);
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final pixels = await _pixelColors(tester);
        if (mode == 'monochrome') {
          expect(pixels.colored, 0, reason: style);
        } else {
          expect(pixels.colored, greaterThan(10), reason: '$style/$mode');
          if (mode == 'rainbow') {
            expect(pixels.hues.length, greaterThanOrEqualTo(4), reason: style);
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets(
    'color preference updates live and missing cover falls back to gray',
    (tester) async {
      final player = _Player();
      final container = ProviderContainer(
        overrides: [
          visualizerSourceProvider.overrideWith(
            (ref) => _FakeVisualizerSource(),
          ),
          albumDominantColorSyncProvider.overrideWith((ref) => null),
        ],
      );
      await tester.runAsync(() async {
        container.read(appPreferencesProvider);
        await pumpEventQueue();
      });
      await _mount(tester, player, container);
      await tester.pump(const Duration(milliseconds: 16));
      expect((await _pixelColors(tester)).colored, 0);
      await container
          .read(appPreferencesProvider.notifier)
          .setVisualizerColorMode('rainbow');
      await tester.pump();
      expect((await _pixelColors(tester)).hues.length, greaterThanOrEqualTo(4));
      await container
          .read(appPreferencesProvider.notifier)
          .setVisualizerColorMode('monochrome');
      await tester.pump();
      expect((await _pixelColors(tester)).colored, 0);
      await tester.pumpWidget(const SizedBox());
      player.dispose();
      container.dispose();
    },
  );

  testWidgets(
    'blocks stay the same square size in mini, artwork card and immersive layouts',
    (tester) async {
      final player = _Player();
      player.isPlayingNotifier.value = false;
      final container = _container();
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'monochrome',
      );
      final painter = _painter(tester) as CustomPainter;
      double? blockSize;
      final counts = <int>[];
      for (final size in [
        const Size(40, 18),
        const Size(360, 120),
        const Size(360, 360),
        const Size(360, 800),
        const Size(720, 360),
      ]) {
        final canvas = _BlockCanvas();
        painter.paint(canvas, size);
        expect(canvas.blocks, isNotEmpty, reason: '$size');
        blockSize ??= canvas.blocks.first.width;
        counts.add(canvas.blocks.length);
        for (final block in canvas.blocks) {
          expect(block.width, closeTo(block.height, 1e-9), reason: '$size');
          expect(block.width, closeTo(blockSize, 1e-9), reason: '$size');
          expect(block.left, greaterThanOrEqualTo(0));
          expect(block.top, greaterThanOrEqualTo(0));
          expect(block.right, lessThanOrEqualTo(size.width));
          expect(block.bottom, lessThanOrEqualTo(size.height));
        }
      }
      expect(counts[1], greaterThan(counts[0]));
      expect(counts[2], greaterThan(counts[1]));
      expect(counts[3], greaterThan(counts[2]));
      expect(counts[4], counts[2] * 2);

      final tiny = _BlockCanvas();
      painter.paint(tiny, const Size(2, 2));
      expect(
        tiny.blocks.single.width,
        closeTo(tiny.blocks.single.height, 1e-9),
      );
      expect(tiny.blocks.single.width, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      player.dispose();
      container.dispose();
    },
  );

  testWidgets(
    'blocks fit mini players and trails decay by elapsed time and reset',
    (tester) async {
      final player = _Player();
      final container = _container();
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      player.isPlayingNotifier.value = false;
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final List<double> trails = _painter(tester).blockOpacities;
      final index = trails.indexWhere(
        (opacity) => opacity > 0.05 && opacity < 0.9,
      );
      expect(index, greaterThanOrEqualTo(0));
      final before = trails[index];
      await tester.pump(const Duration(milliseconds: 100));
      final List<double> after = _painter(tester).blockOpacities;
      expect(after[index], closeTo(before * math.exp(-0.6), 0.001));

      player.currentSongNotifier.value = null;
      await tester.pump();
      final List<double> reset = _painter(tester).blockOpacities;
      expect(reset[index], 0);
      expect(reset.where((v) => v > 0).length, lessThanOrEqualTo(48));
      player.isPlayingNotifier.value = true;
      for (final style in ['bars', 'mirrored', 'blocks']) {
        await _mount(
          tester,
          player,
          container,
          style: style,
          colorMode: 'rainbow',
          size: const Size(40, 18),
        );
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          (await _pixelColors(tester)).colored,
          greaterThan(0),
          reason: style,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      player.dispose();
      container.dispose();
    },
  );

  testWidgets('hides the visualizer when the source is unavailable', (
    tester,
  ) async {
    final player = _Player();
    final container = ProviderContainer(
      overrides: [
        visualizerSourceProvider.overrideWith((ref) => _FakeVisualizerSource()),
      ],
    );
    await _mount(
      tester,
      player,
      container,
      style: 'bars',
      simulationFallback: false,
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AudioVisualizer),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('uses live source bars instead of the simulated renderer', (
    tester,
  ) async {
    final player = _Player();
    final bars = List<double>.generate(48, (i) => (i + 1) / 48);
    final container = ProviderContainer(
      overrides: [
        visualizerSourceProvider.overrideWith(
          (ref) => _FakeVisualizerSource(bars),
        ),
      ],
    );
    await _mount(
      tester,
      player,
      container,
      style: 'bars',
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    await tester.pump();

    final heights = (_painter(tester) as dynamic).barHeights as List<double>;
    expect(heights[30], closeTo(bars[30], 1e-9));
    expect(heights[24], closeTo(bars[24], 1e-9));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('live updates repaint without rebuilding the visualizer', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      style: 'blocks',
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    final painter = _painter(tester);
    final heights = painter.barHeights as List<double>;
    final trails = painter.blockOpacities as List<double>;
    source.emit(List.filled(48, 0.3));
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(_painter(tester), painter), isTrue);
      expect(identical(_painter(tester).barHeights, heights), isTrue);
      expect(identical(_painter(tester).blockOpacities, trails), isTrue);
    }
    expect(heights[24], closeTo(0.3, 0.001));
    await tester.pumpWidget(const SizedBox());
    expect(source.acquires, source.releases);
    player.dispose();
    container.dispose();
  });

  testWidgets('continuous capture cannot restart every display frame at zero', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.2));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    for (final mode in [
      VisualizerSourceMode.android,
      VisualizerSourceMode.rustFft,
    ]) {
      source.setMode(mode);
      for (final style in [
        'bars',
        'blocks',
        'wave',
        'curved_wave',
        'mirrored',
        'dots',
      ]) {
        await _mount(
          tester,
          player,
          container,
          style: style,
          colorMode: 'monochrome',
          simulationFallback: false,
        );
        final painter = _painter(tester);
        final double before = painter.barHeights[24];
        // Capture can arrive before every vsync when fullscreen painting drops
        // below the source's 20/30 Hz. It must not keep resetting the first tick.
        for (var frame = 0; frame < 40; frame++) {
          source.emit(List.filled(48, frame.isEven ? 0.8 : 0.9));
          await tester.pump(const Duration(milliseconds: 50));
          expect(identical(_painter(tester), painter), isTrue);
        }
        expect(
          painter.barHeights[24],
          greaterThan(before + 0.1),
          reason: '${mode.name}/$style must advance during continuous capture',
        );
        await tester.pumpWidget(const SizedBox());
        source.emit(List.filled(48, 0.2));
      }
    }
    player.dispose();
    container.dispose();
  });

  for (final engine in [
    AudioEngineType.normalAndroid,
    AudioEngineType.rustOboe,
  ]) {
    testWidgets(
      '${engine.name}: fullscreen and modal visualizers share continuous capture',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final player = _CapturePlayer(engine);
        final android = _CaptureAndroidService();
        var sequence = 0;
        var level = 0.2;
        final activations = <bool>[];
        final source = VisualizerSourceController(
          playerService: player,
          androidService: android,
          androidPlatform: true,
          permissionResolver: ({required bool request}) async => true,
          rustGetBars: () async => VisualizerBars(
            bars: Float32List.fromList(List.filled(48, level)),
            sampleRate: 48000,
            sequence: BigInt.from(++sequence),
          ),
          rustSetActive: ({required bool active}) async {
            activations.add(active);
            return true;
          },
        );
        final container = ProviderContainer(
          overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
        );
        addTearDown(player.dispose);
        addTearDown(container.dispose);
        await source.prepare();
        const fullKey = Key('fullscreen-spectrum');
        const sheetKey = Key('sheet-spectrum');
        var fullscreen = false;
        Widget spectrum(Key key) => AudioVisualizer(
          key: key,
          playerService: player,
          animationStyle: 'blocks',
          colorMode: 'rainbow',
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Stack(
                    children: [
                      if (fullscreen) Positioned.fill(child: spectrum(fullKey)),
                      SafeArea(
                        child: Wrap(
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                fullscreen = !fullscreen;
                              }),
                              child: const Text('Toggle visualizer'),
                            ),
                            TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (context) => SizedBox(
                                  height: 220,
                                  child: Column(
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close signal path'),
                                      ),
                                      Expanded(child: spectrum(sheetKey)),
                                    ],
                                  ),
                                ),
                              ),
                              child: const Text('Audio signal path'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        CustomPainter painterFor(Key key) => tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
        Timer? capture;
        if (engine == AudioEngineType.normalAndroid) {
          capture = Timer.periodic(const Duration(milliseconds: 50), (_) {
            android.barHeightsNotifier.value = List.filled(48, level);
          });
        }
        addTearDown(() => capture?.cancel());

        await tester.tap(find.text('Toggle visualizer'));
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final fullPainter = painterFor(fullKey);
        expect((fullPainter as dynamic).barHeights[24], closeTo(0.2, 0.01));
        await tester.tap(find.text('Audio signal path'));
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final sheetPainter = painterFor(sheetKey);
        expect((sheetPainter as dynamic).barHeights[24], closeTo(0.2, 0.01));
        final detachesBefore = android.detaches;
        for (var frame = 0; frame < 16; frame++) {
          level = frame.isEven ? 0.8 : 0.9;
          // Both captures can outpace a busy fullscreen display. Timers must
          // continue, both painters must move, and neither widget may rebuild.
          await tester.pump(const Duration(milliseconds: 50));
          expect(identical(painterFor(fullKey), fullPainter), isTrue);
          expect(identical(painterFor(sheetKey), sheetPainter), isTrue);
        }
        expect((fullPainter as dynamic).barHeights[24], greaterThan(0.6));
        expect((sheetPainter as dynamic).barHeights[24], greaterThan(0.6));
        expect(android.detaches, detachesBefore);
        if (engine == AudioEngineType.normalAndroid) {
          expect(android.attaches, 1);
          expect(activations, isEmpty);
        } else {
          expect(android.attaches, 0);
          expect(activations, [true]);
        }

        await tester.tap(find.text('Close signal path'));
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        level = 0.3;
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect((fullPainter as dynamic).barHeights[24], closeTo(0.3, 0.01));
        expect(android.detaches, detachesBefore);
        capture?.cancel();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        if (engine == AudioEngineType.rustOboe) {
          expect(activations, [true, false]);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pause eases the last real spectrum down before going idle', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    for (final style in [
      'bars',
      'wave',
      'curved_wave',
      'mirrored',
      'dots',
      'blocks',
    ]) {
      player.isPlayingNotifier.value = true;
      source.emit(List.filled(48, 0.8));
      await _mount(
        tester,
        player,
        container,
        style: style,
        colorMode: 'monochrome',
        simulationFallback: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      player.isPlayingNotifier.value = false;
      source.emit(null); // Capture stops immediately; only the UI may settle.
      await tester.pump();
      expect(_painter(tester).barHeights[24], closeTo(0.8, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester).barHeights[24], greaterThan(0.04));
      expect(_painter(tester).barHeights[24], lessThan(0.8));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painter(tester).barHeights[24], closeTo(0.04, 0.001));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('immersive blocks batch thousands of squares into few draws', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      style: 'blocks',
      colorMode: 'rainbow',
      simulationFallback: false,
    );
    final canvas = _BlockCanvas();
    (_painter(tester) as CustomPainter).paint(canvas, const Size(360, 800));
    expect(canvas.blocks, hasLength(5640));
    expect(canvas.drawCalls, lessThanOrEqualTo(31));
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('resuming interrupts the pause decay without a jump', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    for (final movement in ['smooth', 'snappy', 'bouncy']) {
      source.emit(List.filled(48, 0.8));
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        movementMode: movement,
        colorMode: 'monochrome',
        simulationFallback: false,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      final painter = _painter(tester);
      player.isPlayingNotifier.value = false;
      source.emit(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double pausedHeight = painter.barHeights[24];
      expect(pausedHeight, inExclusiveRange(0.04, 0.8));

      player.isPlayingNotifier.value = true;
      source.emit(List.filled(48, 0.9));
      await tester.pump();
      expect(painter.barHeights[24], closeTo(pausedHeight, 0.001));
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter.barHeights[24], greaterThan(pausedHeight));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(painter.barHeights[24], closeTo(0.9, 0.001));
      expect(identical(_painter(tester), painter), isTrue);
      expect(tester.binding.transientCallbackCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('live block trails keep elapsed time across capture retargets', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      style: 'blocks',
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    source.emit(List.filled(48, 0.2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final List<double> trails = _painter(tester).blockOpacities;
    const index = 24 * 20 + 15;
    var before = trails[index];
    expect(before, inExclusiveRange(0.01, 1.0));
    for (final level in [0.3, 0.2, 0.4]) {
      source.emit(List.filled(48, level));
      expect(trails[index], before);
      await tester.pump(const Duration(milliseconds: 50));
      expect(trails[index], closeTo(before * math.exp(-0.3), 0.001));
      before = trails[index];
    }
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('frequency changes repaint cached heights without new capture', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    final painter = _painter(tester);
    expect(painter.barHeights[30], 0.8);
    await _mount(
      tester,
      player,
      container,
      frequencyMode: 'bass',
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    expect(_painter(tester).barHeights[30], 0.04);
    expect(_painter(tester).barHeights[0], 0.8);
    expect(_painter(tester).shouldRepaint(painter), isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(source.acquires, 1);
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('production releases capture and stops offscreen or motion off', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    for (final state in [
      (enabled: true, reducedMotion: true, ticking: true),
      (enabled: true, reducedMotion: false, ticking: false),
      (enabled: false, reducedMotion: false, ticking: true),
    ]) {
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'monochrome',
        simulationFallback: false,
      );
      expect(source.acquires - source.releases, 1);
      source.emit(List.filled(48, 0.2));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'monochrome',
        enabled: state.enabled,
        reducedMotion: state.reducedMotion,
        ticking: state.ticking,
        simulationFallback: false,
      );
      expect(source.acquires, source.releases);
      expect(tester.binding.transientCallbackCount, 0);
      source.emit(List.filled(48, 0.9));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, 0);
      if (state.enabled) {
        final List<double> heights = _painter(tester).barHeights;
        expect(heights.every((height) => height == 0.04), isTrue);
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(source.acquires, source.releases);
    player.dispose();
    container.dispose();
  });

  testWidgets('unavailable output paths discard cached live motion', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8));
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    source.emit(List.filled(48, 0.2));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    for (final mode in [
      VisualizerSourceMode.unavailable,
      VisualizerSourceMode.dsdUnavailable,
    ]) {
      source.setMode(mode);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(AudioVisualizer),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(tester.binding.transientCallbackCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets('missing or unchanged live frames do not keep a ticker running', (
    tester,
  ) async {
    final player = _Player();
    final source = _FakeVisualizerSource(List.filled(48, 0.8))..emit(null);
    final container = ProviderContainer(
      overrides: [visualizerSourceProvider.overrideWith((ref) => source)],
    );
    await _mount(
      tester,
      player,
      container,
      colorMode: 'monochrome',
      simulationFallback: false,
    );
    expect(tester.binding.transientCallbackCount, 0);
    source.emit(List.filled(48, 0.8));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(_painter(tester).barHeights[24], closeTo(0.8, 0.001));
    expect(tester.binding.transientCallbackCount, 0);
    source.emit(List.filled(48, 0.8));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    player.dispose();
    container.dispose();
  });

  testWidgets(
    'pause, reduced motion, disabled and offscreen views stop ticking without attaching audio effects',
    (tester) async {
      final player = _Player();
      final container = _container();
      final calls = <MethodCall>[];
      const channel = MethodChannel('com.mossapps.flick/visualizer');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      player.isPlayingNotifier.value = false;
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
      player.isPlayingNotifier.value = true;
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
        reducedMotion: true,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
      );
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
        enabled: false,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await _mount(
        tester,
        player,
        container,
        style: 'blocks',
        colorMode: 'rainbow',
        ticking: false,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      expect(calls, isEmpty);
      player.dispose();
      container.dispose();
    },
  );
}
