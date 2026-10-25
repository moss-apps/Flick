import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/features/settings/screens/uac2_preferences_screen.dart';
import 'package:flick/widgets/uac2/uac2_volume_control.dart';
import 'package:flick/widgets/uac2/uac2_hotplug_monitor.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/l10n/settings_l10n.dart';


class Uac2SettingsScreen extends ConsumerStatefulWidget {
  const Uac2SettingsScreen({super.key});

  @override
  ConsumerState<Uac2SettingsScreen> createState() => _Uac2SettingsScreenState();
}

class _Uac2SettingsScreenState extends ConsumerState<Uac2SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isAvailable = ref.watch(uac2AvailableProvider);
    final devicesAsync = ref.watch(uac2DevicesProvider);
    final selectedDevice = ref.watch(selectedUac2DeviceProvider);
    final deviceStatus = ref.watch(uac2DeviceStatusProvider);
    final currentSong = ref.watch(currentSongProvider);
    final appPreferences = ref.watch(appPreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
          Positioned.fill(
            child: AmbientBackground(song: currentSong),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: AppConstants.spacingMd),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isAvailable) _buildUnavailableCard(context),
                        if (isAvailable) ...[
                          const Uac2HotplugMonitor(),
                          _buildSectionHeader(context, l10n.englishForFilipino.usbAudioDevices),
                          devicesAsync.when(
                            data: (devices) => _buildDevicesList(
                              context,
                              devices,
                              selectedDevice,
                              deviceStatus,
                            ),
                            loading: () => _buildLoadingCard(context),
                            error: (error, _) => _buildErrorCard(context, error),
                          ),
                          if (selectedDevice != null) ...[
                            const SizedBox(height: AppConstants.spacingLg),
                            _buildSectionHeader(context, l10n.englishForFilipino.deviceInformation),
                            _buildDeviceInfoCard(context, selectedDevice),
                            const SizedBox(height: AppConstants.spacingLg),
                            _buildSectionHeader(context, l10n.englishForFilipino.capabilities),
                            _buildCapabilitiesCard(context, selectedDevice),
                          ],
                          if (deviceStatus != null) ...[
                            const SizedBox(height: AppConstants.spacingLg),
                            _buildSectionHeader(context, l10n.englishForFilipino.status),
                            _buildStatusCard(context, deviceStatus),
                          ],
                          if (deviceStatus != null &&
                              deviceStatus.state != Uac2State.idle &&
                              appPreferences.showUsbVolumeOnSettings) ...[
                            const SizedBox(height: AppConstants.spacingLg),
                            _buildSectionHeader(context, l10n.englishForFilipino.volumeControl),
                            const Uac2VolumeControl(),
                          ],

                        ],
                        const SizedBox(height: AppConstants.navBarHeight + 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.of(context).pop(),
            color: context.adaptiveTextPrimary,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              l10n.englishForFilipino.usbAudioUac2,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Uac2PreferencesScreen(),
                ),
              );
            },
            color: context.adaptiveTextPrimary,
            tooltip: l10n.preferences,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.spacingXs,
        bottom: AppConstants.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUnavailableCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: context.adaptiveTextSecondary,
            size: 24,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              l10n.uac2IsNotAvailableOnThis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              l10n.error(error),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList(
    BuildContext context,
    List<Uac2DeviceInfo> devices,
    Uac2DeviceInfo? selectedDevice,
    Uac2DeviceStatus? deviceStatus,
  ) {
    if (devices.isEmpty) {
      return _buildNoDevicesCard(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          ...devices.asMap().entries.map((entry) {
            final index = entry.key;
            final device = entry.value;
            final isSelected =
                selectedDevice?.vendorId == device.vendorId &&
                selectedDevice?.productId == device.productId &&
                selectedDevice?.serial == device.serial;
            return Column(
              children: [
                _buildDeviceItem(context, device, isSelected, deviceStatus),
                if (index < devices.length - 1) _buildDivider(),
              ],
            );
          }),
          _buildDivider(),
          _buildRefreshButton(context),
        ],
      ),
    );
  }

  Widget _buildNoDevicesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.usb_off, color: context.adaptiveTextTertiary, size: 48),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            l10n.noUsbAudioDevicesFound,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            l10n.connectAUsbDacOrAudio,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _buildRefreshButton(context),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context,
    Uac2DeviceInfo device,
    bool isSelected,
    Uac2DeviceStatus? deviceStatus,
  ) {
    final isConnected =
        isSelected &&
        (deviceStatus?.state == Uac2State.connected ||
            deviceStatus?.state == Uac2State.prewarming ||
            deviceStatus?.state == Uac2State.streaming);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleDeviceSelection(device, isSelected, isConnected),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            children: [
              Container(
                width: context.scaleSize(AppConstants.containerSizeSm),
                height: context.scaleSize(AppConstants.containerSizeSm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.glassBackgroundStrong
                      : AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  LucideIcons.usb,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${device.manufacturer} ${device.productName}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VID: 0x${device.vendorId.toRadixString(16).padLeft(4, '0')} '
                      'PID: 0x${device.productId.toRadixString(16).padLeft(4, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                if (isConnected)
                  _buildStatusBadge(context, deviceStatus!.state)
                else
                  Icon(
                    LucideIcons.check,
                    color: context.adaptiveTextPrimary,
                    size: 20,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, Uac2State state) {
    final color = _getStatusColor(state);
    final label = _getStatusLabel(state);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.invalidate(uac2DevicesProvider),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.refreshCw,
                color: context.adaptiveTextSecondary,
                size: 18,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                l10n.refreshDevices,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard(BuildContext context, Uac2DeviceInfo device) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            l10n.manufacturer,
            device.manufacturer.isNotEmpty ? device.manufacturer : l10n.unknown,
            LucideIcons.building,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.product,
            device.productName,
            LucideIcons.package,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.serialNumber,
            device.serial ?? 'N/A',
            LucideIcons.hash,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.vendorId,
            '0x${device.vendorId.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            LucideIcons.tag,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.productId,
            '0x${device.productId.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            LucideIcons.tag,
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard(BuildContext context, Uac2DeviceInfo device) {
    final capabilitiesAsync = ref.watch(uac2DeviceCapabilitiesProvider(device));

    return capabilitiesAsync.when(
      data: (capabilities) {
        if (capabilities == null) {
          return _buildCapabilitiesUnavailable(context);
        }
        return _buildCapabilitiesContent(context, capabilities);
      },
      loading: () => _buildLoadingCard(context),
      error: (error, _) => _buildErrorCard(context, error),
    );
  }

  Widget _buildCapabilitiesUnavailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        l10n.capabilitiesNotAvailable,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.adaptiveTextTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCapabilitiesContent(
    BuildContext context,
    Uac2DeviceCapabilities capabilities,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            l10n.deviceType,
            capabilities.deviceType,
            LucideIcons.cpu,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.sampleRates,
            capabilities.supportedSampleRates
                .map((r) => '${r ~/ 1000}kHz')
                .join(', '),
            LucideIcons.activity,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.bitDepths,
            capabilities.supportedBitDepths.map((d) => '${d}bit').join(', '),
            LucideIcons.layers,
          ),
          _buildDivider(),
          _buildInfoRow(
            context,
            l10n.channels,
            capabilities.supportedChannels
                .map(
                  (c) => c == 1
                      ? l10n.mono
                      : c == 2
                      ? l10n.stereo
                      : '$c ch',
                )
                .join(', '),
            LucideIcons.radio,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, Uac2DeviceStatus status) {
    final diagnostics = ref.watch(audioOutputDiagnosticsProvider);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            l10n.connectionStatus,
            _getStatusLabel(status.state),
            LucideIcons.activity,
            valueColor: _getStatusColor(status.state),
          ),
          if (status.routeType != Uac2RouteType.unknown) ...[
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.playbackPath,
              _getPlaybackPathLabel(status, diagnostics: diagnostics),
              Icons.alt_route,
            ),
          ],
          if (diagnostics != null) ...[
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.capabilityState,
              diagnostics.capabilityStateLabel,
              Icons.tune,
            ),
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.backend,
              diagnostics.backendDescription,
              Icons.memory,
            ),
          ],
          if (status.currentFormat != null) ...[
            _buildDivider(),
            _buildInfoRow(
              context,
              status.currentFormat!.isDsdStream ? l10n.trackDsdRate : l10n.trackSampleRate,
              status.currentFormat!.displayRateLabel,
              Icons.graphic_eq,
            ),
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.trackBitDepth,
              status.currentFormat!.bitDepthLabel,
              LucideIcons.layers,
            ),
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.trackChannels,
              status.currentFormat!.channels == 1
                  ? l10n.mono
                  : status.currentFormat!.channels == 2
                  ? l10n.stereo
                  : l10n.channels2(status.currentFormat!.channels),
              LucideIcons.radio,
            ),
            if (diagnostics != null) ...[
              _buildDivider(),
              _buildInfoRow(
                context,
                l10n.requestedOutputRate,
                diagnostics.requestedOutputSampleRate == null
                    ? l10n.unknown
                    : l10n.khz(diagnostics.requestedOutputSampleRate! ~/ 1000),
                Icons.speed,
              ),
              _buildDivider(),
              _buildInfoRow(
                context,
                l10n.reportedOutputRate,
                diagnostics.reportedOutputSampleRate == null
                    ? l10n.unreported
                    : l10n.khz(diagnostics.reportedOutputSampleRate! ~/ 1000),
                Icons.graphic_eq,
              ),
            ],
          ],
          if (diagnostics != null) ...[
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.mixerManagement,
              diagnostics.isMixerManaged
                  ? 'Android-managed'
                  : l10n.directUsbDeviceManaged,
              Icons.account_tree_outlined,
              valueColor: diagnostics.isMixerManaged
                  ? Colors.amber.shade300
                  : Colors.green.shade400,
            ),
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.dacClaim,
              diagnostics.directUsbRegistered
                  ? (diagnostics.usbInterfaceClaimed
                        ? l10n.claimedByFlick
                        : l10n.registeredNotClaimed)
                  : l10n.notRegistered,
              Icons.usb,
              valueColor: diagnostics.usbInterfaceClaimed
                  ? Colors.green.shade400
                  : Colors.amber.shade300,
            ),
            _buildDivider(),
            _buildInfoRow(
              context,
              l10n.audioFocus,
              diagnostics.audioFocusHeld ? l10n.held : l10n.notHeld,
              Icons.hearing,
              valueColor: diagnostics.audioFocusHeld
                  ? Colors.green.shade400
                  : Colors.amber.shade300,
            ),
          ],
          if (diagnostics != null &&
              diagnostics.verificationReason != null &&
              diagnostics.verificationReason != diagnostics.fallbackReason) ...[
            _buildDivider(),
            _buildWarningMessage(context, diagnostics.verificationReason!),
          ],
          if (diagnostics?.fallbackReason != null) ...[
            _buildDivider(),
            _buildWarningMessage(context, diagnostics!.fallbackReason!),
          ],
          if (diagnostics?.hardwareVolumeError != null) ...[
            _buildDivider(),
            _buildWarningMessage(
              context,
              l10n.usbHardwareVolumeError(diagnostics!.hardwareVolumeError!),
            ),
          ],
          if (status.warningMessage != null) ...[
            _buildDivider(),
            _buildWarningMessage(context, status.warningMessage!),
          ],
          if (status.compatibilityNotice != null) ...[
            _buildDivider(),
            _buildCompatibilityNotice(context, status.compatibilityNotice!),
          ],
          if (status.errorMessage != null) ...[
            _buildDivider(),
            _buildErrorMessage(context, status.errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningMessage(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade400, size: 20),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.amber.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityNotice(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: Colors.lightBlue.shade900.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: Colors.lightBlue.shade400.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.lightBlue.shade300, size: 20),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.lightBlue.shade200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
      child: Row(
        children: [
          Icon(icon, color: context.adaptiveTextSecondary, size: 20),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: AppColors.glassBorder);
  }

  void _handleDeviceSelection(
    Uac2DeviceInfo device,
    bool isSelected,
    bool isConnected,
  ) async {
    final deviceStatusNotifier = ref.read(uac2DeviceStatusProvider.notifier);

    if (isConnected) {
      await deviceStatusNotifier.disconnect();
    } else {
      ref.read(selectedUac2DeviceProvider.notifier).select(device);
      await deviceStatusNotifier.selectDevice(device);
    }
  }

  Color _getStatusColor(Uac2State state) {
    switch (state) {
      case Uac2State.idle:
        return Colors.grey;
      case Uac2State.connecting:
        return Colors.orange;
      case Uac2State.connected:
        return Colors.blue;
      case Uac2State.prewarming:
        return Colors.amber;
      case Uac2State.streaming:
        return Colors.green;
      case Uac2State.error:
        return Colors.red;
    }
  }

  String _getStatusLabel(Uac2State state) {
    switch (state) {
      case Uac2State.idle:
        return l10n.idle;
      case Uac2State.connecting:
        return l10n.connecting;
      case Uac2State.connected:
        return l10n.connected;
      case Uac2State.prewarming:
        return l10n.prewarming;
      case Uac2State.streaming:
        return l10n.streaming;
      case Uac2State.error:
        return l10n.error3;
    }
  }

  String _getPlaybackPathLabel(
    Uac2DeviceStatus status, {
    AudioOutputDiagnostics? diagnostics,
  }) {
    if (diagnostics != null) {
      return diagnostics.capabilityStateLabel;
    }

    switch (status.routeType) {
      case Uac2RouteType.internalDac:
        return l10n.deviceDac;
      case Uac2RouteType.externalUsb:
        return l10n.androidUsbRoute;
      case Uac2RouteType.wired:
        return l10n.wiredOutput;
      case Uac2RouteType.bluetooth:
        return l10n.bluetoothOutput;
      case Uac2RouteType.dock:
        return l10n.androidDockRoute;
      case Uac2RouteType.unknown:
        return status.routeLabel ?? l10n.unknown;
    }
  }
}
