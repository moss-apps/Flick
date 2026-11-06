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
        find.descendant(of: finder, matching: find.byType(CachedImageWidget)),
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
          find.descendant(of: finder, matching: find.byType(CachedImageWidget)),
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
}
