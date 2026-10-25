import 'dart:io';

import 'package:flick/l10n/l10n.dart';
import 'package:flutter/services.dart';

import '../data/repositories/recently_played_repository.dart';

class CsvExportService {
  static const _channel = MethodChannel('com.mossapps.flick/storage');

  // Exported files are English regardless of UI language.
  String _periodLabel(ListeningRecap recap) =>
      recap.period.labelFor(lookupFlickLocalizations(kFallbackLocale));

  Future<String?> saveCsv(ListeningRecap recap) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('CSV export is currently supported on Android only.');
    }

    final content = _buildCsv(recap);
    final fileName = _buildFileName(recap, 'csv');
    final documentUri = await _channel.invokeMethod<String>(
      'createDocument',
      {'fileName': fileName, 'mimeType': 'text/csv'},
    );
    if (documentUri == null || documentUri.trim().isEmpty) return null;

    final success = await _channel.invokeMethod<bool>(
      'writeTextDocument',
      {'uri': documentUri, 'content': content},
    );
    if (success != true) {
      throw const FileSystemException('Failed to write CSV file');
    }

    return fileName;
  }

  Future<String?> saveTxt(ListeningRecap recap) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('TXT export is currently supported on Android only.');
    }

    final content = _buildTxt(recap);
    final fileName = _buildFileName(recap, 'txt');
    final documentUri = await _channel.invokeMethod<String>(
      'createDocument',
      {'fileName': fileName, 'mimeType': 'text/plain'},
    );
    if (documentUri == null || documentUri.trim().isEmpty) return null;

    final success = await _channel.invokeMethod<bool>(
      'writeTextDocument',
      {'uri': documentUri, 'content': content},
    );
    if (success != true) {
      throw const FileSystemException('Failed to write TXT file');
    }

    return fileName;
  }

  String _buildFileName(ListeningRecap recap, String extension) {
    final now = DateTime.now();
    final ts =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return 'flick_${_periodLabel(recap).toLowerCase()}_replay_$ts.$extension';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _buildCsv(ListeningRecap recap) {
    final buf = StringBuffer();

    buf.writeln('Flick Replay — ${_periodLabel(recap)} Recap');
    buf.writeln();
    buf.writeln('Period: ${_formatDateTime(recap.start)} → ${_formatDateTime(recap.endExclusive)}');
    buf.writeln('Total Plays: ${recap.totalPlays}');
    buf.writeln('Total Listening Time: ${_formatDuration(recap.totalListeningTime)}');
    buf.writeln('Unique Songs: ${recap.uniqueSongs}');
    buf.writeln('Unique Artists: ${recap.uniqueArtists}');
    buf.writeln('Active Days: ${recap.activeDays}');
    if (recap.peakHour != null) {
      buf.writeln('Peak Listening Hour: ${recap.peakHour}:00');
    }
    buf.writeln();

    buf.writeln('Top Songs');
    buf.writeln('Rank,Title,Artist,Album,Plays,Listening Time,Last Played');
    for (var i = 0; i < recap.topSongs.length; i++) {
      final s = recap.topSongs[i];
      buf.writeln(
        '${i + 1},'
        '${_csvEscape(s.song.title)},'
        '${_csvEscape(s.song.artist)},'
        '${_csvEscape(s.song.album ?? '')},'
        '${s.plays},'
        '${_formatDuration(s.listeningTime)},'
        '${_formatDateTime(s.lastPlayedAt)}',
      );
    }
    buf.writeln();

    buf.writeln('Top Artists');
    buf.writeln('Rank,Artist,Plays,Unique Songs,Listening Time,Last Played');
    for (var i = 0; i < recap.topArtists.length; i++) {
      final a = recap.topArtists[i];
      buf.writeln(
        '${i + 1},'
        '${_csvEscape(a.artist)},'
        '${a.plays},'
        '${a.uniqueSongs},'
        '${_formatDuration(a.listeningTime)},'
        '${_formatDateTime(a.lastPlayedAt)}',
      );
    }
    buf.writeln();

    buf.writeln('Top Albums');
    buf.writeln('Rank,Album,Artist,Plays,Unique Songs,Listening Time,Last Played');
    for (var i = 0; i < recap.topAlbums.length; i++) {
      final a = recap.topAlbums[i];
      buf.writeln(
        '${i + 1},'
        '${_csvEscape(a.album)},'
        '${_csvEscape(a.artist)},'
        '${a.plays},'
        '${a.uniqueSongs},'
        '${_formatDuration(a.listeningTime)},'
        '${_formatDateTime(a.lastPlayedAt)}',
      );
    }

    return buf.toString();
  }

  String _buildTxt(ListeningRecap recap) {
    final buf = StringBuffer();

    buf.writeln('=== FLICK REPLAY: ${_periodLabel(recap).toUpperCase()} RECAP ===');
    buf.writeln();
    buf.writeln('Period:       ${_formatDateTime(recap.start)} → ${_formatDateTime(recap.endExclusive)}');
    buf.writeln('Total Plays:  ${recap.totalPlays}');
    buf.writeln('Listening:    ${_formatDuration(recap.totalListeningTime)}');
    buf.writeln('Songs:        ${recap.uniqueSongs} unique');
    buf.writeln('Artists:      ${recap.uniqueArtists} unique');
    buf.writeln('Active Days:  ${recap.activeDays}');
    if (recap.peakHour != null) {
      buf.writeln('Peak Hour:    ${recap.peakHour}:00');
    }
    buf.writeln();

    buf.writeln('--- Top Songs ---');
    for (var i = 0; i < recap.topSongs.length; i++) {
      final s = recap.topSongs[i];
      buf.writeln('  ${i + 1}. ${s.song.title} — ${s.song.artist}');
      buf.writeln('     Plays: ${s.plays} | Time: ${_formatDuration(s.listeningTime)} | Last: ${_formatDateTime(s.lastPlayedAt)}');
    }
    buf.writeln();

    buf.writeln('--- Top Artists ---');
    for (var i = 0; i < recap.topArtists.length; i++) {
      final a = recap.topArtists[i];
      buf.writeln('  ${i + 1}. ${a.artist}');
      buf.writeln('     Plays: ${a.plays} | Songs: ${a.uniqueSongs} | Time: ${_formatDuration(a.listeningTime)} | Last: ${_formatDateTime(a.lastPlayedAt)}');
    }
    buf.writeln();

    buf.writeln('--- Top Albums ---');
    for (var i = 0; i < recap.topAlbums.length; i++) {
      final a = recap.topAlbums[i];
      buf.writeln('  ${i + 1}. ${a.album} — ${a.artist}');
      buf.writeln('     Plays: ${a.plays} | Songs: ${a.uniqueSongs} | Time: ${_formatDuration(a.listeningTime)} | Last: ${_formatDateTime(a.lastPlayedAt)}');
    }

    return buf.toString();
  }
}
