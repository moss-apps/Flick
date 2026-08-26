import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/duplicate_cleaner_service.dart';

/// Provider for the duplicate cleaner service.
final duplicateCleanerServiceProvider = Provider<DuplicateCleanerService>((ref) {
  return DuplicateCleanerService();
});

/// State for duplicate scan results.
class DuplicateScanState {
  final DuplicateScanResult? result;
  final bool isScanning;
  final bool isRemoving;
  final String? error;
  /// Per-group keep selection: group key → set of song ids to keep.
  /// Seeded from each group's recommended keep after a scan.
  /// Multi-select: any number of copies can be kept per group, at least one.
  final Map<String, Set<int>> keepSelection;

  const DuplicateScanState({
    this.result,
    this.isScanning = false,
    this.isRemoving = false,
    this.error,
    this.keepSelection = const {},
  });

  Set<int> _keepSetFor(DuplicateGroup g) =>
      keepSelection[g.key] ?? {g.recommendedKeep.id};

  /// Total duplicates that will be removed given the current multi-selection.
  int get selectedRemoveCount {
    if (result == null) return 0;
    var count = 0;
    for (final g in result!.duplicateGroups) {
      final keep = _keepSetFor(g);
      count += (g.songs.length - keep.length).clamp(0, g.songs.length);
    }
    return count;
  }

  /// Total songs that will be kept.
  int get selectedKeepCount {
    if (result == null) return 0;
    var count = 0;
    for (final g in result!.duplicateGroups) {
      count += _keepSetFor(g).length;
    }
    return count;
  }

  /// Whether the current selection differs from the recommended picks.
  bool get hasCustomSelection {
    if (result == null) return false;
    for (final g in result!.duplicateGroups) {
      final sel = keepSelection[g.key];
      if (sel == null) continue;
      if (sel.length != 1 || !sel.contains(g.recommendedKeep.id)) return true;
    }
    return false;
  }

  DuplicateScanState copyWith({
    DuplicateScanResult? result,
    bool? isScanning,
    bool? isRemoving,
    String? error,
    bool clearError = false,
    bool clearResult = false,
    Map<String, Set<int>>? keepSelection,
  }) {
    return DuplicateScanState(
      result: clearResult ? null : (result ?? this.result),
      isScanning: isScanning ?? this.isScanning,
      isRemoving: isRemoving ?? this.isRemoving,
      error: clearError ? null : (error ?? this.error),
      keepSelection: keepSelection ?? this.keepSelection,
    );
  }
}

/// Notifier for managing duplicate scan state.
class DuplicateScanNotifier extends Notifier<DuplicateScanState> {
  @override
  DuplicateScanState build() => const DuplicateScanState();

  Future<void> scanForDuplicates() async {
    state = state.copyWith(isScanning: true, clearError: true);

    try {
      final service = ref.read(duplicateCleanerServiceProvider);
      final result = await service.scanForDuplicates();

      final selection = <String, Set<int>>{
        for (final g in result.duplicateGroups) g.key: {g.recommendedKeep.id},
      };

      state = DuplicateScanState(
        result: result,
        isScanning: false,
        isRemoving: false,
        keepSelection: selection,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  /// Toggle whether [songId] is kept for [groupKey] (multi-select).
  /// At least one song must stay per group — toggling off the last kept is ignored.
  /// Returns true if the toggle succeeded.
  bool toggleKeep(String groupKey, int songId) {
    if (state.result == null) return false;
    if (state.isRemoving) return false;
    final group = state.result!.duplicateGroups
        .where((g) => g.key == groupKey)
        .firstOrNull;
    if (group == null) return false;
    final current =
        Set<int>.from(state.keepSelection[groupKey] ?? {group.recommendedKeep.id});
    if (current.contains(songId)) {
      if (current.length == 1) return false;
      current.remove(songId);
    } else {
      current.add(songId);
    }
    final next = Map<String, Set<int>>.from(state.keepSelection);
    next[groupKey] = current;
    state = state.copyWith(keepSelection: next);
    return true;
  }

  /// Backwards-compat alias — sets a singular keep (replaces the set).
  void selectKeep(String groupKey, int songId) {
    if (state.result == null) return;
    if (state.isRemoving) return;
    final next = Map<String, Set<int>>.from(state.keepSelection);
    next[groupKey] = {songId};
    state = state.copyWith(keepSelection: next);
  }

  /// Explicitly set the keep set for a group (must be non-empty subset of group).
  void setKeepSet(String groupKey, Set<int> keepIds) {
    if (state.result == null || keepIds.isEmpty) return;
    final next = Map<String, Set<int>>.from(state.keepSelection);
    next[groupKey] = Set<int>.from(keepIds);
    state = state.copyWith(keepSelection: next);
  }

  /// Restore a group's keep choice to the recommended one.
  void resetKeepToRecommended(String groupKey) {
    final group = state.result?.duplicateGroups
        .where((g) => g.key == groupKey)
        .firstOrNull;
    if (group == null) return;
    final next = Map<String, Set<int>>.from(state.keepSelection);
    next[groupKey] = {group.recommendedKeep.id};
    state = state.copyWith(keepSelection: next);
  }

  /// Reset all groups to recommended keeps.
  void resetAllToRecommended() {
    if (state.result == null) return;
    final selection = <String, Set<int>>{
      for (final g in state.result!.duplicateGroups) g.key: {g.recommendedKeep.id},
    };
    state = state.copyWith(keepSelection: selection);
  }

  Future<void> removeAllDuplicates() async {
    if (state.result == null) return;

    state = state.copyWith(isRemoving: true, clearError: true);

    try {
      final service = ref.read(duplicateCleanerServiceProvider);
      await service.removeAllDuplicates(
        state.result!.duplicateGroups,
      );

      // Rescan after removal — clears selection and refreshes counts.
      await scanForDuplicates();
    } catch (e) {
      state = state.copyWith(
        isRemoving: false,
        error: e.toString(),
      );
    }
  }

  /// Remove duplicates respecting the per-group multi-keep selection.
  Future<DuplicateRemovalResult?> removeSelected() async {
    if (state.result == null) return null;

    state = state.copyWith(isRemoving: true, clearError: true);

    try {
      final service = ref.read(duplicateCleanerServiceProvider);
      final idsToRemove = <int>[];
      var kept = 0;
      for (final group in state.result!.duplicateGroups) {
        final keepIds =
            state.keepSelection[group.key] ?? {group.recommendedKeep.id};
        kept += keepIds.length;
        idsToRemove.addAll(
          group.songs.where((s) => !keepIds.contains(s.id)).map((s) => s.id),
        );
      }

      if (idsToRemove.isEmpty) {
        state = state.copyWith(isRemoving: false);
        return DuplicateRemovalResult(removedCount: 0, keptCount: kept, errors: []);
      }

      final removed = await service.removeSpecificDuplicates(idsToRemove);

      await scanForDuplicates();

      return DuplicateRemovalResult(
        removedCount: removed,
        keptCount: kept,
        errors: [],
      );
    } catch (e) {
      state = state.copyWith(
        isRemoving: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void clearResults() {
    state = const DuplicateScanState();
  }
}

/// Provider for duplicate scan state.
final duplicateScanProvider = NotifierProvider<DuplicateScanNotifier, DuplicateScanState>(
  DuplicateScanNotifier.new,
);
