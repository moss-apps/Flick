import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/features/settings/screens/uac2_settings_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
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
