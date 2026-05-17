import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateCheckState {
  const UpdateCheckState({
    this.isOnline = false,
    this.isChecking = false,
    this.hasChecked = false,
    this.updateAvailable = false,
    this.errorMessage,
    this.lastCheckedAt,
  });

  final bool isOnline;
  final bool isChecking;
  final bool hasChecked;
  final bool updateAvailable;
  final String? errorMessage;
  final DateTime? lastCheckedAt;

  UpdateCheckState copyWith({
    bool? isOnline,
    bool? isChecking,
    bool? hasChecked,
    bool? updateAvailable,
    String? errorMessage,
    DateTime? lastCheckedAt,
    bool clearErrorMessage = false,
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
    );
  }
}

class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  static const String flickPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mossapps.flick';
  static const String flickPlayStoreMarketUrl =
      'market://details?id=com.mossapps.flick';
  static const Duration _automaticRefreshCooldown = Duration(minutes: 30);

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
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
        updateAvailable: false,
        errorMessage: 'Update checks only work on the Play Store build.',
        lastCheckedAt: DateTime.now(),
      );
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        hasChecked: true,
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
