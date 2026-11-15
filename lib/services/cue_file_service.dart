/// Parsed CUE sheet track.
class CueTrack {
  final int trackNumber;
  final String title;
  final String performer;
  final int startOffsetMs;
  final int? endOffsetMs;

  const CueTrack({
    required this.trackNumber,
    required this.title,
    required this.performer,
    required this.startOffsetMs,
    this.endOffsetMs,
  });

  /// The final track ends at EOF, not one whole album after its start.
  int durationMs({int? sourceDurationMs}) {
    final end = endOffsetMs ?? sourceDurationMs;
    if (end == null || end <= startOffsetMs) return 0;
    return end - startOffsetMs;
  }
}

/// Parsed CUE sheet.
///
/// A sheet with multiple `FILE` blocks yields one [CueSheet] per block:
/// [audioFile] is that block's file and [tracks] holds only its tracks.
class CueSheet {
  final String? performer;
  final String? title;
  final String? date;
  final String? genre;
  final String audioFile;
  final List<CueTrack> tracks;

  const CueSheet({
    this.performer,
    this.title,
    this.date,
    this.genre,
    required this.audioFile,
    required this.tracks,
  });
}

/// Service for parsing CUE sheet files.
class CueFileService {
  static final RegExp _filePattern = RegExp(
    r'^FILE\s+"([^"]+)"\s+(WAVE|MP3|AIFF|BINARY|MOTOROLA)',
    caseSensitive: false,
  );
  static final RegExp _trackPattern = RegExp(
    r'^TRACK\s+(\d+)\s+AUDIO',
    caseSensitive: false,
  );
  static final RegExp _indexPattern = RegExp(
    r'^INDEX\s+(\d+)\s+(\d+):(\d+):(\d+)',
    caseSensitive: false,
  );
  static final RegExp _titlePattern = RegExp(
    r'^TITLE\s+"([^"]*)"',
    caseSensitive: false,
  );
  static final RegExp _performerPattern = RegExp(
    r'^PERFORMER\s+"([^"]*)"',
    caseSensitive: false,
  );
  static final RegExp _remDatePattern = RegExp(
    r'^REM\s+DATE\s+(\d+)',
    caseSensitive: false,
  );
  static final RegExp _remGenrePattern = RegExp(
    r'^REM\s+GENRE\s+"([^"]*)"',
    caseSensitive: false,
  );
  static final RegExp _remGenreBarePattern = RegExp(
    r'^REM\s+GENRE\s+(\S+)',
    caseSensitive: false,
  );

  /// Parse every `FILE` block in [content].
  ///
  /// Tracks and end offsets stay inside their own block. Collapsing them onto
  /// the last file would give every track the same `(filePath, startOffsetMs)`
  /// key for one-track-per-file rips and violate the song unique index.
  List<CueSheet> parseCueSheets(String content, {required String cueFilePath}) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .split('\n');

    String? globalPerformer;
    String? globalTitle;
    String? globalDate;
    String? globalGenre;
    _CueFileBlock? currentFile;

    final sheets = <CueSheet>[];
    String? currentTrackTitle;
    String? currentTrackPerformer;
    int? currentTrackNumber;
    int? currentTrackIndexMs;

    void finishTrack() {
      final block = currentFile;
      final trackNumber = currentTrackNumber;
      final startOffsetMs = currentTrackIndexMs;
      if (block != null && trackNumber != null && startOffsetMs != null) {
        block.tracks.add(
          CueTrack(
            trackNumber: trackNumber,
            title: currentTrackTitle ?? 'Track $trackNumber',
            performer: currentTrackPerformer ?? globalPerformer ?? '',
            startOffsetMs: startOffsetMs,
            endOffsetMs: null,
          ),
        );
      }
      currentTrackNumber = null;
      currentTrackTitle = null;
      currentTrackPerformer = null;
      currentTrackIndexMs = null;
    }

    void finishFile() {
      finishTrack();
      final block = currentFile;
      if (block != null && block.tracks.isNotEmpty) {
        sheets.add(
          CueSheet(
            performer: globalPerformer,
            title: globalTitle,
            date: globalDate,
            genre: globalGenre,
            audioFile: block.audioFile,
            tracks: _withEndOffsets(block.tracks),
          ),
        );
      }
      currentFile = null;
    }

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith(';')) continue;

      final fileMatch = _filePattern.firstMatch(line);
      if (fileMatch != null) {
        finishFile();
        currentFile = _CueFileBlock(fileMatch.group(1)!);
        continue;
      }

      final dateMatch = _remDatePattern.firstMatch(line);
      if (dateMatch != null) {
        globalDate = dateMatch.group(1);
        continue;
      }

      final genreMatch = _remGenrePattern.firstMatch(line);
      if (genreMatch != null) {
        globalGenre = genreMatch.group(1);
        continue;
      }

      final genreBareMatch = _remGenreBarePattern.firstMatch(line);
      if (genreBareMatch != null) {
        globalGenre = genreBareMatch.group(1);
        continue;
      }

      final titleMatch = _titlePattern.firstMatch(line);
      if (titleMatch != null) {
        if (currentTrackNumber != null) {
          currentTrackTitle = titleMatch.group(1);
        } else {
          globalTitle = titleMatch.group(1);
        }
        continue;
      }

      final performerMatch = _performerPattern.firstMatch(line);
      if (performerMatch != null) {
        if (currentTrackNumber != null) {
          currentTrackPerformer = performerMatch.group(1);
        } else {
          globalPerformer = performerMatch.group(1);
        }
        continue;
      }

      final trackMatch = _trackPattern.firstMatch(line);
      if (trackMatch != null) {
        finishTrack();
        currentTrackNumber = int.tryParse(trackMatch.group(1) ?? '');
        continue;
      }

      final indexMatch = _indexPattern.firstMatch(line);
      if (indexMatch != null) {
        final minutes = int.tryParse(indexMatch.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(indexMatch.group(3) ?? '0') ?? 0;
        final frames = int.tryParse(indexMatch.group(4) ?? '0') ?? 0;
        final ms = (minutes * 60 + seconds) * 1000 + (frames * 1000 ~/ 75);
        if (currentTrackNumber != null) {
          final indexNum = int.tryParse(indexMatch.group(1) ?? '0') ?? 0;
          if (indexNum == 1) {
            currentTrackIndexMs = ms;
          }
        }
        continue;
      }
    }

    finishFile();
    return sheets;
  }

  /// Parse the first `FILE` block.
  ///
  /// Kept for callers that only need the common single-image sheet; use
  /// [parseCueSheets] when the sheet may reference more than one audio file.
  CueSheet? parseCueSheet(String content, {required String cueFilePath}) {
    final sheets = parseCueSheets(content, cueFilePath: cueFilePath);
    return sheets.isEmpty ? null : sheets.first;
  }

  List<CueTrack> _withEndOffsets(List<CueTrack> tracks) {
    return [
      for (var i = 0; i < tracks.length; i++)
        CueTrack(
          trackNumber: tracks[i].trackNumber,
          title: tracks[i].title,
          performer: tracks[i].performer,
          startOffsetMs: tracks[i].startOffsetMs,
          endOffsetMs: i + 1 < tracks.length
              ? tracks[i + 1].startOffsetMs
              : null,
        ),
    ];
  }

  /// Resolve the audio file path relative to the CUE file.
  ///
  /// Relative paths (including subdirectories) are joined to the CUE's
  /// directory. Backslashes are normalized to `/` because Android paths use
  /// them even when the sheet was authored on Windows.
  String resolveAudioFilePath(String cueFilePath, String audioFile) {
    final normalizedAudio = audioFile.replaceAll('\\', '/');
    if (normalizedAudio.startsWith('/')) return normalizedAudio;
    final normalizedCue = cueFilePath.replaceAll('\\', '/');
    final lastSep = normalizedCue.lastIndexOf('/');
    if (lastSep == -1) return normalizedAudio;
    return '${normalizedCue.substring(0, lastSep + 1)}$normalizedAudio';
  }
}

class _CueFileBlock {
  final String audioFile;
  final List<CueTrack> tracks = [];

  _CueFileBlock(this.audioFile);
}
