import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/services/bluetooth_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';

class BluetoothSettingsScreen extends ConsumerStatefulWidget {
  const BluetoothSettingsScreen({super.key});

  @override
  ConsumerState<BluetoothSettingsScreen> createState() =>
      _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState
    extends ConsumerState<BluetoothSettingsScreen> {
  final _bt = BluetoothService.instance;
  final _uac2Prefs = Uac2PreferencesService();
  PermissionStatus _permStatus = PermissionStatus.denied;
  List<BluetoothDeviceDto> _devices = const [];
  final Map<String, BluetoothCodecStatusDto?> _codecs = {};
  final Map<String, int?> _batteries = {};
  StreamSubscription<Map<Object?, Object?>>? _btSub;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _btSub = _bt.deviceEvents.listen((_) => _refreshDevices());
  }

  @override
  void dispose() {
    _btSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.bluetoothConnect.status;
    if (!mounted) return;
    setState(() => _permStatus = status);
    if (status.isGranted) _refreshDevices();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.bluetoothConnect.request();
    if (!mounted) return;
    setState(() => _permStatus = status);
    if (status.isGranted) _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    if (_refreshing) return;
    _refreshing = true;
    final devices = await _bt.getConnectedDevices();
    if (!mounted) {
      _refreshing = false;
      return;
    }
    setState(() {
      _devices = devices;
      _codecs.clear();
      _batteries.clear();
    });
    for (final d in devices) {
      if (d.isA2dp) {
        final codec = await _bt.getCodecStatus(d.address);
        if (mounted) setState(() => _codecs[d.address] = codec);
      }
      final battery = await _bt.getBatteryLevel(d.address);
      if (mounted) setState(() => _batteries[d.address] = battery);
    }
    _refreshing = false;
  }

  BluetoothDeviceDto? get _targetDevice =>
      _devices.firstWhere(
        (d) => d.address == ref.read(appPreferencesProvider).preferredBluetoothDevice,
        orElse: () => _devices.firstWhere((d) => d.isA2dp, orElse: () => _devices.first),
      );

  List<Widget> _withDividers(List<Widget> rows) {
    if (rows.length <= 1) return rows;
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SettingsDivider(),
        rows[i],
      ],
    ];
  }

  String _deviceSubtitle(BluetoothDeviceDto d) {
    final parts = <String>[if (d.isA2dp) 'A2DP' else 'Connected'];
    final codec = _codecs[d.address];
    if (codec != null) parts.add(codec.codecName);
    if (codec?.sampleRate != null) parts.add('${codec!.sampleRate} Hz');
    final battery = _batteries[d.address];
    if (battery != null) parts.add('$battery% battery');
    return parts.join(' \u2022 ');
  }

  Future<void> _onCodecSelected(int codecType) async {
    ref.read(appPreferencesProvider.notifier).setBtPreferredCodec(codecType);
    final target = _targetDevice;
    if (target != null) {
      final prefs = ref.read(appPreferencesProvider);
      final ldacBr = codecType == BluetoothCodecType.ldac
          ? _ldacBitrateToInt(_parseLdacBitrate(prefs.btLdacBitrate))
          : 0;
      await _bt.setCodecConfig(
        address: target.address,
        codecType: codecType,
        ldacBitrate: ldacBr,
      );
    }
  }

  Future<void> _onLdacBitrateSelected(BtLdacBitrate bitrate) async {
    ref.read(appPreferencesProvider.notifier).setBtLdacBitrate(bitrate.name);
    final target = _targetDevice;
    if (target != null) {
      await _bt.setCodecConfig(
        address: target.address,
        codecType: BluetoothCodecType.ldac,
        ldacBitrate: _ldacBitrateToInt(bitrate),
      );
    }
  }

  Future<void> _onAbsoluteVolumeChanged(bool enabled) async {
    ref.read(appPreferencesProvider.notifier).setBtAbsoluteVolumeSync(enabled);
    for (final d in _devices) {
      await _bt.setAbsoluteVolumeEnabled(d.address, enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appPrefs = ref.watch(appPreferencesProvider);
    final hasPermission = _permStatus.isGranted;
    final currentLdac = _parseLdacBitrate(appPrefs.btLdacBitrate);

    return SettingsScaffold(
      title: 'Bluetooth',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasPermission) ...[
            const SettingsSectionHeader('Permission'),
            SettingsCard(
              children: [
                ActionButton(
                  icon: LucideIcons.shieldCheck,
                  title: 'Grant Bluetooth access',
                  subtitle:
                      'Required to detect devices, codecs, and battery levels',
                  onTap: _requestPermission,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingLg),
          ],
          const SettingsSectionHeader('Disconnect Behavior'),
          SettingsCard(
            children: _withDividers([
              ToggleSetting(
                icon: LucideIcons.bluetooth,
                title: 'Pause on Disconnect',
                subtitle: appPrefs.pauseOnBluetoothDisconnect
                    ? 'Playback pauses when Bluetooth or headphones disconnect'
                    : 'Playback continues when audio output disconnects',
                value: appPrefs.pauseOnBluetoothDisconnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setPauseOnBluetoothDisconnect(v),
              ),
              ToggleSetting(
                icon: LucideIcons.play,
                title: 'Resume on Reconnect',
                subtitle: appPrefs.resumeOnBluetoothReconnect
                    ? 'Playback resumes when a device reconnects within 30 seconds'
                    : 'Keep playback paused when a device reconnects',
                value: appPrefs.resumeOnBluetoothReconnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setResumeOnBluetoothReconnect(v),
              ),
            ]),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (hasPermission && _devices.isNotEmpty) ...[
            const SettingsSectionHeader('Connected Devices'),
            SettingsCard(
              children: _withDividers([
                SelectionSetting(
                  icon: LucideIcons.bluetooth,
                  title: 'Automatic',
                  subtitle: 'Let Android choose the output device',
                  selected: appPrefs.preferredBluetoothDevice.isEmpty,
                  onTap: () => ref
                      .read(appPreferencesProvider.notifier)
                      .setPreferredBluetoothDevice(''),
                ),
                ..._devices.map(
                  (d) => SelectionSetting(
                    icon: LucideIcons.headphones,
                    title: d.name,
                    subtitle: _deviceSubtitle(d),
                    selected:
                        appPrefs.preferredBluetoothDevice == d.address,
                    onTap: () => ref
                        .read(appPreferencesProvider.notifier)
                        .setPreferredBluetoothDevice(d.address),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppConstants.spacingLg),
          ],
          const SettingsSectionHeader('Codec \u0026 Audio', tag: 'Experimental'),
          SettingsCard(
            children: _withDividers([
              ..._codecOptions.map(
                (ct) => SelectionSetting(
                  icon: LucideIcons.audioWaveform,
                  title: _codecLabel(ct),
                  subtitle: _codecDescription(ct),
                  selected: appPrefs.btPreferredCodec == ct,
                  onTap: () => _onCodecSelected(ct),
                ),
              ),
              if (appPrefs.btPreferredCodec == BluetoothCodecType.ldac)
                ...BtLdacBitrate.values.map(
                  (b) => SelectionSetting(
                    icon: LucideIcons.gauge,
                    title: _ldacBitrateLabel(b),
                    subtitle: _ldacBitrateDescription(b),
                    selected: currentLdac == b,
                    onTap: () => _onLdacBitrateSelected(b),
                  ),
                ),
              ToggleSetting(
                icon: LucideIcons.volume2,
                title: 'Absolute Volume Sync',
                subtitle: appPrefs.btAbsoluteVolumeSync
                    ? 'Phone and headset volume are linked'
                    : 'Phone and headset volume are independent',
                value: appPrefs.btAbsoluteVolumeSync,
                onChanged: _onAbsoluteVolumeChanged,
              ),
            ]),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Output Mode', tag: 'Experimental'),
          SettingsCard(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable:
                    Uac2PreferencesService.btLowLatencyModeNotifier,
                builder: (context, lowLatency, _) {
                  return ToggleSetting(
                    icon: LucideIcons.zap,
                    title: 'Low-latency Mode',
                    subtitle: lowLatency
                        ? 'Routes Bluetooth through the Rust engine'
                        : 'Standard Bluetooth routing via Android',
                    value: lowLatency,
                    onChanged: (v) => _uac2Prefs.setBtLowLatencyMode(v),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Codec Info'),
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
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

const _codecOptions = <int>[
  -1,
  BluetoothCodecType.sbc,
  BluetoothCodecType.aac,
  BluetoothCodecType.aptx,
  BluetoothCodecType.aptxHd,
  BluetoothCodecType.aptxAdaptive,
  BluetoothCodecType.ldac,
];

String _codecLabel(int ct) =>
    ct < 0 ? 'Automatic' : BluetoothCodecType.label(ct);

String _codecDescription(int ct) => switch (ct) {
      -1 => 'Let Android choose the best codec',
      BluetoothCodecType.sbc => 'Universal compatibility',
      BluetoothCodecType.aac => 'High quality, widely supported',
      BluetoothCodecType.aptx => 'Low latency, good quality',
      BluetoothCodecType.aptxHd => 'High-resolution aptX',
      BluetoothCodecType.aptxAdaptive => 'Variable bitrate, low latency',
      BluetoothCodecType.ldac => 'Highest bitrate (up to 990 kbps)',
      _ => '',
    };

BtLdacBitrate _parseLdacBitrate(String name) =>
    BtLdacBitrate.values.firstWhere(
      (b) => b.name == name,
      orElse: () => BtLdacBitrate.adaptive,
    );

int _ldacBitrateToInt(BtLdacBitrate b) => switch (b) {
      BtLdacBitrate.adaptive => 0,
      BtLdacBitrate.kbps330 => 330,
      BtLdacBitrate.kbps660 => 660,
      BtLdacBitrate.kbps990 => 990,
    };

String _ldacBitrateLabel(BtLdacBitrate b) => switch (b) {
      BtLdacBitrate.adaptive => 'LDAC Adaptive',
      BtLdacBitrate.kbps330 => 'LDAC 330 kbps',
      BtLdacBitrate.kbps660 => 'LDAC 660 kbps',
      BtLdacBitrate.kbps990 => 'LDAC 990 kbps',
    };

String _ldacBitrateDescription(BtLdacBitrate b) => switch (b) {
      BtLdacBitrate.adaptive => 'Bitrate adjusts to signal quality',
      BtLdacBitrate.kbps330 => 'Prioritise connection stability',
      BtLdacBitrate.kbps660 => 'Balanced quality and stability',
      BtLdacBitrate.kbps990 => 'Maximum audio quality',
    };

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
            'Flick can attempt to prefer a specific codec above, but success depends on your device, headset, and Android version. Codec forcing uses a hidden system API and may not work on non-rooted devices.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'You can also change the codec in Android Developer Options under "Bluetooth Audio Codec".',
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
