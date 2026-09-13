import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-authored descriptions shown on detail screens (albums, artists,
/// playlists), keyed by a stable per-item key. Persisted in SharedPreferences.
final detailDescriptionsProvider =
    AsyncNotifierProvider.autoDispose<DetailDescriptionsNotifier, Map<String, String>>(
      DetailDescriptionsNotifier.new,
    );

class DetailDescriptionsNotifier extends AsyncNotifier<Map<String, String>> {
  static const String _prefsPrefix = 'detail_description_';

  @override
  FutureOr<Map<String, String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final descriptions = <String, String>{};
    for (final prefsKey in prefs.getKeys()) {
      if (!prefsKey.startsWith(_prefsPrefix)) continue;
      final value = prefs.getString(prefsKey);
      if (value != null && value.isNotEmpty) {
        descriptions[prefsKey.substring(_prefsPrefix.length)] = value;
      }
    }
    return descriptions;
  }

  /// Saves [description] for [key]. An empty description removes the entry.
  Future<void> save(String key, String description) async {
    final prefs = await SharedPreferences.getInstance();
    if (description.isEmpty) {
      await prefs.remove('$_prefsPrefix$key');
    } else {
      await prefs.setString('$_prefsPrefix$key', description);
    }

    if (!ref.mounted) return;
    final updated = Map<String, String>.from(state.value ?? const {});
    if (description.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = description;
    }
    state = AsyncValue.data(updated);
  }
}

/// Convenience provider to watch a single item's description.
final detailDescriptionProvider =
    Provider.autoDispose.family<String, String>((ref, key) {
      return ref.watch(detailDescriptionsProvider).value?[key] ?? '';
    });
