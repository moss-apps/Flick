import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/uac2_provider.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/widgets/common/glass_dialog.dart';

/// Pure gate: prompt only for an external USB route in a live state while
/// bit-perfect is off.
bool shouldPromptBitPerfect(
  Uac2DeviceStatus status, {
  required bool bitPerfectEnabled,
}) {
  if (bitPerfectEnabled) return false;
  if (status.routeType != Uac2RouteType.externalUsb &&
      !status.isExternalRoute) {
    return false;
  }
  return switch (status.state) {
    Uac2State.connected || Uac2State.prewarming || Uac2State.streaming => true,
    _ => false,
  };
}

/// Stable per-device identity so one DAC prompts at most once per session.
String usbDevicePromptKey(Uac2DeviceInfo device) =>
    '${device.vendorId}:${device.productId}:${device.serial ?? device.deviceName}';

/// Auto-detects a connected USB DAC and offers a one-tap switch to
/// Bit-perfect (USB DAC) mode. Renders nothing; mount once in the shell.
class UsbBitPerfectPrompt extends ConsumerStatefulWidget {
  const UsbBitPerfectPrompt({super.key});

  @override
  ConsumerState<UsbBitPerfectPrompt> createState() =>
      _UsbBitPerfectPromptState();
}

class _UsbBitPerfectPromptState extends ConsumerState<UsbBitPerfectPrompt> {
  // ponytail: session-only decline memory; persistent "don't ask again" pref
  // if nagging complaints arrive
  final Set<String> _promptedDevices = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      uac2DeviceStatusProvider,
      (_, next) {
        if (next != null) _maybePrompt(next);
      },
      fireImmediately: true,
    );
  }

  Future<void> _maybePrompt(Uac2DeviceStatus status) async {
    if (!mounted) return;
    if (!shouldPromptBitPerfect(
      status,
      bitPerfectEnabled: ref.read(uac2ServiceProvider).isBitPerfectEnabledSync,
    )) {
      return;
    }

    if (!_promptedDevices.add(usbDevicePromptKey(status.device))) return;

    final AudioEnginePreference engine;
    try {
      engine = await ref
          .read(uac2PreferencesServiceProvider)
          .getAudioEnginePreference();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _showPrompt(status, switchEngine: engine != AudioEnginePreference.isochronousUsb);
  }

  Future<void> _showPrompt(
    Uac2DeviceStatus status, {
    required bool switchEngine,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => GlassDialog(
        title: 'USB DAC detected',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${status.device.productName} is connected.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              switchEngine
                  ? "Switch to the Bit-perfect (USB DAC) engine? Flick takes exclusive control of the USB path and bypasses Android's audio processing for unaltered sound."
                  : 'Enable Bit-perfect (USB DAC) mode? Flick takes exclusive control of the USB path for unaltered sound.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    if (switchEngine) {
      await ref
          .read(playerServiceProvider)
          .setAudioEnginePreference(AudioEnginePreference.isochronousUsb);
    }
    final applied =
        await ref.read(uac2ServiceProvider).setBitPerfectEnabled(true);
    ref.invalidate(audioEnginePreferenceProvider);
    ref.invalidate(uac2BitPerfectEnabledProvider);
    ref.invalidate(uac2ExclusiveDacModeProvider);
    ref.invalidate(killIsochronousUsbOnQuitProvider);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            applied
                ? 'Bit-perfect (USB DAC) enabled. Restart the app to apply playback changes.'
                : 'Bit-perfect (USB DAC) could not be enabled. Check the USB diagnostics for the failure reason.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
