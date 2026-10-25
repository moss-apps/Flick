// Technical checks do not certify the Tagalog wording or Baybayin spelling.
// Human approval is recorded separately in the review sheet and ARB metadata.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/l10n/l10n.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name.arb').readAsStringSync())
        as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final entry in arb.entries)
    if (!entry.key.startsWith('@')) entry.key: entry.value as String,
};

/// Read arguments recursively without treating ICU branch text such as
/// `other{kanta}` as an argument named kanta. gen-l10n validates the grammar.
Set<String> _placeholders(String message) {
  final names = <String>{};
  int closingBrace(String text, int open) {
    var depth = 0;
    for (var i = open; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}' && --depth == 0) return i;
    }
    throw FormatException('Unclosed ICU argument', text, open);
  }

  void scan(String text) {
    var cursor = 0;
    while (cursor < text.length) {
      final open = text.indexOf('{', cursor);
      if (open < 0) break;
      final close = closingBrace(text, open);
      final argument = text.substring(open + 1, close);
      final comma = argument.indexOf(',');
      names.add((comma < 0 ? argument : argument.substring(0, comma)).trim());
      if (comma >= 0) {
        final remaining = argument.substring(comma + 1);
        final typeEnd = remaining.indexOf(',');
        final type = (typeEnd < 0 ? remaining : remaining.substring(0, typeEnd))
            .trim();
        if (['plural', 'select', 'selectordinal'].contains(type)) {
          final branches = remaining.substring(typeEnd + 1);
          var branchCursor = 0;
          while (branchCursor < branches.length) {
            final branchOpen = branches.indexOf('{', branchCursor);
            if (branchOpen < 0) break;
            final branchClose = closingBrace(branches, branchOpen);
            scan(branches.substring(branchOpen + 1, branchClose));
            branchCursor = branchClose + 1;
          }
        }
      }
      cursor = close + 1;
    }
  }

  scan(message);
  return names;
}

/// Actual nonzero cmap format-4 glyph mappings, not just segment ranges (which
/// can contain holes). All Tagalog characters are in the BMP. No font-tool dep.
Set<int> _fontCodepoints(ByteData data) {
  int u16(int offset) => data.getUint16(offset);
  int u32(int offset) => data.getUint32(offset);
  for (var table = 0; table < u16(4); table++) {
    final record = 12 + table * 16;
    if (u32(record) != 0x636d6170) continue; // cmap
    final cmap = u32(record + 8);
    final result = <int>{};
    for (var subtable = 0; subtable < u16(cmap + 2); subtable++) {
      final offset = cmap + u32(cmap + 4 + subtable * 8 + 4);
      if (u16(offset) != 4) continue;
      final segments = u16(offset + 6) ~/ 2;
      final ends = offset + 14;
      final starts = ends + segments * 2 + 2;
      final deltas = starts + segments * 2;
      final ranges = deltas + segments * 2;
      for (var segment = 0; segment < segments; segment++) {
        final start = u16(starts + segment * 2);
        final end = u16(ends + segment * 2);
        final delta = data.getInt16(deltas + segment * 2);
        final rangeAddress = ranges + segment * 2;
        final range = u16(rangeAddress);
        for (var char = start; char <= end && char < 0xffff; char++) {
          var glyph = range == 0
              ? char
              : u16(rangeAddress + range + (char - start) * 2);
          if (range == 0 || glyph != 0) glyph = (glyph + delta) & 0xffff;
          if (glyph != 0) result.add(char);
        }
      }
    }
    return result;
  }
  throw StateError('Bundled font has no cmap table');
}

void main() {
  final en = _messages(_arb('app_en'));
  final filipino = _messages(_arb('app_tl'));
  final arb = _arb('app_tl_Tglg');
  final pilot = _messages(arb);

  test('Filipino covers the template and stays in Latin script', () {
    expect(filipino.keys.toSet(), en.keys.toSet());
    for (final entry in filipino.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(
        RegExp(r'[\u1700-\u1736]').hasMatch(entry.value),
        isFalse,
        reason: entry.key,
      );
      expect(
        _placeholders(entry.value),
        _placeholders(en[entry.key]!),
        reason: entry.key,
      );
    }
  });

  test('ICU argument checks distinguish branches from nested placeholders', () {
    expect(_placeholders('{count, plural, =1{kanta} other{kanta}}'), {'count'});
    expect(
      _placeholders('{count, plural, =1{{artist}} other{{count} • {artist}}}'),
      {'count', 'artist'},
    );
  });

  test(
    'only curated script drafts exist and have matching Latin review context',
    () {
      expect(arb['@@locale'], 'tl_Tglg');
      expect(pilot.keys.toSet(), {
        'songs14',
        'artists',
        'albums',
        'playlists',
        'favorites',
        'folders',
        'queue',
        'settings',
        'libraryLabel',
        'replayShortcutLabel',
        'nowPlaying',
        'playingLabel',
      });
      expect(pilot.keys.toSet().difference(en.keys.toSet()), isEmpty);
      final review = File('docs/BAYBAYIN_REVIEW.md').readAsStringSync();
      for (final entry in pilot.entries) {
        final metadata = arb['@${entry.key}'] as Map<String, dynamic>;
        expect(metadata['description'], isNotEmpty, reason: entry.key);
        expect(metadata['x-latin'], isNotEmpty, reason: entry.key);
        expect(
          metadata['x-latin'],
          entry.key == 'folders' ? 'Mga polder' : filipino[entry.key],
          reason: entry.key,
        );
        expect(
          metadata['x-review-status'],
          isIn(['draft', 'needs-change', 'approved']),
        );
        expect(
          review,
          contains(
            '| `${entry.key}` | ${en[entry.key]} | ${metadata['description']} '
            '| ${metadata['x-latin']} | ${entry.value} | ${metadata['x-review-status']} |',
          ),
          reason: 'Keep the review row in sync with ${entry.key}.',
        );
      }
    },
  );

  test('heading resources preserve every source placeholder', () {
    for (final entry in pilot.entries) {
      final latin =
          (arb['@${entry.key}'] as Map<String, dynamic>)['x-latin'] as String;
      expect(
        _placeholders(entry.value),
        _placeholders(en[entry.key]!),
        reason: entry.key,
      );
      expect(
        _placeholders(latin),
        _placeholders(en[entry.key]!),
        reason: entry.key,
      );
    }
  });

  test(
    'reviewer wording stays Filipino even when a script tag is requested',
    () {
      final strings = lookupFlickLocalizations(kBaybayinLocale);
      expect(strings.songs14, 'Mga kanta');
      expect(strings.artists, 'Mga kumanta');
      expect(strings.artist, 'Kumanta');
      expect(strings.playlists, 'Mga talaan ng kanta');
      expect(strings.playlist2, 'Talaan ng kanta');
      expect(strings.nextSong, 'Susunod na kanta');
      expect(strings.previousSong, 'Nakaraang kanta');
      expect(strings.previousSong2, strings.previousSong);
      expect(strings.lyrics, 'Lirika');
      expect(strings.allSongs, 'Lahat ng kanta');
      expect(strings.noSongsFound, 'Walang nahanap na kanta');
      // The correction is for Next song, not onboarding's separate Next label.
      expect(strings.next, 'Susunod');
    },
  );

  test('Filipino plurals and arguments survive generation', () {
    final strings = lookupFlickLocalizations(kFilipinoLocale);
    for (final count in [0, 1, 2, 101]) {
      expect(strings.songsCount(count), '$count kanta');
      expect(strings.tracks(count), '$count kanta');
      expect(strings.songUnit(count), 'kanta');
    }
    expect(strings.songs('3:25', 7), '3:25 • 7 kanta');
    expect(strings.repeat('MODE'), 'Ulit: MODE');
    expect(strings.shuffle2('MODE'), 'Paghalo: MODE');
    expect(
      strings.baybayinPilotDescription,
      filipino['baybayinPilotDescription'],
    );
    expect(strings.flickReplay, en['flickReplay']);
    expect(strings.unknownArtist, 'Hindi kilalang kumanta');
  });

  test(
    'native review copy is context-specific, not a global English switch',
    () {
      final strings = lookupFlickLocalizations(kFilipinoLocale);
      expect(
        strings.tracksLikedSongsPlaylists(902, 18, 1),
        '902 na kanta\n18 mga paborito mo\n1 playlist',
      );
      expect(
        strings.tracksLikedSongsPlaylists(0, 0, 0),
        '0 na kanta\n0 mga paborito mo\n0 playlist',
      );
      expect(strings.updateAvailable, 'Yun oh! May bagong update na naman!');
      expect(strings.playingLabel, 'Tumutugtog');
      expect(strings.nowPlaying, 'Kasalukuyang tumutugtog');
      expect(
        strings.filipinoDonationNote,
        'Donations will help me a lot! Hehehe. Sana masarap ulam mo lagi!',
      );
      expect(
        strings.configureYourMusicExperience,
        'Dito mo ayusin mga configuration ng settings mo.',
      );
      expect(strings.addedToFavorites, 'Goods, na sa favorites mo na.');
      expect(strings.removedFromFavorites3, 'Okay, naalis na po.');
      expect(
        strings.englishForFilipino.chooseAudioEngine,
        en['chooseAudioEngine'],
      );
      expect(strings.englishForFilipino.settings, en['settings']);
      expect(strings.englishForFilipino.soloDeveloper, en['soloDeveloper']);
      expect(strings.search, filipino['search']);
      final englishCopy = strings.englishForFilipino;
      expect(
        englishCopy.theAudioEngineDeterminesHowYour,
        en['theAudioEngineDeterminesHowYour'],
      );
      expect(
        englishCopy.defaultAndroidPlayerPlaysEverything,
        en['defaultAndroidPlayerPlaysEverything'],
      );
      expect(
        englishCopy.ourRustPoweredEngineCleanerSound,
        en['ourRustPoweredEngineCleanerSound'],
      );
      expect(
        englishCopy.studioGradeOutputForExternalDacs,
        en['studioGradeOutputForExternalDacs'],
      );
      expect(strings.isFilipino, isTrue);
      for (final locale in kSupportedLocales.where(
        (l) => l != kFilipinoLocale,
      )) {
        final other = lookupFlickLocalizations(locale);
        expect(other.isFilipino, isFalse);
        expect(identical(other.englishForFilipino, other), isTrue);
      }
    },
  );

  test(
    'the bundled fallback covers the script and its combining/final marks',
    () {
      final bytes = File(
        'assets/fonts/NotoSansTagalog-Regular.ttf',
      ).readAsBytesSync();
      final supported = _fontCodepoints(ByteData.sublistView(bytes));
      final required = <int>{
        // Complete modern Tagalog alphabet, not just this pilot's current glyphs.
        for (var char = 0x1700; char <= 0x1715; char++) char,
        0x171f, // archaic ra
        0x1735, 0x1736, // Philippine punctuation
        for (final message in pilot.values)
          ...message.runes.where((char) => char >= 0x1700 && char <= 0x1736),
      };
      expect(required.difference(supported), isEmpty);
      expect(AppTheme.fontFamilyFallback, contains('NotoSansTagalog'));
      expect(
        AppTheme.darkTheme.textTheme.bodyMedium!.fontFamilyFallback,
        contains('NotoSansTagalog'),
      );
      expect(
        File('assets/fonts/NotoSansTagalog-OFL.txt').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE Version 1.1'),
      );
    },
  );
}
