import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;

class MetadataEditorService {
  MetadataEditorService._();
  static final MetadataEditorService instance = MetadataEditorService._();

  Future<rust_metadata.TagReadResult?> readTags(String filePath) async {
    try {
      return await rust_metadata.readTags(path: filePath);
    } catch (_) {
      return null;
    }
  }

  Future<bool> writeTags(Song song, rust_metadata.TagEditFields fields) async {
    if (song.filePath == null) return false;
    if (song.startOffsetMs != null) return false;
    if (song.isExternal) return false;

    try {
      await SongRepository().updateSongMetadata(
        song.filePath!,
        title: fields.title,
        artist: fields.artist,
        album: fields.album,
        albumArtist: fields.albumArtist,
        trackNumber: fields.trackNumber,
        discNumber: fields.discNumber,
        year: fields.year,
        genre: fields.genre,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}