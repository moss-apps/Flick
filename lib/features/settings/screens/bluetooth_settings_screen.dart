import 'dart:async';
import 'package:flick/widgets/common/flick_snackbar.dart';

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
import 'package:flick/l10n/settings_l10n.dart';

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
    final devices = await _bt.getBondedDevices();
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
      if (d.isA2dp && d.isConnected) {
        final codec = await _bt.getCodecStatus(d.address);
        if (mounted) setState(() => _codecs[d.address] = codec);
      }
      final battery = await _bt.getBatteryLevel(d.address);
      if (mounted) setState(() => _batteries[d.address] = battery);
    }
    _refreshing = false;
  }

  BluetoothDeviceDto? get _targetDevice {
    final pref = ref.read(appPreferencesProvider).preferredBluetoothDevice;
    BluetoothDeviceDto? byAddress(bool Function(BluetoothDeviceDto) test) =>
        _devices.where(test).firstOrNull;
    // preferred + connected first, then any connected A2DP, then preferred, then first.
    return byAddress((d) => d.address == pref && d.isConnected && d.isA2dp) ??
        byAddress((d) => d.isConnected && d.isA2dp) ??
        byAddress((d) => d.address == pref) ??
        byAddress((d) => d.isA2dp) ??
        (_devices.isEmpty ? null : _devices.first);
  }

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
    final parts = <String>[
      if (d.isConnected) l10n.connected else l10n.paired,
      if (d.isA2dp) 'A2DP',
    ];
    final codec = _codecs[d.address];
    if (codec != null) parts.add(codec.codecName);
    if (codec?.sampleRate != null) parts.add(l10n.hz6(codec!.sampleRate!));
    final battery = _batteries[d.address];
    if (battery != null) parts.add(l10n.battery(battery));
    return parts.join(' \u2022 ');
  }

  /// Push the full codec configuration to the target device.
  Future<void> _applyCurrentCodec({int? overrideCodec}) async {
    final target = _targetDevice;
    if (target == null) return;
    final prefs = ref.read(appPreferencesProvider);
    final codecType = overrideCodec ?? prefs.btPreferredCodec;
    if (codecType < 0) return;
    final isLdac = codecType == BluetoothCodecType.ldac;
    final result = await _bt.setCodecConfig(
      address: target.address,
      codecType: codecType,
      sampleRate: prefs.btSampleRate,
      bitsPerSample: isLdac ? prefs.btLdacBitsPerSample : 0,
      ldacBitrate: isLdac
          ? BtLdacBitrate.fromName(prefs.btLdacBitrate).kbps
          : 0,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (result.ok) {
      messenger.showFlickSnackBar(
        SnackBar(
          content: Text(l10n.codecApplied(BluetoothCodecType.label(codecType))),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showFlickSnackBar(
        SnackBar(
          content: Text(
            l10n.codecForcingUnavailableOnThisDevice,
          ),
          action: SnackBarAction(
            label: l10n.englishForFilipino.open,
            onPressed: () => _bt.openBluetoothCodecSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _openBluetoothCodecSettings() async {
    final ok = await _bt.openBluetoothCodecSettings();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!ok && messenger != null) {
      messenger.showFlickSnackBar(
        SnackBar(
          content: Text(
            l10n.developerOptionsIsDisabledEnableIt,
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _onCodecControlEnabled(bool enabled) async {
    await ref.read(appPreferencesProvider.notifier).setBtEnableCodecControl(enabled);
    if (enabled) await _applyCurrentCodec();
  }

  Future<void> _onCodecSelected(int codecType) async {
    await ref.read(appPreferencesProvider.notifier).setBtPreferredCodec(codecType);
    await _applyCurrentCodec(overrideCodec: codecType);
  }

  Future<void> _onSampleRateSelected(int bitmask) async {
    await ref.read(appPreferencesProvider.notifier).setBtSampleRate(bitmask);
    await _applyCurrentCodec();
  }

  Future<void> _onLdacBitsSelected(int bitmask) async {
    await ref
        .read(appPreferencesProvider.notifier)
        .setBtLdacBitsPerSample(bitmask);
    await _applyCurrentCodec();
  }

  Future<void> _onLdacBitrateSelected(BtLdacBitrate bitrate) async {
    await ref.read(appPreferencesProvider.notifier).setBtLdacBitrate(bitrate.name);
    await _applyCurrentCodec();
  }

  Future<void> _onAbsoluteVolumeChanged(bool enabled) async {
    ref.read(appPreferencesProvider.notifier).setBtAbsoluteVolumeSync(enabled);
    for (final d in _devices.where((d) => d.isConnected)) {
      await _bt.setAbsoluteVolumeEnabled(d.address, enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appPrefs = ref.watch(appPreferencesProvider);
    final hasPermission = _permStatus.isGranted;
    final currentLdac = BtLdacBitrate.fromName(appPrefs.btLdacBitrate);
    final codecControlOn = appPrefs.btEnableCodecControl;
    final isLdac = appPrefs.btPreferredCodec == BluetoothCodecType.ldac;

    return SettingsScaffold(
      title: l10n.englishForFilipino.bluetooth,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasPermission) ...[
            SettingsSectionHeader(l10n.englishForFilipino.permission),
            SettingsCard(
              children: [
                ActionButton(
                  icon: LucideIcons.shieldCheck,
                  title: l10n.englishForFilipino.grantBluetoothAccess,
                  subtitle:
                      l10n.requiredToDetectDevicesCodecsAnd,
                  onTap: _requestPermission,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingLg),
          ],
          SettingsSectionHeader(l10n.englishForFilipino.connectionBehavior),
          SettingsCard(
            children: _withDividers([
              ToggleSetting(
                icon: LucideIcons.bluetooth,
                title: l10n.englishForFilipino.pauseOnDisconnect,
                subtitle: appPrefs.pauseOnBluetoothDisconnect
                    ? l10n.playbackPausesWhenBluetoothOrHeadphones
                    : l10n.playbackContinuesWhenAudioOutput,
                value: appPrefs.pauseOnBluetoothDisconnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setPauseOnBluetoothDisconnect(v),
              ),
              ToggleSetting(
                icon: LucideIcons.bluetoothConnected,
                title: l10n.englishForFilipino.pauseOnBluetoothConnect,
                subtitle: appPrefs.pauseOnBluetoothConnect
                    ? l10n.playbackPausesWhenABluetoothAudio
                    : l10n.playbackContinuesWhenABluetoothDevice,
                value: appPrefs.pauseOnBluetoothConnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setPauseOnBluetoothConnect(v),
              ),
              ToggleSetting(
                icon: LucideIcons.play,
                title: l10n.englishForFilipino.resumeOnReconnect,
                subtitle: appPrefs.resumeOnBluetoothReconnect
                    ? l10n.playbackResumesWhenADeviceReconnects
                    : l10n.keepPlaybackPausedWhenADevice,
                value: appPrefs.resumeOnBluetoothReconnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setResumeOnBluetoothReconnect(v),
              ),
              ToggleSetting(
                icon: LucideIcons.usb,
                title: l10n.englishForFilipino.pauseOnUsbDacAttach,
                subtitle: appPrefs.pauseOnUsbDacConnect
                    ? l10n.playbackPausesWhenAUsbDac
                    : l10n.playbackContinuesWhenAUsbDac,
                value: appPrefs.pauseOnUsbDacConnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setPauseOnUsbDacConnect(v),
              ),
              ToggleSetting(
                icon: LucideIcons.usb,
                title: l10n.englishForFilipino.pauseOnUsbDacDetach,
                subtitle: appPrefs.pauseOnUsbDacDisconnect
                    ? l10n.playbackPausesWhenAUsbDac2
                    : l10n.playbackContinuesWhenAUsbDac2,
                value: appPrefs.pauseOnUsbDacDisconnect,
                onChanged: (v) => ref
                    .read(appPreferencesProvider.notifier)
                    .setPauseOnUsbDacDisconnect(v),
              ),
            ]),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (hasPermission && _devices.isNotEmpty) ...[
            SettingsSectionHeader(l10n.englishForFilipino.devices),
            SettingsCard(
              children: _withDividers([
                SelectionSetting(
                  icon: LucideIcons.bluetooth,
                  title: l10n.englishForFilipino.automatic,
                  subtitle: l10n.letAndroidChooseTheOutputDevice,
                  selected: appPrefs.preferredBluetoothDevice.isEmpty,
                  onTap: () => ref
                      .read(appPreferencesProvider.notifier)
                      .setPreferredBluetoothDevice(''),
                ),
                ..._devices.map(
                  (d) => SelectionSetting(
                    icon: d.isConnected
                        ? LucideIcons.headphones
                        : LucideIcons.bluetooth,
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
          SettingsSectionHeader(l10n.englishForFilipino.codecU0026Audio, tag: l10n.englishForFilipino.experimental),
          SettingsCard(
            children: _withDividers([
              ToggleSetting(
                icon: LucideIcons.slidersHorizontal,
                title: l10n.englishForFilipino.codecControl,
                subtitle: codecControlOn
                    ? l10n.flickWillForceYourChosenCodec
                    : l10n.letAndroidNegotiateTheCodecAutomatically,
                value: codecControlOn,
                onChanged: _onCodecControlEnabled,
              ),
              if (codecControlOn) ...[
                ActionButton(
                  icon: LucideIcons.externalLink,
                  title: l10n.englishForFilipino.openBluetoothCodecSettings,
                  subtitle: l10n.androidDeveloperOptionsTheReliableWay,
                  onTap: _openBluetoothCodecSettings,
                ),
                ..._codecOptions.map(
                  (ct) => SelectionSetting(
                    icon: LucideIcons.audioWaveform,
                    title: _codecLabel(ct),
                    subtitle: _codecDescription(ct),
                    selected: appPrefs.btPreferredCodec == ct,
                    onTap: () => _onCodecSelected(ct),
                  ),
                ),
                ...BtSampleRate.entries.map(
                  (e) => SelectionSetting(
                    icon: LucideIcons.music,
                    title: e.$2,
                    subtitle: l10n.sampleRate,
                    selected: appPrefs.btSampleRate == e.$1,
                    onTap: () => _onSampleRateSelected(e.$1),
                  ),
                ),
                if (isLdac) ...[
                  ...BtBitsPerSample.entries.map(
                    (e) => SelectionSetting(
                      icon: LucideIcons.bitcoin,
                      title: e.$2,
                      subtitle: l10n.ldacBitsPerSample,
                      selected: appPrefs.btLdacBitsPerSample == e.$1,
                      onTap: () => _onLdacBitsSelected(e.$1),
                    ),
                  ),
                  ...BtLdacBitrate.values.map(
                    (b) => SelectionSetting(
                      icon: LucideIcons.gauge,
                      title: _ldacBitrateLabel(b),
                      subtitle: _ldacBitrateDescription(b),
                      selected: currentLdac == b,
                      onTap: () => _onLdacBitrateSelected(b),
                    ),
                  ),
                ],
              ],
              ToggleSetting(
                icon: LucideIcons.volume2,
                title: l10n.englishForFilipino.absoluteVolumeSync,
                subtitle: appPrefs.btAbsoluteVolumeSync
                    ? l10n.phoneAndHeadsetVolumeAreLinked
                    : l10n.phoneAndHeadsetVolumeAreIndependent,
                value: appPrefs.btAbsoluteVolumeSync,
                onChanged: _onAbsoluteVolumeChanged,
              ),
            ]),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.outputMode, tag: l10n.englishForFilipino.experimental),
          SettingsCard(
            children: _withDividers([
              ValueListenableBuilder<bool>(
                valueListenable:
                    Uac2PreferencesService.btHiResDirectNotifier,
                builder: (context, hiRes, _) {
                  return ToggleSetting(
                    icon: LucideIcons.gem,
                    title: l10n.englishForFilipino.hiResDirect,
                    subtitle: hiRes
                        ? l10n.routesBluetoothThroughTheHiRes
                        : l10n.standardBluetoothRoutingViaAndroid,
                    value: hiRes,
                    onChanged: (v) => _uac2Prefs.setBtHiResDirect(v),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable:
                    Uac2PreferencesService.btLowLatencyModeNotifier,
                builder: (context, lowLatency, _) {
                  return ToggleSetting(
                    icon: LucideIcons.zap,
                    title: l10n.englishForFilipino.lowLatencyMode,
                    subtitle: lowLatency
                        ? l10n.routesBluetoothThroughTheRustEngine
                        : l10n.standardBluetoothRoutingViaAndroid,
                    value: lowLatency,
                    onChanged: (v) => _uac2Prefs.setBtLowLatencyMode(v),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.codecInfo),
          SettingsCard(
            children: [
              ValueListenableBuilder<AndroidPlaybackDeviceInfo>(
                valueListenable:
                    AndroidAudioDeviceService.instance.deviceInfoNotifier,
                builder: (context, deviceInfo, _) {
                  final target = _targetDevice;
                  final negotiated = target == null
                      ? null
                      : _codecs[target.address];
                  return _BluetoothCodecInfo(
                    deviceInfo: deviceInfo,
                    negotiated: negotiated,
                  );
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
    ct < 0 ? l10n.englishForFilipino.automatic : BluetoothCodecType.label(ct);

String _codecDescription(int ct) => switch (ct) {
      -1 => l10n.letAndroidChooseTheBestCodec,
      BluetoothCodecType.sbc => l10n.universalCompatibility,
      BluetoothCodecType.aac => l10n.highQualityWidelySupported,
      BluetoothCodecType.aptx => l10n.lowLatencyGoodQuality,
      BluetoothCodecType.aptxHd => l10n.highResolutionAptx,
      BluetoothCodecType.aptxAdaptive => l10n.variableBitrateLowLatency,
      BluetoothCodecType.ldac => l10n.highestBitrateUpTo990Kbps,
      _ => '',
    };

String _ldacBitrateLabel(BtLdacBitrate b) => switch (b) {
      BtLdacBitrate.adaptive => l10n.ldacAdaptive,
      BtLdacBitrate.kbps330 => l10n.ldac330Kbps,
      BtLdacBitrate.kbps660 => l10n.ldac660Kbps,
      BtLdacBitrate.kbps990 => l10n.ldac990Kbps,
    };

String _ldacBitrateDescription(BtLdacBitrate b) => switch (b) {
      BtLdacBitrate.adaptive => l10n.bitrateAdjustsToSignalQuality,
      BtLdacBitrate.kbps330 => l10n.prioritiseConnectionStability,
      BtLdacBitrate.kbps660 => l10n.balancedQualityAndStability,
      BtLdacBitrate.kbps990 => l10n.maximumAudioQuality,
    };

class _BluetoothCodecInfo extends StatelessWidget {
  const _BluetoothCodecInfo({required this.deviceInfo, this.negotiated});

  final AndroidPlaybackDeviceInfo deviceInfo;
  final BluetoothCodecStatusDto? negotiated;

  @override
  Widget build(BuildContext context) {
    final negotiatedLine = StringBuffer();
    if (negotiated != null) {
      negotiatedLine.write(l10n.negotiated(negotiated!.codecName));
      if (negotiated!.sampleRate != null) {
        negotiatedLine.write(' \u2022 ${_formatHz(negotiated!.sampleRate!)}');
      }
      if (negotiated!.bitsPerSample != null) {
        negotiatedLine.write(l10n.u2022Bit(negotiated!.bitsPerSample!));
      }
    }
    final currentRouteLabel = deviceInfo.isBluetoothRoute
        ? l10n.currentRoute(deviceInfo.routeSummary)
        : l10n.whenYouPlayOverBluetoothAndroid;

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
                      l10n.englishForFilipino.bluetoothCodecInfo,
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
                    if (negotiatedLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        negotiatedLine.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: [
              _CodecChip('SBC'),
              _CodecChip('AAC'),
              _CodecChip('aptX'),
              _CodecChip(l10n.aptxHd),
              _CodecChip(l10n.aptxAdaptive),
              _CodecChip('LDAC'),
              _CodecChip('LC3'),
              _CodecChip('LHDC'),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            l10n.flickCanAttemptToPreferA,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            l10n.youCanAlsoChangeTheCodec,
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

String _formatHz(int hz) {
  if (hz >= 1000) {
    final khz = hz / 1000.0;
    return '${khz.toStringAsFixed(khz == khz.roundToDouble() ? 1 : 1)} kHz';
  }
  return l10n.hz3(hz);
}
