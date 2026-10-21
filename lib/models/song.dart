import 'package:flick/l10n/l10n.dart';

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

  /// ReplayGain loudness gain for the track (dB).
  final double? replaygainTrackGain;

  /// ReplayGain track peak (linear).
  final double? replaygainTrackPeak;

  /// ReplayGain loudness gain for the whole album (dB).
  final double? replaygainAlbumGain;

  /// ReplayGain album peak (linear).
  final double? replaygainAlbumPeak;

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

  /// Directory path relative to the scanned root, recorded at scan time using
  /// on-disk display names ('Hindi/Album'; '' directly under the root). Null
  /// when not recorded; the path is then reconstructed from [folderUri] and
  /// [filePath].
  final String? relativeFolderPath;

  /// Date the song was added to the library
  final DateTime? dateAdded;

  /// True when the song came from an external app handoff.
  final bool isExternal;

  /// Package name of the app that handed this song to Flick.
  final String? sourcePackage;

  /// Where this song came from: null = local file, otherwise one of
  /// 'subsonic' | 'webdav' | 'jellyfin'.
  final String? sourceType;

  /// The server's song id (Subsonic song id, WebDAV file URL, Jellyfin Item.Id).
  final String? remoteId;

  /// [NetworkServerEntity.id] of the server this song was synced from.
  final int? remoteServerId;

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
    this.replaygainTrackGain,
    this.replaygainTrackPeak,
    this.replaygainAlbumGain,
    this.replaygainAlbumPeak,
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
    this.relativeFolderPath,
    this.dateAdded,
    this.isExternal = false,
    this.sourcePackage,
    this.sourceType,
    this.remoteId,
    this.remoteServerId,
  });

  bool get isFromLocker => sourcePackage == 'com.mossapps.locker';

  bool get isNetworkSource => sourceType != null;

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

  /// WavPack container (DSD or PCM payload). The Android system tier cannot
  /// open WavPack, so these files always need the Rust engine.
  bool get isWavPack {
    final ft = fileType.toUpperCase();
    if (ft == 'WV' || ft == 'WV-DSD' || ft == 'WAVPACK') return true;
    final ext = filePath?.split('.').last.toLowerCase() ?? '';
    return ext == _wavpackExtension;
  }

  /// Whether playback needs the Rust engine because the Android system
  /// decoder (just_audio/ExoPlayer) cannot decode this container.
  bool get requiresRustDecoder => isDsd || isWavPack;

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
    double? replaygainTrackGain,
    double? replaygainTrackPeak,
    double? replaygainAlbumGain,
    double? replaygainAlbumPeak,
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
    String? relativeFolderPath,
    DateTime? dateAdded,
    bool? isExternal,
    String? sourcePackage,
    String? sourceType,
    String? remoteId,
    int? remoteServerId,
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
      replaygainTrackGain: replaygainTrackGain ?? this.replaygainTrackGain,
      replaygainTrackPeak: replaygainTrackPeak ?? this.replaygainTrackPeak,
      replaygainAlbumGain: replaygainAlbumGain ?? this.replaygainAlbumGain,
      replaygainAlbumPeak: replaygainAlbumPeak ?? this.replaygainAlbumPeak,
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
      relativeFolderPath: relativeFolderPath ?? this.relativeFolderPath,
      dateAdded: dateAdded ?? this.dateAdded,
      isExternal: isExternal ?? this.isExternal,
      sourcePackage: sourcePackage ?? this.sourcePackage,
      sourceType: sourceType ?? this.sourceType,
      remoteId: remoteId ?? this.remoteId,
      remoteServerId: remoteServerId ?? this.remoteServerId,
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
    Song(
      id: '1',
      title: l10n.midnightDreams,
      artist: l10n.auroraSounds,
      duration: const Duration(minutes: 4, seconds: 32),
      fileType: 'FLAC',
      resolution: '24-bit/96kHz',
      album: l10n.nocturnal,
    ),
    Song(
      id: '2',
      title: l10n.electricSunset,
      artist: l10n.neonPulse,
      duration: const Duration(minutes: 3, seconds: 45),
      fileType: 'MP3',
      resolution: '320kbps',
      album: l10n.synthwaveCity,
    ),
    Song(
      id: '3',
      title: l10n.oceanWaves,
      artist: l10n.calmFrequencies,
      duration: Duration(minutes: 5, seconds: 18),
      fileType: 'FLAC',
      resolution: '16-bit/44.1kHz',
      album: l10n.natureAmbient,
    ),
    Song(
      id: '4',
      title: l10n.starlightSerenade,
      artist: l10n.cosmicOrchestra,
      duration: Duration(minutes: 6, seconds: 02),
      fileType: 'WAV',
      resolution: '32-bit/192kHz',
      album: l10n.spaceOdyssey,
    ),
    Song(
      id: '5',
      title: l10n.urbanEchoes,
      artist: l10n.cityBeats,
      duration: Duration(minutes: 3, seconds: 21),
      fileType: 'AAC',
      resolution: '256kbps',
      album: l10n.metropolitan,
    ),
    Song(
      id: '6',
      title: l10n.velvetNoir,
      artist: l10n.shadowJazz,
      duration: Duration(minutes: 4, seconds: 55),
      fileType: 'FLAC',
      resolution: '24-bit/48kHz',
      album: l10n.lateNightSessions,
    ),
    Song(
      id: '7',
      title: l10n.crystalCaverns,
      artist: l10n.etherealTones,
      duration: Duration(minutes: 7, seconds: 12),
      fileType: 'FLAC',
      resolution: '24-bit/96kHz',
      album: l10n.deepEarth,
    ),
    Song(
      id: '8',
      title: l10n.neonNights,
      artist: l10n.retroFuture,
      duration: Duration(minutes: 4, seconds: 08),
      fileType: 'MP3',
      resolution: '320kbps',
      album: '1984',
    ),
    Song(
      id: '9',
      title: l10n.whisperedSecrets,
      artist: l10n.asmrDreams,
      duration: Duration(minutes: 8, seconds: 45),
      fileType: 'WAV',
      resolution: '24-bit/48kHz',
      album: l10n.whisperWorld,
    ),
    Song(
      id: '10',
      title: l10n.thunderRoad,
      artist: l10n.stormChasers,
      duration: Duration(minutes: 5, seconds: 33),
      fileType: 'FLAC',
      resolution: '16-bit/44.1kHz',
      album: l10n.wildWeather,
    ),
  ];
}
