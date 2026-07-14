import 'package:flick/data/repositories/song_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SongRepository.resolveGroupArtist', () {
    test('single artist stays as-is', () {
      expect(SongRepository.resolveGroupArtist({'Pink Floyd'}), 'Pink Floyd');
    });

    test('distinct albumArtists resolve to Various Artists (untagged comp)',
        () {
      expect(
        SongRepository.resolveGroupArtist({'A Tribe Called Quest', 'De La Soul'}),
        'Various Artists',
      );
    });

    test('Various Artists tag stays stable when mixed with poisoned values',
        () {
      expect(
        SongRepository.resolveGroupArtist(
          {'Various Artists', 'Kanye West', 'Jay‑Z'},
        ),
        'Various Artists',
      );
    });

    test('empty/blank values fall back to Unknown Artist', () {
      expect(SongRepository.resolveGroupArtist({''}), 'Unknown Artist');
      expect(SongRepository.resolveGroupArtist(<String>{}), 'Unknown Artist');
    });
  });
}
