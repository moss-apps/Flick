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
  /// Per-group keep selection: group key → song id to keep.
  /// Seeded from each group's recommended keep after a scan.
  final Map<String, int> keepSelection;

  const DuplicateScanState({
    this.result,
    this.isScanning = false,
    this.isRemoving = false,
    this.error,
    this.keepSelection = const {},
  });

  /// Total duplicates that will be removed given the current selection.
  /// Always equals sum(songs.length - 1) — kept count is one per group.
  int get selectedRemoveCount {
    if (result == null) return 0;
    var count = 0;
    for (final g in result!.duplicateGroups) {
      // one kept per group, regardless of which one
      count += g.songs.length - 1;
    }
    return count;
  }

  /// Whether the current selection differs from the recommended picks.
  bool get hasCustomSelection {
    if (result == null) return false;
    for (final g in result!.duplicateGroups) {
      final sel = keepSelection[g.key];
      if (sel != null && sel != g.recommendedKeep.id) return true;
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
    Map<String, int>? keepSelection,
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

      final selection = <String, int>{
        for (final g in result.duplicateGroups) g.key: g.recommendedKeep.id,
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

  /// Update which song to keep for a single group (singular selection).
  void selectKeep(String groupKey, int songId) {
    if (state.result == null) return;
    if (state.isRemoving) return;
    final next = Map<String, int>.from(state.keepSelection);
    next[groupKey] = songId;
    state = state.copyWith(keepSelection: next);
  }

  /// Restore a group's keep choice to the recommended one.
  void resetKeepToRecommended(String groupKey) {
    final group = state.result?.duplicateGroups
        .where((g) => g.key == groupKey)
        .firstOrNull;
    if (group == null) return;
    selectKeep(groupKey, group.recommendedKeep.id);
  }

  /// Reset all groups to recommended keeps.
  void resetAllToRecommended() {
    if (state.result == null) return;
    final selection = <String, int>{
      for (final g in state.result!.duplicateGroups) g.key: g.recommendedKeep.id,
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

  /// Remove duplicates respecting the per-group singular selection.
  Future<DuplicateRemovalResult?> removeSelected() async {
    if (state.result == null) return null;

    state = state.copyWith(isRemoving: true, clearError: true);

    try {
      final service = ref.read(duplicateCleanerServiceProvider);
      final idsToRemove = <int>[];
      for (final group in state.result!.duplicateGroups) {
        final keepId = state.keepSelection[group.key] ?? group.recommendedKeep.id;
        idsToRemove.addAll(
          group.songs.where((s) => s.id != keepId).map((s) => s.id),
        );
      }

      if (idsToRemove.isEmpty) {
        state = state.copyWith(isRemoving: false);
        return DuplicateRemovalResult(removedCount: 0, keptCount: 0, errors: []);
      }

      final removed = await service.removeSpecificDuplicates(idsToRemove);
      final kept = state.result!.totalGroups;

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
