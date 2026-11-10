import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/songs/widgets/song_card.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

const _song = Song(
  id: 'card-song',
  title: 'Original title',
  artist: 'Original artist',
  duration: Duration(minutes: 4),
  fileType: 'FLAC',
);

Widget _host({
  Song song = _song,
  double scale = 1,
  double opacity = 1,
  bool isSelected = false,
  bool isSelectionMode = false,
  bool isMultiSelected = false,
  double artSizeLarge = 110,
  double artResolutionMultiplier = 1.5,
  VoidCallback? onTap,
  VoidCallback? onSwipeLeft,
  VoidCallback? onSwipeRight,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SongCard(
        song: song,
        width: 320,
        scale: scale,
        opacity: opacity,
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
        isMultiSelected: isMultiSelected,
        artSizeBase: 70,
        artSizeLarge: artSizeLarge,
        artResolutionMultiplier: artResolutionMultiplier,
        swipeActionsEnabled: true,
        onTap: onTap,
        onSwipeLeft: onSwipeLeft,
        onSwipeRight: onSwipeRight,
      ),
    ),
  ),
);

void main() {
  testWidgets('motion retains the card face and its painted content', (
    tester,
  ) async {
    await tester.pumpWidget(_host(scale: 0.9, opacity: 0.8));
    final imageFinder = find.byType(CachedImageWidget).first;
    final image = tester.widget<CachedImageWidget>(imageFinder);
    final imageState = tester.state(imageFinder);
    final boundaryFinder = find.descendant(
      of: find.byType(SongCard),
      matching: find.byType(RepaintBoundary),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
    final paintedContent = boundary.debugLayer!.firstChild;
    expect(paintedContent, isNotNull);

    await tester.pumpWidget(_host(scale: 0.8, opacity: 0.7));
    expect(tester.widget(imageFinder), same(image));
    expect(tester.state(imageFinder), same(imageState));
    expect(tester.renderObject(boundaryFinder), same(boundary));
    expect(boundary.debugLayer!.firstChild, same(paintedContent));

    final opacity = tester.widget<Opacity>(
      find
          .descendant(of: find.byType(SongCard), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.child, isA<RepaintBoundary>());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-ID metadata and artwork updates refresh the retained face',
    (tester) async {
      await tester.pumpWidget(_host());
      final imageFinder = find.byType(CachedImageWidget).first;
      final originalImage = tester.widget<CachedImageWidget>(imageFinder);
      final imageState = tester.state(imageFinder);
      final edited = _song.copyWith(
        title: 'Edited title',
        artist: 'Edited artist',
        albumArt: '/missing/edited-cover.png',
        duration: const Duration(minutes: 5),
        fileType: 'WAV',
      );
      // Song equality compares IDs, not the metadata displayed by the card.
      expect(edited, _song);

      await tester.pumpWidget(_host(song: edited));
      expect(find.text('Original title'), findsNothing);
      expect(find.text('Edited title'), findsOneWidget);
      expect(find.text('Edited artist'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('WAV'), findsOneWidget);
      final updatedImage = tester.widget<CachedImageWidget>(imageFinder);
      expect(updatedImage, isNot(same(originalImage)));
      expect(updatedImage.imagePath, '/missing/edited-cover.png');
      expect(tester.state(imageFinder), same(imageState));
    },
  );

  testWidgets('landscape card keeps artwork above the song footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SongCard(
              song: _song,
              width: 220,
              height: 110,
              artSizeBase: 70,
              artworkAbove: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CachedImageWidget), findsOneWidget);
    final art = tester.getRect(find.byType(CachedImageWidget));
    final title = tester.getRect(find.text('Original title'));
    final artist = tester.getRect(find.text('Original artist'));
    expect(art.bottom, lessThanOrEqualTo(title.top));
    expect(title.bottom, lessThanOrEqualTo(artist.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection and artwork preferences refresh the retained face', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final imageFinder = find.byType(CachedImageWidget).first;
    final imageState = tester.state(imageFinder);
    expect(tester.widget<CachedImageWidget>(imageFinder).thumbnailWidth, 105);

    await tester.pumpWidget(_host(isSelected: true));
    expect(tester.widget<CachedImageWidget>(imageFinder).thumbnailWidth, 165);
    expect(tester.state(imageFinder), same(imageState));

    await tester.pumpWidget(
      _host(isSelected: true, artSizeLarge: 120, artResolutionMultiplier: 2),
    );
    expect(tester.widget<CachedImageWidget>(imageFinder).thumbnailWidth, 240);
    expect(tester.state(imageFinder), same(imageState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiselect changes refresh the retained face', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

    await tester.pumpWidget(_host(isSelectionMode: true));
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

    await tester.pumpWidget(
      _host(isSelectionMode: true, isMultiSelected: true),
    );
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('retained content uses current tap and swipe callbacks', (
    tester,
  ) async {
    var oldTaps = 0;
    var taps = 0;
    var queued = 0;
    var favorites = 0;
    await tester.pumpWidget(_host(onTap: () => oldTaps++));
    await tester.pumpWidget(
      _host(
        scale: 0.95,
        onTap: () => taps++,
        onSwipeLeft: () => queued++,
        onSwipeRight: () => favorites++,
      ),
    );
    await tester.tap(find.byType(SongCard));
    expect(oldTaps, 0);
    expect(taps, 1);

    await tester.drag(find.byType(SongCard), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(queued, 1);
    expect(favorites, 0);

    await tester.drag(find.byType(SongCard), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(queued, 1);
    expect(favorites, 1);
    expect(tester.takeException(), isNull);
  });
}
