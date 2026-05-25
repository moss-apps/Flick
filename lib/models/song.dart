/// Song data model for Flick Player.
class Song {
  /// Unique identifier for the song
  final String id;

  /// Song title
  final String title;

  /// Artist name
  final String artist;

  /// Path or URL to album art (nullable if no art available)
  final String? albumArt;

  /// Duration of the song
  final Duration duration;

  /// File type/codec (e.g., "FLAC", "MP3", "WAV", "AAC")
  final String fileType;

  /// Audio resolution (e.g., "24-bit/96kHz", "16-bit/44.1kHz")
  final String? resolution;

  /// Structured sample rate in Hz when available.
  final int? sampleRate;

  /// Structured bit depth when available.
  final int? bitDepth;

  /// Start offset in milliseconds (for CUE sheet tracks)
  final int? startOffsetMs;

  /// End offset in milliseconds (for CUE sheet tracks)
  final int? endOffsetMs;

  /// Ripper name from log file
  final String? ripper;

  /// Read mode from log file
  final String? readMode;

  /// AccurateRip verified status
  final bool? accurateRip;

  /// Test CRC from log file
  final String? testCrc;

  /// Copy CRC from log file
  final String? copyCrc;

  /// Album name (optional)
  final String? album;

  /// Album artist (optional, used for compilations)
  final String? albumArtist;

  /// Track number within the album
  final int? trackNumber;

  /// Disc number within a multi-disc release
  final int? discNumber;

  /// Year of release
  final int? year;

  /// Genre
  final String? genre;

  /// File path on device
  final String? filePath;

  /// URI of the folder containing this song
  final String? folderUri;

  /// Date the song was added to the library
  final DateTime? dateAdded;

  /// True when the song came from an external app handoff.
  final bool isExternal;

  /// Package name of the app that handed this song to Flick.
  final String? sourcePackage;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.duration,
    required this.fileType,
    this.resolution,
    this.sampleRate,
    this.bitDepth,
    this.startOffsetMs,
    this.endOffsetMs,
    this.ripper,
    this.readMode,
    this.accurateRip,
    this.testCrc,
    this.copyCrc,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.filePath,
    this.folderUri,
    this.dateAdded,
    this.isExternal = false,
    this.sourcePackage,
  });

  bool get isFromLocker => sourcePackage == 'com.mossapps.locker';

  static const _dsdExtensions = {'dsf', 'dff'};
  static const _wavpackExtension = 'wv';

  bool get isDsd {
    if (sampleRate != null && sampleRate! >= 2822400) return true;
    final ext = filePath?.split('.').last.toLowerCase() ?? '';
    if (_dsdExtensions.contains(ext)) return true;
    if (ext == _wavpackExtension && (fileType.toUpperCase() == 'WV-DSD' || (sampleRate != null && sampleRate! >= 2822400))) return true;
    final ft = fileType.toUpperCase();
    return ft == 'DSF' || ft == 'DFF' || ft == 'DSD' || ft == 'WV-DSD';
  }

  String get dsdRateLabel {
    if (!isDsd) return '';
    final rate = sampleRate ?? 0;
    if (rate >= 22579200) return 'DSD512';
    if (rate >= 11289600) return 'DSD256';
    if (rate >= 5644800) return 'DSD128';
    if (rate >= 2822400) return 'DSD64';
    final ft = fileType.toUpperCase();
    if (ft == 'DSF' || ft == 'DFF' || ft == 'DSD') return 'DSD';
    return 'DSD';
  }

  static int? dsdToPcmRate(int? dsdRate) {
    if (dsdRate == null) return null;
    if (dsdRate >= 22579200) return 705600;
    if (dsdRate >= 11289600) return 352800;
    if (dsdRate >= 5644800) return 176400;
    if (dsdRate >= 2822400) return 88200;
    return null;
  }

  static int? dsdToDopRate(int? dsdRate) {
    if (dsdRate == null) return null;
    if (dsdRate >= 22579200) return 705600;
    if (dsdRate >= 11289600) return 705600;
    if (dsdRate >= 5644800) return 352800;
    if (dsdRate >= 2822400) return 176400;
    return null;
  }

  /// Format duration as mm:ss or hh:mm:ss
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with modified fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArt,
    Duration? duration,
    String? fileType,
    String? resolution,
    int? sampleRate,
    int? bitDepth,
    int? startOffsetMs,
    int? endOffsetMs,
    String? ripper,
    String? readMode,
    bool? accurateRip,
    String? testCrc,
    String? copyCrc,
    String? album,
    String? albumArtist,
    int? trackNumber,
    int? discNumber,
    int? year,
    String? genre,
    String? filePath,
    String? folderUri,
    DateTime? dateAdded,
    bool? isExternal,
    String? sourcePackage,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      fileType: fileType ?? this.fileType,
      resolution: resolution ?? this.resolution,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      startOffsetMs: startOffsetMs ?? this.startOffsetMs,
      endOffsetMs: endOffsetMs ?? this.endOffsetMs,
      ripper: ripper ?? this.ripper,
      readMode: readMode ?? this.readMode,
      accurateRip: accurateRip ?? this.accurateRip,
      testCrc: testCrc ?? this.testCrc,
      copyCrc: copyCrc ?? this.copyCrc,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      filePath: filePath ?? this.filePath,
      folderUri: folderUri ?? this.folderUri,
      dateAdded: dateAdded ?? this.dateAdded,
      isExternal: isExternal ?? this.isExternal,
      sourcePackage: sourcePackage ?? this.sourcePackage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist)';
  }

  /// Sample songs for UI development and testing
  static List<Song> get sampleSongs => [
    const Song(
      id: '1',
      title: 'Midnight Dreams',
      artist: 'Aurora Sounds',
      duration: Duration(minutes: 4, seconds: 32),
      fileType: 'FLAC',
      resolution: '24-bit/96kHz',
      album: 'Nocturnal',
    ),
    const Song(
      id: '2',
      title: 'Electric Sunset',
      artist: 'Neon Pulse',
      duration: Duration(minutes: 3, seconds: 45),
      fileType: 'MP3',
      resolution: '320kbps',
      album: 'Synthwave City',
    ),
    const Song(
      id: '3',
      title: 'Ocean Waves',
      artist: 'Calm Frequencies',
      duration: Duration(minutes: 5, seconds: 18),
      fileType: 'FLAC',
      resolution: '16-bit/44.1kHz',
      album: 'Nature Ambient',
    ),
    const Song(
      id: '4',
      title: 'Starlight Serenade',
      artist: 'Cosmic Orchestra',
      duration: Duration(minutes: 6, seconds: 02),
      fileType: 'WAV',
      resolution: '32-bit/192kHz',
      album: 'Space Odyssey',
    ),
    const Song(
      id: '5',
      title: 'Urban Echoes',
      artist: 'City Beats',
      duration: Duration(minutes: 3, seconds: 21),
      fileType: 'AAC',
      resolution: '256kbps',
      album: 'Metropolitan',
    ),
    const Song(
      id: '6',
      title: 'Velvet Noir',
      artist: 'Shadow Jazz',
      duration: Duration(minutes: 4, seconds: 55),
      fileType: 'FLAC',
      resolution: '24-bit/48kHz',
      album: 'Late Night Sessions',
    ),
    const Song(
      id: '7',
      title: 'Crystal Caverns',
      artist: 'Ethereal Tones',
      duration: Duration(minutes: 7, seconds: 12),
      fileType: 'FLAC',
      resolution: '24-bit/96kHz',
      album: 'Deep Earth',
    ),
    const Song(
      id: '8',
      title: 'Neon Nights',
      artist: 'Retro Future',
      duration: Duration(minutes: 4, seconds: 08),
      fileType: 'MP3',
      resolution: '320kbps',
      album: '1984',
    ),
    const Song(
      id: '9',
      title: 'Whispered Secrets',
      artist: 'ASMR Dreams',
      duration: Duration(minutes: 8, seconds: 45),
      fileType: 'WAV',
      resolution: '24-bit/48kHz',
      album: 'Whisper World',
    ),
    const Song(
      id: '10',
      title: 'Thunder Road',
      artist: 'Storm Chasers',
      duration: Duration(minutes: 5, seconds: 33),
      fileType: 'FLAC',
      resolution: '16-bit/44.1kHz',
      album: 'Wild Weather',
    ),
  ];
}
