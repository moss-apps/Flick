import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/features/player/widgets/share/share_cards/album_art_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/lyric_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/minimal_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/solid_color_share_card.dart';
import 'package:flick/models/song.dart';

const Song _song = Song(
  id: '1',
  title: 'A very long song title that wraps onto a second line for sure',
  artist: 'An artist name that also runs long enough to ellipsize',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
);

Widget _host(Widget card) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: SizedBox(width: 240, height: 300, child: card)),
  ),
);

void main() {
  testWidgets('share cards scale their metadata without overflowing', (
    tester,
  ) async {
    final cards = <Widget>[
      const LyricShareCard(song: _song, textScale: 1.4),
      const SolidColorShareCard(song: _song, textScale: 1.4),
      const MinimalShareCard(song: _song, textScale: 1.4),
      const AlbumArtShareCard(song: _song, textScale: 1.4),
    ];

    for (final card in cards) {
      await tester.pumpWidget(_host(card));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('text scale multiplies the title size', (tester) async {
    await tester.pumpWidget(
      _host(const SolidColorShareCard(song: _song, textScale: 1.25)),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text(_song.title));
    expect(title.style!.fontSize, closeTo(18 * 1.25, 0.001));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a reframed cover overrides only the foreground', (tester) async {
    await tester.pumpWidget(
      _host(
        const SolidColorShareCard(
          song: _song,
          albumArtPath: '/missing/backdrop.jpg',
          coverArtPath: '/missing/cover.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    expect(images[0].image, isA<FileImage>());
    expect((images[0].image as FileImage).file.path, '/missing/backdrop.jpg');
    expect((images[1].image as FileImage).file.path, '/missing/cover.jpg');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
