import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/songs/widgets/orbit_scroll.dart';
import 'package:flick/features/songs/widgets/song_card.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

final _songs = List.generate(
  40,
  (i) => Song(
    id: 'orbit-$i',
    title: 'Song $i with a longer title',
    artist: 'Artist $i',
    duration: const Duration(minutes: 4),
    fileType: 'FLAC',
  ),
);

void main() {
  void setView(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(
    PageController pages, {
    int selected = 15,
    Axis axis = Axis.horizontal,
    OrbitScrollController? orbit,
    ValueChanged<int>? onChanged,
    ValueChanged<int>? onAction,
    double textScale = 1,
    double radiusRatio = 1.0,
    double centerYRatio = 0.42,
    double itemSpacing = 0.28,
    double selectedScale = 1.25,
    double depth = 0.75,
    int visibleItems = 5,
    double cardWidthRatio = 0.68,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: PageView(
        controller: pages,
        children: [
          Column(
            children: [
              Container(
                key: const ValueKey('header'),
                height: 64,
                color: Colors.black,
              ),
              Expanded(
                child: OrbitScroll(
                  key: const ValueKey('orbit'),
                  songs: _songs,
                  selectedIndex: selected,
                  scrollDirection: axis,
                  controller: orbit,
                  swipeActionsEnabled: true,
                  radiusRatio: radiusRatio,
                  centerYRatio: centerYRatio,
                  itemSpacing: itemSpacing,
                  selectedScale: selectedScale,
                  depth: depth,
                  visibleItems: visibleItems,
                  cardWidthRatio: cardWidthRatio,
                  onSelectedIndexChanged: onChanged,
                  onSongSwipedLeft: onAction,
                  onSongSwipedRight: onAction,
                ),
              ),
            ],
          ),
          const Center(child: Text('Next destination')),
        ],
      ),
    ),
  );

  testWidgets('horizontal orbit wins over navigation, including on a card', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    addTearDown(pages.dispose);
    var selected = 15;
    var actions = 0;
    await tester.pumpWidget(
      host(pages, onChanged: (i) => selected = i, onAction: (_) => actions++),
    );
    final card = find.byWidgetPredicate((w) => w is SongCard && w.isSelected);
    await tester.dragFrom(tester.getCenter(card), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(selected, greaterThan(15));
    expect(pages.page, 0);
    expect(actions, 0);
    expect(tester.takeException(), isNull);
  });

  for (final edge in [0, 39]) {
    testWidgets('orbit boundary $edge never leaks a fling into navigation', (
      tester,
    ) async {
      setView(tester, const Size(900, 411));
      final pages = PageController();
      addTearDown(pages.dispose);
      await tester.pumpWidget(host(pages, selected: edge));
      await tester.flingFrom(
        const Offset(450, 220),
        Offset(edge == 0 ? 250 : -250, 0),
        900,
      );
      await tester.pumpAndSettle();
      expect(pages.page, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('header and side gutters retain navigation swipes', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    addTearDown(pages.dispose);
    await tester.pumpWidget(host(pages));
    await tester.dragFrom(const Offset(700, 32), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    pages.jumpToPage(0);
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(16, 220), const Offset(-220, 0), 1000);
    await tester.pumpAndSettle();
    expect(pages.page, 1);
  });

  testWidgets('cancel and rotation retain selection and external jumps', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    final orbit = OrbitScrollController();
    addTearDown(pages.dispose);
    var selected = 15;
    await tester.pumpWidget(
      host(pages, orbit: orbit, onChanged: (i) => selected = i),
    );
    final gesture = await tester.startGesture(const Offset(450, 220));
    await gesture.moveBy(const Offset(-80, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(pages.page, 0);
    orbit.jumpToIndex(24, animate: false);
    await tester.pump();
    expect(selected, 24);
    tester.view.physicalSize = const Size(411, 900);
    await tester.pumpWidget(
      host(pages, orbit: orbit, axis: Axis.vertical, selected: selected),
    );
    await tester.pumpAndSettle();
    final card = tester.widget<SongCard>(
      find.byWidgetPredicate((w) => w is SongCard && w.isSelected),
    );
    expect(card.song.id, 'orbit-24');
    expect(card.artworkAbove, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('songs retain card and artwork state as the orbit advances', (
    tester,
  ) async {
    setView(tester, const Size(411, 900));
    final pages = PageController();
    final orbit = OrbitScrollController();
    addTearDown(pages.dispose);
    await tester.pumpWidget(host(pages, orbit: orbit, axis: Axis.vertical));

    final cardStates = <String, State>{};
    final imageStates = <String, State>{};
    for (final element in find.byType(SongCard).evaluate()) {
      final card = element.widget as SongCard;
      final finder = find.byWidget(card);
      cardStates[card.song.id] = tester.state(finder);
      imageStates[card.song.id] = tester.state(
        find
            .descendant(
              of: finder,
              matching: find.byType(CachedImageWidget),
            )
            .first,
      );
    }

    orbit.jumpToIndex(16, animate: false);
    await tester.pump();
    var retained = 0;
    for (final element in find.byType(SongCard).evaluate()) {
      final card = element.widget as SongCard;
      if (!cardStates.containsKey(card.song.id)) continue;
      final finder = find.byWidget(card);
      expect(tester.state(finder), same(cardStates[card.song.id]));
      expect(
        tester.state(
          find
              .descendant(
                of: finder,
                matching: find.byType(CachedImageWidget),
              )
              .first,
        ),
        same(imageStates[card.song.id]),
      );
      retained++;
    }
    expect(retained, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape cards fit with enlarged text', (tester) async {
    setView(tester, const Size(640, 240));
    final pages = PageController();
    addTearDown(pages.dispose);
    await tester.pumpWidget(host(pages, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape settings drive card count, depth and selected scale', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    addTearDown(pages.dispose);

    Future<void> pump({
      double selectedScale = 1.25,
      double depth = 0.75,
      int visibleItems = 5,
    }) async {
      await tester.pumpWidget(
        host(
          pages,
          selectedScale: selectedScale,
          depth: depth,
          visibleItems: visibleItems,
        ),
      );
      await tester.pumpAndSettle();
    }

    SongCard selectedCard() => tester.widget<SongCard>(
      find.byWidgetPredicate(
        (widget) => widget is SongCard && widget.isSelected,
      ),
    );
    SongCard card(int index) => tester.widget<SongCard>(
      find.byWidgetPredicate(
        (widget) => widget is SongCard && widget.song.id == 'orbit-$index',
      ),
    );

    await pump();
    expect(find.byType(SongCard), findsNWidgets(5));
    expect(selectedCard().scale, closeTo(1.25, 0.001));
    expect(card(16).scale, closeTo(1.0 - 0.6 * 0.75, 0.001));

    await pump(depth: 0.2);
    expect(card(16).scale, closeTo(1.0 - 0.6 * 0.2, 0.001));

    await pump(selectedScale: 1.8);
    expect(selectedCard().scale, closeTo(1.8, 0.001));

    await pump(visibleItems: 7);
    expect(find.byType(SongCard), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape radius, spacing and width feed the renderer', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    addTearDown(pages.dispose);
    final selected = find.byWidgetPredicate(
      (widget) => widget is SongCard && widget.isSelected,
    );
    final neighbor = find.byWidgetPredicate(
      (widget) => widget is SongCard && widget.song.id == 'orbit-16',
    );

    Future<void> pump({
      double radiusRatio = 1.0,
      double itemSpacing = 0.28,
      double cardWidthRatio = 0.68,
    }) async {
      await tester.pumpWidget(
        host(
          pages,
          radiusRatio: radiusRatio,
          itemSpacing: itemSpacing,
          cardWidthRatio: cardWidthRatio,
        ),
      );
      await tester.pumpAndSettle();
    }

    double neighborOffset() =>
        (tester.getCenter(neighbor).dx - tester.getCenter(selected).dx).abs();

    await pump();
    final baseOffset = neighborOffset();
    final baseWidth = tester.widget<SongCard>(selected).width!;

    await pump(radiusRatio: 1.4);
    expect(neighborOffset(), greaterThan(baseOffset * 1.3));

    await pump(itemSpacing: 0.5);
    expect(neighborOffset(), greaterThan(baseOffset * 1.5));

    await pump(cardWidthRatio: 0.5);
    expect(tester.widget<SongCard>(selected).width!, lessThan(baseWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape focal position follows the profile value', (
    tester,
  ) async {
    setView(tester, const Size(900, 411));
    final pages = PageController();
    addTearDown(pages.dispose);
    final selected = find.byWidgetPredicate(
      (widget) => widget is SongCard && widget.isSelected,
    );

    await tester.pumpWidget(host(pages, centerYRatio: 0.3, selectedScale: 1.0));
    await tester.pumpAndSettle();
    final high = tester.getCenter(selected).dy;

    await tester.pumpWidget(host(pages, centerYRatio: 0.6, selectedScale: 1.0));
    await tester.pumpAndSettle();
    final low = tester.getCenter(selected).dy;

    expect(low, greaterThan(high + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected landscape card stays inside the stage at extremes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = PageController();
    addTearDown(pages.dispose);
    final orbit = find.byKey(const ValueKey('orbit'));
    final selected = find.byWidgetPredicate(
      (widget) => widget is SongCard && widget.isSelected,
    );

    for (final size in const [Size(900, 411), Size(640, 240)]) {
      for (final centerYRatio in const [0.3, 0.6]) {
        for (final selectedScale in const [1.0, 1.8]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            host(
              pages,
              centerYRatio: centerYRatio,
              selectedScale: selectedScale,
              radiusRatio: 2.0,
              cardWidthRatio: 0.85,
              visibleItems: 7,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();

          final stage = tester.getRect(orbit);
          final card = tester.getRect(selected);
          final reason = '$size centerY=$centerYRatio scale=$selectedScale';
          expect(
            card.top,
            greaterThanOrEqualTo(stage.top - 0.5),
            reason: reason,
          );
          expect(
            card.bottom,
            lessThanOrEqualTo(stage.bottom + 0.5),
            reason: reason,
          );
          expect(
            card.left,
            greaterThanOrEqualTo(stage.left - 0.5),
            reason: reason,
          );
          expect(
            card.right,
            lessThanOrEqualTo(stage.right + 0.5),
            reason: reason,
          );
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
    }
  });
}
