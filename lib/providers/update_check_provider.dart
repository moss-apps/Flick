import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';

import '../core/constants/app_constants.dart';

class UpdateCheckState {
  const UpdateCheckState({
    this.isOnline = false,
    this.isChecking = false,
    this.hasChecked = false,
    this.updateAvailable = false,
    this.errorMessage,
    this.lastCheckedAt,
    this.isPlayStoreBuild = true,
    this.downloadUrl,
    this.latestVersion,
  });

  final bool isOnline;
  final bool isChecking;
  final bool hasChecked;
  final bool updateAvailable;
  final String? errorMessage;
  final DateTime? lastCheckedAt;
  final bool isPlayStoreBuild;
  final String? downloadUrl;
  final String? latestVersion;

  UpdateCheckState copyWith({
    bool? isOnline,
    bool? isChecking,
    bool? hasChecked,
    bool? updateAvailable,
    String? errorMessage,
    DateTime? lastCheckedAt,
    bool clearErrorMessage = false,
    bool? isPlayStoreBuild,
    String? downloadUrl,
    String? latestVersion,
    bool clearDownloadUrl = false,
    bool clearLatestVersion = false,
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
      downloadUrl:
          clearDownloadUrl ? null : downloadUrl ?? this.downloadUrl,
      latestVersion:
          clearLatestVersion ? null : latestVersion ?? this.latestVersion,
    );
  }
}

class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  static const String flickPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mossapps.flick';
  static const String flickPlayStoreMarketUrl =
      'market://details?id=com.mossapps.flick';
  static const String flickWebsiteDownloadUrl = 'https://www.flick-player.site/';
  static const Duration _automaticRefreshCooldown = Duration(minutes: 30);

  static final Uri _githubReleasesApiUri = Uri.parse(
    'https://api.github.com/repos/moss-apps/Flick/releases/latest',
  );

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _initialized = false;

  @override
  UpdateCheckState build() {
    if (!_initialized) {
      _initialized = true;
      ref.onDispose(() => _connectivitySubscription?.cancel());
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        result,
      ) {
        unawaited(_syncConnectivityAndMaybeCheck(result));
      });
      Future<void>.microtask(_bootstrap);
    }
    return const UpdateCheckState();
  }

  Future<void> _bootstrap() async {
    final connectivityState = await _connectivity.checkConnectivity();
    await _syncConnectivityAndMaybeCheck(connectivityState, forceCheck: true);
  }

  Future<void> refreshIfOnline({bool force = false}) async {
    final connectivityState = await _connectivity.checkConnectivity();
    await _syncConnectivityAndMaybeCheck(connectivityState, forceCheck: force);
  }

  Future<void> _syncConnectivityAndMaybeCheck(
    dynamic connectivityState, {
    bool forceCheck = false,
  }) async {
    final isOnline = _isOnline(connectivityState);
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

  bool _isOnline(dynamic connectivityState) {
    if (connectivityState is ConnectivityResult) {
      return connectivityState != ConnectivityResult.none;
    }
    if (connectivityState is List<ConnectivityResult>) {
      return connectivityState.any(
        (result) => result != ConnectivityResult.none,
      );
    }
    return false;
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
      );
    } on PlatformException {
      await _checkGitHubForUpdate();
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        errorMessage: 'Unable to check for updates right now.',
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

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      var tag = (data['tag_name'] as String?)?.trim() ?? '';
      if (tag.startsWith('v')) {
        tag = tag.substring(1);
      }

      final isUpdateAvailable = tag.isNotEmpty && tag != kAppVersion;

      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        isPlayStoreBuild: false,
        updateAvailable: isUpdateAvailable,
        downloadUrl:
            isUpdateAvailable ? flickWebsiteDownloadUrl : null,
        latestVersion: tag.isNotEmpty ? tag : null,
        lastCheckedAt: DateTime.now(),
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        isPlayStoreBuild: false,
        updateAvailable: false,
        errorMessage: 'Unable to check for updates right now.',
        lastCheckedAt: DateTime.now(),
      );
    }
  }
}

final updateCheckProvider =
    NotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
      UpdateCheckNotifier.new,
    );
