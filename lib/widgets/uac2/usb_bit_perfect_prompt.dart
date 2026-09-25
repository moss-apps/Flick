import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/uac2_provider.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';

/// Pure gate: auto-engage only for an external USB route in a live state when
/// the user hasn't opted out, the device isn't declined, and bits aren't
/// already flowing through the direct path.
bool shouldAutoEngageDirectUsb(
  Uac2DeviceStatus status, {
  required bool bitPerfectEnabled,
  required bool isochronousEngineSelected,
  required bool autoEngageEnabled,
  required bool deviceDeclined,
}) {
  if (!autoEngageEnabled || deviceDeclined) return false;
  if (bitPerfectEnabled && isochronousEngineSelected) return false;
  if (status.routeType != Uac2RouteType.externalUsb &&
      !status.isExternalRoute) {
    return false;
  }
  return switch (status.state) {
    Uac2State.connected || Uac2State.prewarming || Uac2State.streaming => true,
    _ => false,
  };
}

/// True while an external USB route is enumerated in a live state.
bool isLiveExternalUsbRoute(Uac2DeviceStatus status) {
  final external =
      status.routeType == Uac2RouteType.externalUsb || status.isExternalRoute;
  if (!external) return false;
  return switch (status.state) {
    Uac2State.connected || Uac2State.prewarming || Uac2State.streaming => true,
    _ => false,
  };
}

/// Stable per-device identity so auto-engage and declines are per DAC.
String usbDevicePromptKey(Uac2DeviceInfo device) =>
    '${device.vendorId}:${device.productId}:${device.serial ?? device.deviceName}';

/// Auto-engages Bit-perfect (USB DAC) when a USB DAC is attached, so the
/// exclusive path wins by default instead of silently staying on Android's
/// mixer. Renders nothing; mount once in the shell. Per-device declines are
/// persisted, and the switch offers Undo.
class UsbBitPerfectPrompt extends ConsumerStatefulWidget {
  const UsbBitPerfectPrompt({super.key});

  @override
  ConsumerState<UsbBitPerfectPrompt> createState() =>
      _UsbBitPerfectPromptState();
}

class _UsbBitPerfectPromptState extends ConsumerState<UsbBitPerfectPrompt> {
  final Set<String> _handledDevices = {};
  final Set<String> _fallbackNoticeShown = {};
  Timer? _restoreTimer;
  String? _engagedDeviceKey;
  AudioEnginePreference? _previousEnginePreference;
  bool _previousBitPerfectEnabled = false;
  bool _engageInFlight = false;
  bool _restoreInFlight = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      uac2DeviceStatusProvider,
      (_, next) => unawaited(_onStatusChanged(next)),
      fireImmediately: true,
    );
    ref.listenManual(
      currentPlaybackModeProvider,
      (_, next) => unawaited(_onPlaybackModeChanged(next)),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    super.dispose();
  }

  Future<void> _onStatusChanged(Uac2DeviceStatus? status) async {
    if (!mounted) return;
    final engagedKey = _engagedDeviceKey;
    if (engagedKey == null) {
      if (status != null) await _maybeAutoEngage(status);
      return;
    }

    if (status != null && isLiveExternalUsbRoute(status)) {
      if (usbDevicePromptKey(status.device) == engagedKey) {
        // Same DAC still live: keep the direct path.
        _restoreTimer?.cancel();
        _restoreTimer = null;
        return;
      }
      // Different DAC: put the previous engine back, then evaluate the new one.
      _restoreTimer?.cancel();
      _restoreTimer = null;
      await _restorePreviousEngine();
      if (mounted) await _maybeAutoEngage(status);
      return;
    }

    if (status != null &&
        (status.routeType == Uac2RouteType.externalUsb ||
            status.isExternalRoute)) {
      // Still enumerated, just re-negotiating (idle/error/prewarming gap):
      // wait instead of thrashing the engine.
      return;
    }

    // Route flickers while detaching; restore the user's engine after a short
    // grace period unless the DAC comes back.
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      unawaited(_restorePreviousEngine());
    });
  }

  Future<void> _maybeAutoEngage(Uac2DeviceStatus status) async {
    if (_engageInFlight || _engagedDeviceKey != null || !mounted) return;
    final preferences = ref.read(uac2PreferencesServiceProvider);
    final autoEngage = await preferences.getAutoEngageUsbDacEnabled();
    if (!autoEngage) return;

    final promptKey = usbDevicePromptKey(status.device);
    if (_handledDevices.contains(promptKey)) return;

    final engine = await preferences.getAudioEnginePreference();
    final bitPerfect = ref.read(uac2ServiceProvider).isBitPerfectEnabledSync;
    final declined = (await preferences.getDeclinedUsbDevices()).contains(
      promptKey,
    );
    if (!shouldAutoEngageDirectUsb(
      status,
      bitPerfectEnabled: bitPerfect,
      isochronousEngineSelected: engine == AudioEnginePreference.isochronousUsb,
      autoEngageEnabled: autoEngage,
      deviceDeclined: declined,
    )) {
      return;
    }
    if (!mounted) return;

    _engageInFlight = true;
    _handledDevices.add(promptKey);
    _engagedDeviceKey = promptKey;
    _previousEnginePreference = engine;
    _previousBitPerfectEnabled = bitPerfect;
    try {
      if (engine != AudioEnginePreference.isochronousUsb) {
        await ref
            .read(playerServiceProvider)
            .setAudioEnginePreference(AudioEnginePreference.isochronousUsb);
      }
      final applied = await ref
          .read(uac2ServiceProvider)
          .setBitPerfectEnabled(true);
      _invalidateEngineProviders();
      if (!mounted) return;
      _showEngagedSnackBar(status, promptKey, applied);
    } catch (e) {
      debugPrint('[USB] Auto-engage direct USB failed: $e');
      _engagedDeviceKey = null;
      _previousEnginePreference = null;
      _previousBitPerfectEnabled = false;
    } finally {
      _engageInFlight = false;
    }
  }

  Future<void> _restorePreviousEngine() async {
    if (_restoreInFlight) return;
    final promptKey = _engagedDeviceKey;
    final previousEngine = _previousEnginePreference;
    final previousBitPerfect = _previousBitPerfectEnabled;
    _engagedDeviceKey = null;
    _previousEnginePreference = null;
    _previousBitPerfectEnabled = false;
    if (promptKey == null || previousEngine == null) return;
    _handledDevices.remove(promptKey);

    _restoreInFlight = true;
    try {
      final service = ref.read(uac2ServiceProvider);
      if (service.isBitPerfectEnabledSync != previousBitPerfect) {
        await service.setBitPerfectEnabled(previousBitPerfect);
      }
      final preferences = ref.read(uac2PreferencesServiceProvider);
      final current = await preferences.getAudioEnginePreference();
      if (current == AudioEnginePreference.isochronousUsb &&
          previousEngine != AudioEnginePreference.isochronousUsb) {
        await ref
            .read(playerServiceProvider)
            .setAudioEnginePreference(previousEngine);
      }
      _invalidateEngineProviders();
    } catch (e) {
      debugPrint('[USB] Failed to restore previous engine: $e');
    } finally {
      _restoreInFlight = false;
    }
  }

  Future<void> _declineAutoEngage(String promptKey) async {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    await ref
        .read(uac2PreferencesServiceProvider)
        .addDeclinedUsbDevice(promptKey);
    await _restorePreviousEngine();
  }

  Future<void> _onPlaybackModeChanged(AudioEngineType mode) async {
    final key = _engagedDeviceKey;
    if (key == null || mode != AudioEngineType.normalAndroid) return;
    if (_fallbackNoticeShown.contains(key)) return;
    final status = ref.read(uac2DeviceStatusProvider);
    if (status == null || !isLiveExternalUsbRoute(status)) return;
    final preferences = ref.read(uac2PreferencesServiceProvider);
    if (await preferences.getAudioEnginePreference() !=
        AudioEnginePreference.isochronousUsb) {
      // The user deliberately moved off the direct engine.
      return;
    }
    if (!mounted) return;
    _fallbackNoticeShown.add(key);
    _showFallbackSnackBar();
  }

  Future<void> _retryDirectUsb() async {
    final messenger = ScaffoldMessenger.of(context);
    final recovered = await ref
        .read(playerServiceProvider)
        .retryDirectUsbForCurrentDevice();
    if (!mounted) return;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            recovered
                ? 'Exclusive USB bit-perfect re-engaged.'
                : 'Exclusive USB is still unavailable. Check the USB diagnostics.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showEngagedSnackBar(
    Uac2DeviceStatus status,
    String promptKey,
    bool applied,
  ) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            applied
                ? 'Bit-perfect (USB DAC) enabled for ${status.device.productName}.'
                : 'Bit-perfect (USB DAC) could not be enabled for ${status.device.productName}. Check the USB diagnostics.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(_declineAutoEngage(promptKey)),
          ),
        ),
      );
  }

  void _showFallbackSnackBar() {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Exclusive USB dropped to the Android mixer. Bit-perfect is paused.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_retryDirectUsb()),
          ),
        ),
      );
  }

  void _invalidateEngineProviders() {
    ref.invalidate(audioEnginePreferenceProvider);
    ref.invalidate(uac2BitPerfectEnabledProvider);
    ref.invalidate(uac2ExclusiveDacModeProvider);
    ref.invalidate(killIsochronousUsbOnQuitProvider);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
