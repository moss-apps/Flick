import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('enhanced LRC word parsing', () {
    final service = LyricsService();

    test('extracts word timings and keeps plain text intact', () {
      final lyrics = service.parseLyricsText(
        '[00:10.00]<00:10.00>Hello <00:10.50>wide <00:11.00>world\n',
      );

      expect(lyrics.isSynchronized, isTrue);
      expect(lyrics.lines, hasLength(1));
      final line = lyrics.lines.single;
      expect(line.text, 'Hello wide world');
      expect(line.words, isNotNull);
      expect(line.words!, hasLength(3));
      expect(line.words![0].start, const Duration(seconds: 10));
      expect(line.words![1].start, const Duration(milliseconds: 10500));
      expect(line.words![2].start, const Duration(seconds: 11));
    });

    test('plain synced LRC leaves words null', () {
      final lyrics = service.parseLyricsText('[01:02.03]Just a line\n');

      expect(lyrics.lines.single.words, isNull);
      expect(lyrics.lines.single.text, 'Just a line');
    });

    test('applies offset tag to word timestamps', () {
      final lyrics = service.parseLyricsText(
        '[offset:1000]\n[00:10.00]<00:10.00>Alpha <00:12.00>Beta',
      );

      final words = lyrics.lines.single.words!;
      expect(words.first.start, const Duration(seconds: 11));
    });
  });

  group('resolveWords', () {
    final service = LyricsService();

    LyricsData synced(String raw) => service.parseLyricsText(raw);

    test('chains real word ends to next word start', () {
      final lyrics = synced(
        '[00:10.00]<00:10.00>One <00:11.00>two <00:13.00>three',
      );
      final words = service.resolveWords(lyrics, 0);

      expect(words[0].end, const Duration(seconds: 11));
      expect(words[1].end, const Duration(seconds: 13));
      // Last word rests trimmed: 13s + 85% of the remaining 2s tail.
      expect(words[2].end, const Duration(milliseconds: 14700));
    });

    test('plain synced lines get one whole-line window', () {
      final lyrics = synced('[00:10.00]Short big\n[00:14.00]Next');
      final words = service.resolveWords(lyrics, 0);

      expect(words, hasLength(1));
      expect(words.single.start, const Duration(seconds: 10));
      // 85% of the 4s window, so the sweep rests before the next line.
      expect(words.single.end, const Duration(milliseconds: 13400));
      expect(words.single.text, 'Short big');
    });

    test('sweep finishes before the next line starts', () {
      final lyrics = synced('[00:10.00]A few words here\n[00:14.00]Next');
      final words = service.resolveWords(lyrics, 0);

      expect(words.last.end, lessThan(const Duration(seconds: 14)));
    });

    test('caps whole-line windows on long instrumental gaps', () {
      final lyrics = synced('[00:10.00]Solo line\n[01:00.00]Later');
      final words = service.resolveWords(lyrics, 0);

      expect(words.single.end, const Duration(seconds: 16));
    });

    test('fillForWord clamps outside its window', () {
      const word = LyricsWord(
        start: Duration(seconds: 10),
        end: Duration(seconds: 12),
        text: 'hi',
      );

      expect(LyricsService.fillForWord(word, const Duration(seconds: 9)), 0.0);
      expect(
        LyricsService.fillForWord(word, const Duration(seconds: 11)),
        closeTo(0.5, 0.001),
      );
      expect(
        LyricsService.fillForWord(word, const Duration(minutes: 1)),
        1.0,
      );
    });
  });

  group('buildLrcContent round-trip', () {
    test('re-emits enhanced word tags for word-timed lines', () {
      final service = LyricsService();
      final content = service.buildLrcContent(
        lines: [
          const LyricsLine(
            timestamp: Duration(seconds: 10),
            text: 'Hello world',
            words: [
              LyricsWord(
                start: Duration(seconds: 10),
                end: Duration(seconds: 10, milliseconds: 500),
                text: 'Hello ',
              ),
              LyricsWord(
                start: Duration(seconds: 10, milliseconds: 500),
                end: Duration(seconds: 11),
                text: 'world',
              ),
            ],
          ),
        ],
      );

      expect(content, contains('<00:10.00>Hello <00:10.50>world'));

      final reparsed = service.parseLyricsText(content);
      expect(reparsed.lines.single.words, isNotNull);
      expect(reparsed.lines.single.words!, hasLength(2));
      expect(reparsed.lines.single.text, 'Hello world');
    });
  });

  group('lyricsTextAlign preference', () {
    test('defaults to center and persists changes', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = AppPreferencesService();

      expect(await service.getLyricsTextAlign(), 'center');

      await service.setLyricsTextAlign('left');
      expect(await service.getLyricsTextAlign(), 'left');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lyrics_text_align'), 'left');
    });
  });
}
