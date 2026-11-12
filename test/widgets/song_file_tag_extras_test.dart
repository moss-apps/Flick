// Read-only file tags that are not stored in the library database. Both
// metadata sheets mount this widget, including for SAF-imported files.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:flick/widgets/common/song_file_tag_extras.dart';

const _song = Song(
  id: 'tag-song-1',
  title: 'Reference Note',
  artist: 'Test Artist',
  duration: Duration(minutes: 3),
  fileType: 'OPUS',
  filePath: '/music/reference-note.opus',
);

const _otherSong = Song(
  id: 'tag-song-2',
  title: 'Other Note',
  artist: 'Test Artist',
  duration: Duration(minutes: 4),
  fileType: 'OPUS',
  filePath: '/music/other.opus',
);

Widget _host(
  Widget child, {
  Locale locale = kFallbackLocale,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  locale: locale,
  supportedLocales: kSupportedLocales,
  localizationsDelegates: kAppLocalizationsDelegates,
  builder: (context, child) {
    LocaleController.instance.bind(AppLocalizations.of(context));
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
  },
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('shows the comment with date, copyright, and label', (
    tester,
  ) async {
    final seenPaths = <String>[];
    await tester.pumpWidget(
      _host(
        SongFileTagExtras(
          song: _song,
          readTags: (path) async {
            seenPaths.add(path);
            return const rust_metadata.TagReadResult(
              comment: 'Reference note for the opus file.\n\nSecond paragraph.',
              date: '2019-04-12',
              copyright: '2019 Example Records',
              label: 'Example Records',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seenPaths, ['/music/reference-note.opus']);
    expect(find.text('Comment'), findsOneWidget);
    expect(
      find.text('Reference note for the opus file.\n\nSecond paragraph.'),
      findsOneWidget,
    );
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('2019-04-12'), findsOneWidget);
    expect(find.text('Copyright'), findsOneWidget);
    expect(find.text('Label / Organization'), findsOneWidget);
    expect(find.text('Example Records'), findsWidgets);
  });

  testWidgets('hides blank rows and a year-only recording date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SongFileTagExtras(song: _song, readTags: _blankAndLabelTags)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comment'), findsNothing);
    expect(find.text('Date'), findsNothing);
    expect(find.text('Copyright'), findsNothing);
    expect(find.text('Label / Organization'), findsOneWidget);
    expect(find.text('Example Records'), findsOneWidget);
  });

  testWidgets('reads once per opening and reloads when the path changes', (
    tester,
  ) async {
    final reads = <String>[];
    Future<rust_metadata.TagReadResult?> readTags(String path) async {
      reads.add(path);
      return rust_metadata.TagReadResult(comment: 'Note for $path');
    }

    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _song, readTags: readTags)),
    );
    await tester.pumpAndSettle();
    expect(reads, ['/music/reference-note.opus']);

    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _song, readTags: readTags)),
    );
    await tester.pumpAndSettle();
    expect(reads, ['/music/reference-note.opus']);

    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _otherSong, readTags: readTags)),
    );
    await tester.pumpAndSettle();
    expect(reads, ['/music/reference-note.opus', '/music/other.opus']);
    expect(find.text('Note for /music/other.opus'), findsOneWidget);

    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _song, readTags: readTags)),
    );
    await tester.pumpAndSettle();
    expect(reads, [
      '/music/reference-note.opus',
      '/music/other.opus',
      '/music/reference-note.opus',
    ]);
  });

  testWidgets('hides previous tags while a different file is loading', (
    tester,
  ) async {
    final nextTags = Completer<rust_metadata.TagReadResult?>();
    Future<rust_metadata.TagReadResult?> readTags(String path) {
      return path == _song.filePath
          ? Future.value(const rust_metadata.TagReadResult(comment: 'Old note'))
          : nextTags.future;
    }

    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _song, readTags: readTags)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old note'), findsOneWidget);

    await tester.pumpWidget(
      _host(SongFileTagExtras(song: _otherSong, readTags: readTags)),
    );
    expect(find.text('Old note'), findsNothing);
    expect(find.text('Comment'), findsNothing);

    nextTags.complete(const rust_metadata.TagReadResult(comment: 'New note'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <String, Song>{
    'CUE': _song.copyWith(startOffsetMs: 0),
    'external': _song.copyWith(isExternal: true),
    'network': _song.copyWith(sourceType: 'smb'),
  }.entries) {
    testWidgets('reevaluates ${entry.key} eligibility at the same path', (
      tester,
    ) async {
      var reads = 0;
      Future<rust_metadata.TagReadResult?> readTags(String path) async {
        reads++;
        return const rust_metadata.TagReadResult(comment: 'Local note');
      }

      await tester.pumpWidget(
        _host(SongFileTagExtras(song: _song, readTags: readTags)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local note'), findsOneWidget);

      await tester.pumpWidget(
        _host(SongFileTagExtras(song: entry.value, readTags: readTags)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local note'), findsNothing);
      expect(reads, 1);

      await tester.pumpWidget(
        _host(SongFileTagExtras(song: _song, readTags: readTags)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local note'), findsOneWidget);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reads SAF content URIs instead of skipping them', (
    tester,
  ) async {
    const safSong = Song(
      id: 'tag-song-saf',
      title: 'SAF Note',
      artist: 'Test Artist',
      duration: Duration(minutes: 2),
      fileType: 'OPUS',
      filePath:
          'content://com.android.providers.media.documents/document/'
          'audio%3A42',
    );
    final seenPaths = <String>[];
    await tester.pumpWidget(
      _host(
        SongFileTagExtras(
          song: safSong,
          readTags: (path) async {
            seenPaths.add(path);
            return const rust_metadata.TagReadResult(
              comment: 'SAF reference note',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seenPaths, [safSong.filePath]);
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('SAF reference note'), findsOneWidget);
  });

  testWidgets('skips CUE, external, network, and pathless songs', (
    tester,
  ) async {
    var reads = 0;
    Future<rust_metadata.TagReadResult?> readTags(String path) async {
      reads++;
      return const rust_metadata.TagReadResult(comment: 'Should not show');
    }

    final ineligible = <Song>[
      _song.copyWith(startOffsetMs: 0),
      _song.copyWith(isExternal: true),
      _song.copyWith(sourceType: 'smb'),
      _song.copyWith(filePath: ''),
      const Song(
        id: 'tag-song-no-path',
        title: 'No Path',
        artist: 'Test Artist',
        duration: Duration(minutes: 1),
        fileType: 'OPUS',
      ),
    ];
    for (final song in ineligible) {
      await tester.pumpWidget(
        _host(SongFileTagExtras(song: song, readTags: readTags)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comment'), findsNothing, reason: song.id);
      await tester.pumpWidget(_host(const SizedBox.shrink()));
    }
    expect(reads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides unreadable tags without surfacing an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SongFileTagExtras(
          song: _song,
          readTags: (path) async => throw StateError('unreadable file'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in kSupportedLocales) {
    testWidgets('localizes the label but not the comment in $locale', (
      tester,
    ) async {
      const comment = 'Original note\n日本語 y español';
      await tester.pumpWidget(
        _host(
          SongFileTagExtras(
            song: _song,
            readTags: (_) async =>
                const rust_metadata.TagReadResult(comment: comment),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      final copy = lookupFlickLocalizations(
        locale == kFilipinoLocale ? kFallbackLocale : locale,
      );
      expect(find.text(copy.comment), findsOneWidget);
      expect(find.text(comment), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(360, 640), Size(640, 320)]) {
    testWidgets('long comments scroll without truncation at 2x text in $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final comment = List.generate(
        25,
        (index) => 'Reference note $index: Original text with Unicode 日本語.',
      ).join('\n\n');
      await tester.pumpWidget(
        _host(
          SongFileTagExtras(
            song: _song,
            readTags: (_) async =>
                rust_metadata.TagReadResult(comment: comment),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();

      final commentFinder = find.text(comment);
      final text = tester.widget<Text>(commentFinder);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getSize(commentFinder).height, greaterThan(size.height));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(scroll.position.extentAfter, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<rust_metadata.TagReadResult?> _blankAndLabelTags(String path) async {
  return const rust_metadata.TagReadResult(
    comment: '   ',
    date: '2024',
    copyright: '  ',
    label: 'Example Records',
  );
}
