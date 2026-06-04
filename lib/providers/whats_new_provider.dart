import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/whats_new/data/changelog_data.dart';
import 'package:flick/providers/app_preferences_provider.dart';

class WhatsNewState {
  const WhatsNewState({required this.currentEntry, required this.pendingEntry});

  /// The changelog entry matching the running app version (always non-null in
  /// production — `findChangelogEntry` returns `null` only if a release
  /// shipped without being recorded in `changelog_data.dart`).
  final ChangelogEntry? currentEntry;

  /// The entry that should be shown to the user as new, if any.
  final ChangelogEntry? pendingEntry;
}

class WhatsNewNotifier extends Notifier<WhatsNewState> {
  @override
  WhatsNewState build() {
    return WhatsNewState(
      currentEntry: findChangelogEntry(kAppVersion),
      pendingEntry: null,
    );
  }

  /// Re-evaluates whether a "What's New" entry should be presented. Call this
  /// after the app preferences have finished loading so the stored
  /// "last seen" version is accurate.
  void evaluate() {
    final preferences = ref.read(appPreferencesProvider);
    final lastSeen = preferences.lastSeenChangelogVersion;

    final current = findChangelogEntry(kAppVersion);
    final shouldShow = lastSeen != null && lastSeen != kAppVersion;

    state = WhatsNewState(
      currentEntry: current,
      pendingEntry: shouldShow ? current : null,
    );
  }

  /// Marks the running version as seen so the sheet does not re-appear.
  Future<void> markCurrentVersionSeen() async {
    await ref
        .read(appPreferencesProvider.notifier)
        .setLastSeenChangelogVersion(kAppVersion);
    state = WhatsNewState(currentEntry: state.currentEntry, pendingEntry: null);
  }
}

final whatsNewProvider = NotifierProvider<WhatsNewNotifier, WhatsNewState>(
  WhatsNewNotifier.new,
);
