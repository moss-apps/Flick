import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';

import '../core/constants/app_constants.dart';
import '../models/update_channel.dart';
import '../services/github_release_service.dart';
import 'connectivity_provider.dart';
import 'package:flick/l10n/l10n.dart';

class UpdateCheckState {
  const UpdateCheckState({
    this.isOnline = false,
    this.isChecking = false,
    this.hasChecked = false,
    this.updateAvailable = false,
    this.errorMessage,
    this.lastCheckedAt,
    this.isPlayStoreBuild = true,
    this.stableRelease,
    this.betaRelease,
  });

  final bool isOnline;
  final bool isChecking;
  final bool hasChecked;
  final bool updateAvailable;
  final String? errorMessage;
  final DateTime? lastCheckedAt;
  final bool isPlayStoreBuild;
  final AppRelease? stableRelease;
  final AppRelease? betaRelease;

  /// Whether the selected [channel] has an update to offer. Play Store builds
  /// keep their existing single-channel behavior.
  bool hasUpdateForChannel(UpdateChannel channel) {
    if (isPlayStoreBuild) return updateAvailable;
    return switch (channel) {
      UpdateChannel.stable => stableRelease != null,
      UpdateChannel.beta => betaRelease != null,
      UpdateChannel.both => stableRelease != null || betaRelease != null,
    };
  }

  /// The newest release available on [channel], preferring the stable release
  /// when both channels point at the same version.
  AppRelease? releaseForChannel(UpdateChannel channel) {
    return switch (channel) {
      UpdateChannel.stable => stableRelease,
      UpdateChannel.beta => betaRelease,
      UpdateChannel.both => _newestRelease(stableRelease, betaRelease),
    };
  }

  static AppRelease? _newestRelease(AppRelease? stable, AppRelease? beta) {
    if (stable == null) return beta;
    if (beta == null) return stable;
    final stableVersion = SemVer.tryParse(stable.version);
    final betaVersion = SemVer.tryParse(beta.version);
    if (stableVersion == null) return beta;
    if (betaVersion == null) return stable;
    return betaVersion.compareTo(stableVersion) > 0 ? beta : stable;
  }

  UpdateCheckState copyWith({
    bool? isOnline,
    bool? isChecking,
    bool? hasChecked,
    bool? updateAvailable,
    String? errorMessage,
    DateTime? lastCheckedAt,
    bool clearErrorMessage = false,
    bool? isPlayStoreBuild,
    AppRelease? stableRelease,
    AppRelease? betaRelease,
    bool clearStableRelease = false,
    bool clearBetaRelease = false,
  }) {
    return UpdateCheckState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      hasChecked: hasChecked ?? this.hasChecked,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      isPlayStoreBuild: isPlayStoreBuild ?? this.isPlayStoreBuild,
      stableRelease: clearStableRelease
          ? null
          : stableRelease ?? this.stableRelease,
      betaRelease: clearBetaRelease ? null : betaRelease ?? this.betaRelease,
    );
  }
}

class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  static const String flickPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mossapps.flick';
  static const String flickPlayStoreMarketUrl =
      'market://details?id=com.mossapps.flick';
  static const String flickWebsiteDownloadUrl =
      'https://www.flick-player.site/';
  static const Duration _automaticRefreshCooldown = Duration(minutes: 30);

  static final Uri _githubReleasesApiUri = Uri.parse(
    GitHubReleaseService.releasesUri,
  );

  bool _initialized = false;

  @override
  UpdateCheckState build() {
    if (!_initialized) {
      _initialized = true;
      ref.listen<ConnectivityStatus>(connectivityProvider, (previous, next) {
        if (next == ConnectivityStatus.unknown) {
          return;
        }
        final isOnline = next == ConnectivityStatus.online;
        unawaited(
          _syncConnectivityAndMaybeCheck(
            isOnline,
            forceCheck: previous == ConnectivityStatus.offline && isOnline,
          ),
        );
      });

      // The shared provider may already be resolved when this notifier is
      // first read, in which case no transition will fire.
      final status = ref.read(connectivityProvider);
      if (status == ConnectivityStatus.online) {
        Future<void>.microtask(() => _syncConnectivityAndMaybeCheck(true));
      } else if (status == ConnectivityStatus.offline) {
        Future<void>.microtask(() => _syncConnectivityAndMaybeCheck(false));
      }
    }
    return const UpdateCheckState();
  }

  Future<void> refreshIfOnline({bool force = false}) async {
    final status = ref.read(connectivityProvider);
    final isOnline = switch (status) {
      ConnectivityStatus.online => true,
      ConnectivityStatus.offline => false,
      ConnectivityStatus.unknown =>
        await ref.read(connectivityProvider.notifier).refresh(),
    };
    await _syncConnectivityAndMaybeCheck(isOnline, forceCheck: force);
  }

  Future<void> _syncConnectivityAndMaybeCheck(
    bool isOnline, {
    bool forceCheck = false,
  }) async {
    final wasOnline = state.isOnline;

    state = state.copyWith(isOnline: isOnline, clearErrorMessage: isOnline);

    if (!isOnline) {
      return;
    }

    final shouldCheck = forceCheck || !state.hasChecked || !wasOnline;
    if (!shouldCheck) {
      return;
    }

    if (!forceCheck && _checkedRecently) {
      return;
    }

    await _checkForUpdate();
  }

  bool get _checkedRecently {
    final lastCheckedAt = state.lastCheckedAt;
    if (lastCheckedAt == null) {
      return false;
    }
    return DateTime.now().difference(lastCheckedAt) < _automaticRefreshCooldown;
  }

  Future<void> _checkForUpdate() async {
    if (state.isChecking) {
      return;
    }

    state = state.copyWith(isChecking: true, clearErrorMessage: true);

    try {
      final info = await InAppUpdate.checkForUpdate();
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        updateAvailable:
            info.updateAvailability == UpdateAvailability.updateAvailable,
        lastCheckedAt: DateTime.now(),
        clearErrorMessage: true,
        clearStableRelease: true,
        clearBetaRelease: true,
      );
    } on PlatformException {
      await _checkGitHubForUpdate();
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        errorMessage: l10n.unableToCheckForUpdatesRight,
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  Future<void> _checkGitHubForUpdate() async {
    try {
      final response = await http.get(
        _githubReleasesApiUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'FlickPlayer',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('GitHub API returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data is! List) {
        throw const FormatException();
      }

      final updates = GitHubReleaseService.selectUpdates(data, kAppVersion);

      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        isPlayStoreBuild: false,
        updateAvailable: updates.hasUpdates,
        stableRelease: updates.stable,
        betaRelease: updates.beta,
        clearStableRelease: updates.stable == null,
        clearBetaRelease: updates.beta == null,
        lastCheckedAt: DateTime.now(),
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        isPlayStoreBuild: false,
        updateAvailable: false,
        clearStableRelease: true,
        clearBetaRelease: true,
        errorMessage: l10n.unableToCheckForUpdatesRight,
        lastCheckedAt: DateTime.now(),
      );
    }
  }
}

final updateCheckProvider =
    NotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
      UpdateCheckNotifier.new,
    );
