import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/song.dart';

/// A single lyric line, optionally timestamped for synchronized display.
class LyricsLine {
  final Duration timestamp;
  final String text;

  const LyricsLine({required this.timestamp, required this.text});
}

/// Parsed lyrics payload.
class LyricsData {
  final List<LyricsLine> lines;
  final bool isSynchronized;
  final String? source;
  final String rawContent;

  const LyricsData({
    required this.lines,
    required this.isSynchronized,
    this.source,
    required this.rawContent,
  });
}

class LyricsSaveResult {
  final LyricsData data;
  final String path;
  final bool savedBesideSong;

  const LyricsSaveResult({
    required this.data,
    required this.path,
    required this.savedBesideSong,
  });
}

class LyricsService {
  static const MethodChannel _storageChannel = MethodChannel(
    'com.mossapps.flick/storage',
  );
  static const String _manualLyricsOverridesKey = 'lyrics_manual_overrides_v1';
  static const String _managedLyricsDirectoryName = 'lyrics';

  final Map<String, LyricsData?> _cache = {};

  Future<LyricsData?> loadLyricsForSong(
    Song song, {
    bool forceRefresh = false,
  }) async {
    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) return null;

    if (forceRefresh) {
      _cache.remove(filePath);
    }

    if (!forceRefresh && _cache.containsKey(filePath)) {
      return _cache[filePath];
    }

    final manualPath = await getManualLyricsPathForSong(song);
    if (manualPath != null && manualPath.isNotEmpty) {
      final manualLoaded = await _loadLyricsFromAbsolutePath(manualPath);
      if (manualLoaded != null && manualLoaded.content.trim().isNotEmpty) {
        final parsed = _parseLyrics(manualLoaded.content, source: manualLoaded.source);
        _cache[filePath] = parsed;
        return parsed;
      }

      await clearManualLyricsPathForSong(song);
    }

    final embedded = await _loadEmbeddedLyricsText(filePath);
    if (embedded != null && embedded.content.trim().isNotEmpty) {
      final parsed = _parseLyrics(embedded.content, source: embedded.source);
      _cache[filePath] = parsed;
      return parsed;
    }

    final loaded = await _loadLyricsText(filePath);
    if (loaded == null || loaded.content.trim().isEmpty) {
      _cache[filePath] = null;
      return null;
    }

    final parsed = _parseLyrics(loaded.content, source: loaded.source);
    _cache[filePath] = parsed;
    return parsed;
  }

  Future<String?> getManualLyricsPathForSong(Song song) async {
    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_manualLyricsOverridesKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final value = decoded[filePath];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    } catch (_) {
      // Ignore malformed preference payload and fall back to auto lookup.
    }

    return null;
  }

  Future<void> clearManualLyricsPathForSong(Song song) async {
    await _setManualLyricsPath(song, null);
  }

  Future<LyricsSaveResult> importLyricsForSong({
    required Song song,
    required String fileName,
    required String content,
  }) async {
    final extension = _preferredLyricsExtension(fileName);
    final savedPath = await _writeManagedLyricsCopy(
      song: song,
      extension: extension,
      content: content,
    );
    await _setManualLyricsPath(song, savedPath);
    final data = (await loadLyricsForSong(song, forceRefresh: true)) ??
        _parseLyrics(content, source: savedPath);
    return LyricsSaveResult(
      data: data,
      path: savedPath,
      savedBesideSong: false,
    );
  }

  Future<LyricsSaveResult> saveLyricsForSong({
    required Song song,
    required String content,
  }) async {
    final sidecarPath = suggestSidecarLrcPath(song);
    var savedBesideSong = false;
    late final String savedPath;

    if (sidecarPath != null) {
      try {
        final file = File(sidecarPath);
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
        await _setManualLyricsPath(song, null);
        savedBesideSong = true;
        savedPath = file.path;
      } catch (_) {
        savedPath = await _writeManagedLyricsCopy(
          song: song,
          extension: 'lrc',
          content: content,
        );
        await _setManualLyricsPath(song, savedPath);
      }
    } else {
      savedPath = await _writeManagedLyricsCopy(
        song: song,
        extension: 'lrc',
        content: content,
      );
      await _setManualLyricsPath(song, savedPath);
    }

    final data = (await loadLyricsForSong(song, forceRefresh: true)) ??
        _parseLyrics(content, source: savedPath);
    return LyricsSaveResult(
      data: data,
      path: savedPath,
      savedBesideSong: savedBesideSong,
    );
  }

  int findCurrentLineIndex(LyricsData lyrics, Duration position) {
    if (!lyrics.isSynchronized || lyrics.lines.isEmpty) return -1;

    final targetMs = position.inMilliseconds;
    int left = 0;
    int right = lyrics.lines.length - 1;
    int result = -1;

    while (left <= right) {
      final mid = left + ((right - left) ~/ 2);
      final lineMs = lyrics.lines[mid].timestamp.inMilliseconds;
      if (lineMs <= targetMs) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
  }

  LyricsData parseLyricsText(String raw, {String? source}) {
    return _parseLyrics(raw, source: source);
  }

  Duration? parseTimestamp(String timestamp) {
    return _parseTimestamp(timestamp);
  }

  String formatTimestamp(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final centiseconds = (duration.inMilliseconds.remainder(1000) ~/ 10);
    return '[${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}]';
  }

  String buildLrcContent({
    required List<LyricsLine> lines,
    Song? song,
  }) {
    final buffer = StringBuffer();
    if (song?.title case final title? when title.trim().isNotEmpty) {
      buffer.writeln('[ti:${title.trim()}]');
    }
    if (song?.artist case final artist? when artist.trim().isNotEmpty) {
      buffer.writeln('[ar:${artist.trim()}]');
    }
    if (song?.album case final album? when album.trim().isNotEmpty) {
      buffer.writeln('[al:${album.trim()}]');
    }
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }

    for (final line in lines) {
      buffer.writeln('${formatTimestamp(line.timestamp)}${line.text}');
    }
    return buffer.toString().trimRight();
  }

  String? suggestSidecarLrcPath(Song song) {
    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) return null;
    final localPath = _resolveLocalPath(filePath);
    if (localPath == null || localPath.isEmpty) return null;

    final audioFile = File(localPath);
    final parent = audioFile.parent;
    final stem = _basenameWithoutExtension(audioFile.path);
    return '${parent.path}${Platform.pathSeparator}$stem.lrc';
  }

  Future<_LoadedLyrics?> _loadEmbeddedLyricsText(String filePath) async {
    try {
      final result = await _storageChannel.invokeMapMethod<String, dynamic>(
        'readEmbeddedLyrics',
        {'audioUri': filePath},
      );
      final content = result?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return _LoadedLyrics(
          content: content,
          source: result?['source'] as String? ?? 'embedded',
        );
      }
    } catch (_) {
      // Best-effort lookup. Fall back to sidecar lookup.
    }
    return null;
  }

  Future<_LoadedLyrics?> _loadLyricsFromAbsolutePath(String absolutePath) async {
    final file = File(absolutePath);
    if (!await file.exists()) return null;
    final content = await _readTextFile(file);
    if (content == null || content.trim().isEmpty) return null;
    return _LoadedLyrics(content: content, source: file.path);
  }

  Future<_LoadedLyrics?> _loadLyricsText(String filePath) async {
    final parsedUri = Uri.tryParse(filePath);
    final isAndroidContentUri =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        parsedUri?.scheme == 'content';

    if (isAndroidContentUri) {
      try {
        final result = await _storageChannel.invokeMapMethod<String, dynamic>(
          'readSiblingLyrics',
          {'audioUri': filePath},
        );
        final content = result?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return _LoadedLyrics(
            content: content,
            source: result?['name'] as String? ?? result?['uri'] as String?,
          );
        }
      } catch (_) {
        // Best-effort only. Fall back to local path resolution.
      }
    }

    final localPath = _resolveLocalPath(filePath);
    if (localPath == null || localPath.isEmpty) return null;

    final audioFile = File(localPath);
    final parent = audioFile.parent;
    final stem = _basenameWithoutExtension(audioFile.path);
    final sep = Platform.pathSeparator;

    final candidates = <String>[
      '${parent.path}$sep$stem.lrc',
      '${parent.path}$sep$stem.txt',
      '${parent.path}$sep$stem.xml',
      '${parent.path}$sep$stem.LRC',
      '${parent.path}$sep$stem.TXT',
      '${parent.path}$sep$stem.XML',
    ];

    for (final candidatePath in candidates) {
      final file = File(candidatePath);
      if (!await file.exists()) continue;

      final content = await _readTextFile(file);
      if (content != null && content.trim().isNotEmpty) {
        return _LoadedLyrics(content: content, source: file.path);
      }
    }

    return null;
  }

  String? _resolveLocalPath(String filePath) {
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(filePath)) {
      return filePath;
    }

    final parsed = Uri.tryParse(filePath);
    if (parsed != null && parsed.scheme == 'file') {
      return parsed.toFilePath();
    }

    if (parsed != null && parsed.scheme.isNotEmpty) {
      return null;
    }

    return filePath;
  }

  String _basenameWithoutExtension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final filename = normalized.split('/').last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }

  Future<String?> _readTextFile(File file) async {
    try {
      return await file.readAsString();
    } catch (_) {
      try {
        return await file.readAsString(encoding: latin1);
      } catch (_) {
        return null;
      }
    }
  }

  LyricsData _parseLyrics(String raw, {String? source}) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('<?xml') || trimmed.startsWith('<')) {
      final xmlData = _parseXmlLyrics(trimmed, source: source);
      if (xmlData != null) return xmlData;
    }

    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst(RegExp(r'^\uFEFF'), '');
    final rows = normalized.split('\n');

    final timestampPattern = RegExp(r'\[(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{1,3})?)\]');
    final wordTimestampPattern = RegExp(r'<(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{1,3})?)>');
    final offsetPattern = RegExp(
      r'^\s*\[offset:([+-]?\d+)\]\s*$',
      caseSensitive: false,
    );
    final metadataPattern = RegExp(r'^\s*\[[a-zA-Z]+:.*\]\s*$');

    var offsetMs = 0;
    var hasTimestamps = false;
    final parsedLines = <LyricsLine>[];

    for (final row in rows) {
      final line = row.trimRight();
      if (line.trim().isEmpty) continue;

      final offsetMatch = offsetPattern.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '') ?? offsetMs;
        continue;
      }

      final matches = timestampPattern.allMatches(line).toList();
      if (matches.isNotEmpty) {
        hasTimestamps = true;
        final lyricText = line
            .replaceAll(timestampPattern, '')
            .replaceAll(wordTimestampPattern, '')
            .trim();
        for (final match in matches) {
          final parsedTime = _parseTimestamp(match.group(1) ?? '');
          if (parsedTime == null) continue;

          final adjustedMs = parsedTime.inMilliseconds + offsetMs;
          final clamped = Duration(
            milliseconds: adjustedMs < 0 ? 0 : adjustedMs,
          );
          if (lyricText.isEmpty) continue;
          parsedLines.add(LyricsLine(timestamp: clamped, text: lyricText));
        }
        continue;
      }

      if (metadataPattern.hasMatch(line)) {
        continue;
      }

      parsedLines.add(LyricsLine(timestamp: Duration.zero, text: line.trim()));
    }

    if (hasTimestamps) {
      parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return LyricsData(
        lines: parsedLines,
        isSynchronized: true,
        source: source,
        rawContent: raw,
      );
    }

    return LyricsData(
      lines: parsedLines.where((line) => line.text.isNotEmpty).toList(),
      isSynchronized: false,
      source: source,
      rawContent: raw,
    );
  }

  LyricsData? _parseXmlLyrics(String xml, {String? source}) {
    try {
      final linePattern = RegExp(
        r'<line\s+start="(\d+)"\s*>([^<]*)</line>',
        caseSensitive: false,
      );
      final altPattern = RegExp(
        r'<line\s+start="(\d{1,2}):(\d{2})\.(\d{2})"\s*>([^<]*)</line>',
        caseSensitive: false,
      );

      final lines = <LyricsLine>[];
      var hasTimestamps = false;

      for (final match in linePattern.allMatches(xml)) {
        hasTimestamps = true;
        final ms = int.tryParse(match.group(1) ?? '') ?? 0;
        final text = match.group(2)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricsLine(timestamp: Duration(milliseconds: ms), text: text));
        }
      }

      if (lines.isEmpty) {
        for (final match in altPattern.allMatches(xml)) {
          hasTimestamps = true;
          final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
          final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
          final centis = int.tryParse(match.group(3) ?? '0') ?? 0;
          final ms = (minutes * 60 + seconds) * 1000 + centis * 10;
          final text = match.group(4)?.trim() ?? '';
          if (text.isNotEmpty) {
            lines.add(LyricsLine(timestamp: Duration(milliseconds: ms), text: text));
          }
        }
      }

      if (lines.isNotEmpty) {
        lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return LyricsData(
          lines: lines,
          isSynchronized: hasTimestamps,
          source: source,
          rawContent: xml,
        );
      }
    } catch (_) {
      // Fall through to plain-text parser
    }
    return null;
  }

  Duration? _parseTimestamp(String timestamp) {
    final trimmed = timestamp.trim();

    var match = RegExp(
      r'^(\d{1,2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
    ).firstMatch(trimmed);
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: _parseFraction(match.group(4)),
      );
    }

    match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    final minutes = int.tryParse(match.group(1) ?? '');
    final seconds = int.tryParse(match.group(2) ?? '');
    if (minutes == null || seconds == null) return null;

    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: _parseFraction(match.group(3)),
    );
  }

  int _parseFraction(String? fractionRaw) {
    if (fractionRaw == null || fractionRaw.isEmpty) return 0;
    if (fractionRaw.length == 1) return int.parse(fractionRaw) * 100;
    if (fractionRaw.length == 2) return int.parse(fractionRaw) * 10;
    return int.parse(fractionRaw.substring(0, 3));
  }

  Future<void> _setManualLyricsPath(Song song, String? manualPath) async {
    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_manualLyricsOverridesKey);
    final map = <String, String>{};
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String && entry.value is String) {
              map[entry.key as String] = entry.value as String;
            }
          }
        }
      } catch (_) {
        // Reset malformed preferences payload.
      }
    }

    if (manualPath == null || manualPath.isEmpty) {
      map.remove(filePath);
    } else {
      map[filePath] = manualPath;
    }

    if (map.isEmpty) {
      await prefs.remove(_manualLyricsOverridesKey);
    } else {
      await prefs.setString(_manualLyricsOverridesKey, jsonEncode(map));
    }
    _cache.remove(filePath);
  }

  Future<String> _writeManagedLyricsCopy({
    required Song song,
    required String extension,
    required String content,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final lyricsDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}$_managedLyricsDirectoryName',
    );
    await lyricsDirectory.create(recursive: true);

    final safeStem = _safeLyricsStem(song);
    final file = File(
      '${lyricsDirectory.path}${Platform.pathSeparator}$safeStem.$extension',
    );
    await file.writeAsString(content);
    return file.path;
  }

  String _preferredLyricsExtension(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.txt')) return 'txt';
    if (normalized.endsWith('.xml')) return 'xml';
    return 'lrc';
  }

  String _safeLyricsStem(Song song) {
    final parts = [
      if (song.artist.trim().isNotEmpty) song.artist.trim(),
      if (song.title.trim().isNotEmpty) song.title.trim(),
      song.id,
    ];
    final stem = parts.join('_');
    return stem.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
  }
}

class _LoadedLyrics {
  final String content;
  final String? source;

  const _LoadedLyrics({required this.content, this.source});
}
