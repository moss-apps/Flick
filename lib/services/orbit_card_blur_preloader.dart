import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flick/models/song.dart';

/// Warms a small moving window, one cover at a time. A jump or direction change
/// replaces queued work rather than building a backlog for songs already passed.
class OrbitCardBlurPreloader {
  OrbitCardBlurPreloader({required this.preload});

  final Future<void> Function(Song song, Size cardSize) preload;
  static const _lookahead = 4;

  List<Song>? _songs;
  int? _center;
  int? _visibleItems;
  Size? _cardSize;
  List<(Song, Size)> _pending = [];
  Future<void>? _work;
  bool _disposed = false;

  Future<void> update({
    required List<Song> songs,
    required int centerIndex,
    required int visibleItems,
    required Size cardSize,
  }) {
    if (_disposed) return Future<void>.value();
    if (identical(songs, _songs) &&
        centerIndex == _center &&
        visibleItems == _visibleItems &&
        cardSize == _cardSize) {
      return _work ?? Future<void>.value();
    }
    final direction = _center == null || centerIndex >= _center! ? 1 : -1;
    _songs = songs;
    _center = centerIndex;
    _visibleItems = visibleItems;
    _cardSize = cardSize;
    final radius = math.max(0, visibleItems ~/ 2) + _lookahead;
    _pending = [
      for (var distance = 0; distance <= radius; distance++)
        for (final index in [
          centerIndex + distance * direction,
          if (distance > 0) centerIndex - distance * direction,
        ])
          if (index >= 0 && index < songs.length) (songs[index], cardSize),
    ];
    return _work ??= Future<void>.microtask(_drain);
  }

  Future<void> _drain() async {
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final (song, size) = _pending.removeAt(0);
        try {
          await preload(song, size);
        } catch (_) {
          // One unavailable cover must not block the rest of the window.
        }
      }
    } finally {
      _work = null;
    }
  }

  void clear() {
    _pending.clear();
    _songs = null;
    _center = null;
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
