import 'package:shared_preferences/shared_preferences.dart';

/// Cap for on-disk playback caches (WAV conversions + SAF staging copies).
/// Unlimited is represented as -1; enforceCacheCap treats <= 0 as no cap.
const int kPlaybackCacheUnlimited = -1;

const int kPlaybackCacheDefaultMaxBytes = 1024 * 1024 * 1024; // 1 GiB

/// Ordered preset choices shown in settings; label -> bytes.
const List<(String, int)> kPlaybackCacheCapPresets = [
  ('250 MB', 250 * 1024 * 1024),
  ('500 MB', 500 * 1024 * 1024),
  ('1 GB', kPlaybackCacheDefaultMaxBytes),
  ('2 GB', 2 * 1024 * 1024 * 1024),
  ('Unlimited', kPlaybackCacheUnlimited),
];

class PlaybackCachePreferencesService {
  static const _maxBytesKey = 'playback_cache_max_bytes';

  static int? _cachedMaxBytes;

  /// Invalidates the in-memory copy so the next read hits SharedPreferences.
  /// Call after writing from another isolate or in tests.
  static void invalidateCache() => _cachedMaxBytes = null;

  Future<int> getMaxCacheBytes() async {
    final cached = _cachedMaxBytes;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_maxBytesKey);
    final resolved = value ?? kPlaybackCacheDefaultMaxBytes;
    _cachedMaxBytes = resolved;
    return resolved;
  }

  Future<void> setMaxCacheBytes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxBytesKey, value);
    _cachedMaxBytes = value;
  }
}
