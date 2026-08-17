import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/folders/screens/folders_screen.dart';
import 'package:flick/models/song.dart';

Song _song(String title, String filePath) => Song(
  id: title,
  title: title,
  artist: 'Artist',
  duration: const Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: filePath,
  folderUri: 'file:///storage/Music',
);

void main() {
  test('groupByImmediateFolder at nested prefix splits subfolders and songs', () {
    final allSongs = [
      _song('Root', 'file:///storage/Music/Root.flac'),
      _song('A1', 'file:///storage/Music/Album/A1.flac'),
      _song('CD1a', 'file:///storage/Music/Album/CD1/CD1a.flac'),
    ];

    final (:subfolders, :songs) = groupByImmediateFolder(
      allSongs: allSongs,
      folderUri: 'file:///storage/Music',
      prefix: 'Album',
    );

    expect(subfolders.single.key, 'Album/CD1');
    expect(subfolders.single.songs.map((s) => s.title), ['CD1a']);
    expect(songs.map((s) => s.title), ['A1']);
  });
}
