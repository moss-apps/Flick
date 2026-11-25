import 'dart:math' as math;

import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/song.dart';

/// Collection kinds of the car channel (docs/ANDROID_AUTO_DESIGN.md, 4.3).
abstract final class CarKind {
  static const album = 'album';
  static const artist = 'artist';
  static const playlist = 'playlist';
  static const folder = 'folder';
  static const songs = 'songs';
  static const favorites = 'favorites';
  static const recentlyAdded = 'recentlyAdded';
  static const mostPlayed = 'mostPlayed';
  static const recentlyPlayed = 'recentlyPlayed';
  static const search = 'search';

  /// Kinds that `collection`, `play` and `enqueue` accept.
  static const playable = {
    album,
    artist,
    playlist,
    folder,
    songs,
    favorites,
    recentlyAdded,
    mostPlayed,
    recentlyPlayed,
    search,
  };
}

/// Short fidelity label: `DSD128`, `24/96 FLAC`, `16/44.1 FLAC`, `MP3`.
///
/// DSD uses the rate label. Otherwise the label is `{bitDepth}/{kHz} {type}`
/// when bit depth and sample rate are both known, else the file type alone.
/// Null when nothing is known.
String? carQualityLabel(Song song) {
  if (song.isDsd) return song.dsdRateLabel;

  final type = _cleanFileType(song.fileType);
  final depth = song.bitDepth;
  final rate = song.sampleRate;
  if (depth != null && depth > 0 && rate != null && rate > 0) {
    final pcm = '$depth/${_formatKhz(rate)}';
    return type == null ? pcm : '$pcm $type';
  }
  return type;
}

/// The label every song shares, or null when they differ, when any song has
/// none, or when [songs] is empty.
String? carCommonQuality(Iterable<Song> songs) {
  String? common;
  var first = true;
  for (final song in songs) {
    final label = carQualityLabel(song);
    if (label == null) return null;
    if (first) {
      common = label;
      first = false;
    } else if (label != common) {
      return null;
    }
  }
  return common;
}

String? _cleanFileType(String fileType) {
  final type = fileType.trim();
  if (type.isEmpty || type.toLowerCase() == 'unknown') return null;
  return type;
}

/// 96000 -> "96", 44100 -> "44.1", 22050 -> "22.05".
String _formatKhz(int hz) {
  final text = (hz / 1000).toStringAsFixed(2);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// First non-empty cover among [songs], or null.
String? carFirstArt(Iterable<Song> songs) {
  for (final song in songs) {
    final art = song.albumArt;
    if (art != null && art.isNotEmpty) return art;
  }
  return null;
}

String carArtistName(String artist) {
  final name = artist.trim();
  return name.isEmpty ? l10n.unknownArtist : name;
}

/// `Track {id, title, artist, album, art?, durationMs, quality?, trackNo?}`.
Map<String, Object?> carTrackMap(Song song, {int? trackNo}) {
  final art = song.albumArt;
  final quality = carQualityLabel(song);
  return {
    'id': song.id,
    'title': song.title,
    'artist': carArtistName(song.artist),
    'album': song.album?.trim() ?? '',
    if (art != null && art.isNotEmpty) 'art': art,
    'durationMs': song.duration.inMilliseconds,
    'quality': ?quality,
    'trackNo': ?trackNo,
  };
}

/// The track number for an album row: the tag when it is a real number.
int? carTrackNumber(Song song) {
  final number = song.trackNumber;
  return number != null && number > 0 ? number : null;
}

/// `Collection {kind, id, title, subtitle?, art?, count?}`.
///
/// `quality` is an additive key (the tracks' common label) so a grid tile can
/// read "Artist - 24/96 FLAC"; readers that do not know it ignore it.
Map<String, Object?> carCollectionMap({
  required String kind,
  required String id,
  required String title,
  String? subtitle,
  String? art,
  int? count,
  String? quality,
}) {
  return {
    'kind': kind,
    'id': id,
    'title': title,
    if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
    if (art != null && art.isNotEmpty) 'art': art,
    'count': ?count,
    'quality': ?quality,
  };
}

/// Caps a requested page size: [fallback] when absent or not positive, never
/// above [max].
int carLimit(Object? requested, {int fallback = 300, int max = 1000}) {
  final value = requested is num ? requested.toInt() : null;
  if (value == null || value <= 0) return fallback;
  return value > max ? max : value;
}

/// The songs after the current one, split the way the car shows them.
///
/// PlayerService keeps the manual queue *inside* its upcoming list (queued
/// songs are inserted right after the current one), so the queue is not a
/// separate list to append. [queued] marks which entries of `upNext` came from
/// the manual queue; everything else is the rest of the playing context. A
/// song is therefore in exactly one section, even when it is both queued and
/// later in the context.
class CarUpcoming {
  const CarUpcoming({
    required this.fromYou,
    required this.fromContext,
    required this.order,
    required this.fromManualQueue,
  });

  final List<Song> fromYou;
  final List<Song> fromContext;

  /// For each row in display order (fromYou, then fromContext): the index to
  /// jump to, into `upNext`, or into the manual queue when [fromManualQueue].
  final List<int> order;

  /// True only while nothing is loaded but songs were queued: `upNext` is empty
  /// then, so the queue itself is the whole list.
  final bool fromManualQueue;

  int get total => fromYou.length + fromContext.length;

  factory CarUpcoming.split({
    required List<Song> upNext,
    required List<bool> queued,
    List<Song> manualQueue = const [],
  }) {
    if (upNext.isEmpty && manualQueue.isNotEmpty) {
      return CarUpcoming(
        fromYou: List.unmodifiable(manualQueue),
        fromContext: const [],
        order: List.unmodifiable([
          for (var i = 0; i < manualQueue.length; i++) i,
        ]),
        fromManualQueue: true,
      );
    }

    final you = <int>[];
    final context = <int>[];
    for (var i = 0; i < upNext.length; i++) {
      (i < queued.length && queued[i] ? you : context).add(i);
    }
    return CarUpcoming(
      fromYou: List.unmodifiable([for (final i in you) upNext[i]]),
      fromContext: List.unmodifiable([for (final i in context) upNext[i]]),
      order: List.unmodifiable([...you, ...context]),
      fromManualQueue: false,
    );
  }
}

/// The song a `play` starts on: [trackId] when it is in [songs], else a random
/// song when [shuffle] is set, else the first. [songs] must not be empty.
Song carStartSong(
  List<Song> songs, {
  String? trackId,
  bool shuffle = false,
  math.Random? random,
}) {
  if (trackId != null) {
    for (final song in songs) {
      if (song.id == trackId) return song;
    }
  }
  if (shuffle && songs.length > 1) {
    return songs[(random ?? math.Random()).nextInt(songs.length)];
  }
  return songs.first;
}

/// The row of [upcoming] that `jump {section, index}` names, or null when the
/// section is unknown or [index] is outside it.
int? carJumpRow(CarUpcoming upcoming, String section, int index) {
  if (index < 0) return null;
  switch (section) {
    case 'you':
      return index < upcoming.fromYou.length ? index : null;
    case 'context':
      return index < upcoming.fromContext.length
          ? upcoming.fromYou.length + index
          : null;
  }
  return null;
}

/// `queue` result: `{current, fromYou, fromContext, contextName?, shuffle,
/// loop}`. At most [limit] rows in all; the user's queue is shown first, so it
/// takes the rows before the rest of the list does.
Map<String, Object?> carQueueMap({
  required Song? current,
  required CarUpcoming upcoming,
  required int limit,
  required PlaybackContext context,
  required bool shuffle,
  required String loop,
}) {
  final you = upcoming.fromYou.take(limit).toList();
  final rest = upcoming.fromContext.take(limit - you.length).toList();
  final name = context.source == PlaybackSource.unknown
      ? null
      : context.sourceName?.trim();
  return {
    'current': current == null ? null : carTrackMap(current),
    'fromYou': [for (final song in you) carTrackMap(song)],
    'fromContext': [for (final song in rest) carTrackMap(song)],
    if (name != null && name.isNotEmpty) 'contextName': name,
    'shuffle': shuffle,
    'loop': loop,
  };
}
