import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/features/settings/screens/uac2_settings_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/android_audio_device_service.dart';
// TODO: crossfade disabled for this version
// import 'package:flick/core/utils/app_haptics.dart';
// import 'package:flick/providers/app_preferences_provider.dart';
// import 'package:flick/services/rust_audio_service.dart';
// import 'package:flick/src/rust/api/audio_api.dart' as rust_audio;

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() =>
      _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {
  // TODO: crossfade disabled for this version
  // final _rustAudioService = RustAudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AndroidAudioDeviceService.instance.refresh();
    });
  }

  // static const _curveLabels = <String>[
  //   'Equal Power',
  //   'Linear',
  //   'Square Root',
  //   'S-Curve',
  // ];

  // static const _curveValues = <rust_audio.CrossfadeCurveType>[
  //   rust_audio.CrossfadeCurveType.equalPower,
  //   rust_audio.CrossfadeCurveType.linear,
  //   rust_audio.CrossfadeCurveType.squareRoot,
  //   rust_audio.CrossfadeCurveType.sCurve,
  // ];

  // Future<void> _applyCrossfade() async {
  //   final prefs = ref.read(appPreferencesProvider);
  //   await _rustAudioService.setCrossfade(
  //     enabled: prefs.crossfadeEnabled,
  //     durationSecs: prefs.crossfadeDurationSecs,
  //   );
  //   final curve = _curveValues[prefs.crossfadeCurveIndex.clamp(
  //     0,
  //     _curveValues.length - 1,
  //   )];
  //   await _rustAudioService.setCrossfadeCurve(curve);
  // }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Audio',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Audio'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.usb,
                title: 'USB Audio (UAC2)',
                subtitle: 'Configure USB DAC/AMP devices',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Uac2SettingsScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.slidersHorizontal,
                title: 'Equalizer',
                subtitle: 'Adjust audio frequencies',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EqualizerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Bluetooth Audio'),
          SettingsCard(
            children: [
              ValueListenableBuilder<AndroidPlaybackDeviceInfo>(
                valueListenable:
                    AndroidAudioDeviceService.instance.deviceInfoNotifier,
                builder: (context, deviceInfo, _) {
                  return _BluetoothCodecInfo(deviceInfo: deviceInfo);
                },
              ),
            ],
          ),
          // TODO: crossfade disabled for this version
          // const SizedBox(height: AppConstants.spacingLg),
          // const SettingsSectionHeader('Crossfade'),
          // SettingsCard(
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _BluetoothCodecInfo extends StatelessWidget {
  const _BluetoothCodecInfo({required this.deviceInfo});

  final AndroidPlaybackDeviceInfo deviceInfo;

  @override
  Widget build(BuildContext context) {
    final currentRouteLabel = deviceInfo.isBluetoothRoute
        ? 'Current route: ${deviceInfo.routeSummary}. Android is handling codec negotiation right now.'
        : 'When you play over Bluetooth, Android negotiates the codec with your headphones or speaker.';

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundStrong,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(
                  LucideIcons.bluetooth,
                  color: context.adaptiveTextSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth codec info',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentRouteLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: const [
              _CodecChip('SBC'),
              _CodecChip('AAC'),
              _CodecChip('aptX'),
              _CodecChip('aptX HD'),
              _CodecChip('aptX Adaptive'),
              _CodecChip('LDAC'),
              _CodecChip('LC3'),
              _CodecChip('LHDC'),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'Flick does not force Bluetooth codecs itself. The active codec depends on Android, your phone, your headset, signal quality, and any Bluetooth developer settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'If you want to prefer AAC, SBC, aptX, LDAC, or another supported codec, change it in Android Bluetooth settings or Developer Options when your device allows it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodecChip extends StatelessWidget {
  const _CodecChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.adaptiveTextSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
