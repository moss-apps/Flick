import 'package:isar_community/isar.dart';

part 'song_entity.g.dart';

/// Database entity for storing song metadata.
@collection
class SongEntity {
  Id id = Isar.autoIncrement;

  /// File path or content URI for the song
  @Index(composite: [CompositeIndex('startOffsetMs')], unique: true)
  late String filePath;

  /// MediaStore content URI used for Android metadata refreshes.
  @Index()
  String? mediaStoreUri;

  /// Start offset in milliseconds (for CUE sheet tracks)
  int? startOffsetMs;

  /// End offset in milliseconds (for CUE sheet tracks)
  int? endOffsetMs;

  /// Title of the song
  @Index()
  late String title;

  /// Artist name
  late String artist;

  /// Album name
  String? album;

  /// Album artist
  String? albumArtist;

  /// Duration in milliseconds
  int? durationMs;

  /// Track number
  int? trackNumber;

  /// Disc number
  int? discNumber;

  /// Year of release
  int? year;

  /// Genre
  String? genre;

  /// File size in bytes
  int? fileSize;

  /// File type (e.g., mp3, flac, wav)
  String? fileType;

  /// Bitrate in kbps
  int? bitrate;

  /// Sample rate in Hz
  int? sampleRate;

  /// Number of audio channels
  int? channels;

  /// Bit depth
  int? bitDepth;

  /// Ripper name from log file
  String? ripper;

  /// Read mode from log file
  String? readMode;

  /// AccurateRip verified status
  bool? accurateRip;

  /// Test CRC from log file
  String? testCrc;

  /// Copy CRC from log file
  String? copyCrc;

  /// Path to album art (if extracted)
  String? albumArtPath;

  /// URI of the folder containing this song
  @Index()
  String? folderUri;

  /// Date the song was added to the library
  @Index()
  late DateTime dateAdded;

  /// Last time metadata was updated
  @Index()
  DateTime? lastModified;

  /// Whether all metadata fields (sampleRate, bitDepth, discNumber) have been
  /// extracted. false means background extraction is still pending.
  @Index()
  bool metadataComplete = false;

  /// Whether the user has edited metadata locally (title, artist, album, etc.).
  /// When true, text metadata fields are preserved during library rescans instead
  /// of being overwritten by file tags.
  @Index()
  bool hasLocalEdits = false;
}
