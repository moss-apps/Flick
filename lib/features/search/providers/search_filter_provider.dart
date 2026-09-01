import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_category.dart';

class SearchFilterNotifier extends Notifier<Set<SearchCategory>> {
  static const _key = 'search_enabled_categories';

  @override
  Set<SearchCategory> build() {
    // Default: all enabled.
    final initial = SearchCategory.values.toSet();
    // Async hydrate – mirrors SongsNotifier pattern.
    Future.microtask(_load);
    return initial;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key);
      if (stored == null) return;
      if (stored.isEmpty) {
        // Empty list persisted means user disabled all – respect it.
        state = <SearchCategory>{};
        return;
      }
      final parsed = stored
          .map(SearchCategoryX.fromStorageKey)
          .whereType<SearchCategory>()
          .toSet();
      // If stored list contained only unknown keys, keep default all.
      if (parsed.isNotEmpty || stored.isEmpty) {
        state = parsed;
      }
    } catch (_) {}
  }

  Future<void> _save(Set<SearchCategory> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        value.map((c) => c.storageKey).toList(),
      );
    } catch (_) {}
  }

  void toggle(SearchCategory category) {
    final next = Set<SearchCategory>.from(state);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    state = next;
    _save(next);
  }

  void setEnabled(SearchCategory category, bool enabled) {
    final next = Set<SearchCategory>.from(state);
    if (enabled) {
      next.add(category);
    } else {
      next.remove(category);
    }
    if (next.length == state.length && next.containsAll(state)) return;
    state = next;
    _save(next);
  }

  void setAll(bool enabled) {
    final next =
        enabled ? SearchCategory.values.toSet() : <SearchCategory>{};
    state = next;
    _save(next);
  }

  void toggleAll() {
    if (isAllEnabled) {
      setAll(false);
    } else {
      setAll(true);
    }
  }

  bool isEnabled(SearchCategory category) => state.contains(category);

  bool get isAllEnabled => state.length == SearchCategory.values.length;

  bool get isNoneEnabled => state.isEmpty;
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, Set<SearchCategory>>(
  SearchFilterNotifier.new,
);

final searchAllEnabledProvider = Provider<bool>((ref) {
  final enabled = ref.watch(searchFilterProvider);
  return enabled.length == SearchCategory.values.length;
});
