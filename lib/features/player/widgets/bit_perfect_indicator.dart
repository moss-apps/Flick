import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Compact bit-perfect indicator capsule for the player file-info row.
///
/// Shows HQ/SD with color-coded status based on the active audio path.
/// Tapping opens a detailed bottom sheet with diagnostics.
class BitPerfectIndicator extends ConsumerWidget {
  final Song song;
  final PlayerService playerService;
  final VoidCallback? onTap;

  const BitPerfectIndicator({
    super.key,
    required this.song,
    required this.playerService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(audioOutputDiagnosticsProvider);
    final prefs = ref.watch(appPreferencesProvider);

    final state = _resolveState(
      diagnostics,
      suppressVerified: prefs.replaceAlbumWithBitPerfectCapsule,
    );
    final label = _getSongQuality(song);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsive(4.0, 5.0, 6.0),
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: state.bgColor,
          borderRadius: BorderRadius.circular(3),
          border: state.borderColor != null
              ? Border.all(color: state.borderColor!, width: 1)
              : null,
          boxShadow: state.glowColor != null
              ? [
                  BoxShadow(
                    color: state.glowColor!,
                    blurRadius: 6,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.icon != null) ...[
              Icon(
                state.icon!,
                size: context.responsive(8.0, 9.0, 10.0),
                color: state.textColor,
              ),
              SizedBox(width: context.responsive(2.0, 2.5, 3.0)),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsive(9.0, 10.0, 11.0),
                fontWeight: FontWeight.w600,
                color: state.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _getSongQuality(Song song) {
    if (song.isDsd) return 'HQ';
    final fileType = song.fileType.toUpperCase();
    const lossless = {'FLAC', 'WAV', 'ALAC', 'AIFF', 'APE', 'WV'};
    if (lossless.contains(fileType)) return 'HQ';
    if ((song.bitDepth ?? 0) >= 24) return 'HQ';
    if ((song.sampleRate ?? 0) >= 88200) return 'HQ';
    final res = song.resolution?.toLowerCase() ?? '';
    final m = RegExp(r'(\d+)\s*kbps').firstMatch(res);
    if (m != null && (int.tryParse(m.group(1)!) ?? 0) >= 320) return 'HQ';
    return 'SD';
  }

  static _IndicatorState _resolveState(
    AudioOutputDiagnostics? diagnostics, {
    bool suppressVerified = false,
  }) {
    final isVerified =
        diagnostics?.capabilityFlags.supportsVerifiedBitPerfect == true &&
        diagnostics?.resamplerActive != true;

    final isLocked =
        diagnostics != null &&
        diagnostics.capabilityFlags.supportsVerifiedBitPerfect == true &&
        diagnostics.resamplerActive == true;

    if (isVerified && !suppressVerified) {
      return _IndicatorState.verified();
    }
    if (isVerified && suppressVerified) {
      return _IndicatorState.standard();
    }
    if (isLocked) {
      return _IndicatorState.locked();
    }
    return _IndicatorState.standard();
  }

  /// Opens a sleek bottom sheet with full audio diagnostics.
  static void showInfoSheet(
    BuildContext context, {
    required Song song,
    required AudioOutputDiagnostics? diagnostics,
    required Uac2DeviceStatus? deviceStatus,
    required PlayerService playerService,
  }) {
    final isVerified =
        diagnostics?.capabilityFlags.supportsVerifiedBitPerfect == true &&
        diagnostics?.resamplerActive != true;
    final isDirectUsb =
        diagnostics?.pathManagement ==
        AudioPathManagement.directUsbExperimental;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AudioInfoBottomSheet(
        song: song,
        diagnostics: diagnostics,
        deviceStatus: deviceStatus,
        playerService: playerService,
        isVerified: isVerified,
        isDirectUsb: isDirectUsb,
      ),
    );
  }
}

class _IndicatorState {
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;
  final Color? glowColor;
  final IconData? icon;

  const _IndicatorState({
    required this.bgColor,
    required this.textColor,
    this.borderColor,
    this.glowColor,
    this.icon,
  });

  factory _IndicatorState.verified() => _IndicatorState(
    bgColor: Colors.green.withValues(alpha: 0.22),
    textColor: Colors.green.shade400,
    borderColor: Colors.green.withValues(alpha: 0.5),
    glowColor: Colors.green.withValues(alpha: 0.12),
    icon: Icons.verified_rounded,
  );

  factory _IndicatorState.locked() => _IndicatorState(
    bgColor: Colors.amber.withValues(alpha: 0.18),
    textColor: Colors.amber.shade400,
    borderColor: Colors.amber.withValues(alpha: 0.4),
    glowColor: Colors.amber.withValues(alpha: 0.08),
    icon: Icons.lock_rounded,
  );

  factory _IndicatorState.standard() => _IndicatorState(
    bgColor: Colors.white.withValues(alpha: 0.2),
    textColor: Colors.white,
  );
}

class _AudioInfoBottomSheet extends ConsumerWidget {
  final Song song;
  final AudioOutputDiagnostics? diagnostics;
  final Uac2DeviceStatus? deviceStatus;
  final PlayerService playerService;
  final bool isVerified;
  final bool isDirectUsb;

  const _AudioInfoBottomSheet({
    required this.song,
    required this.diagnostics,
    required this.deviceStatus,
    required this.playerService,
    required this.isVerified,
    required this.isDirectUsb,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
          left: BorderSide(color: AppColors.glassBorder),
          right: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            const SizedBox(height: 12),
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildInfoRows(context),
            const SizedBox(height: 16),
            _buildVisualizerPreview(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVerified
                ? Colors.green.withValues(alpha: 0.15)
                : isDirectUsb
                ? Colors.blue.withValues(alpha: 0.15)
                : AppColors.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isVerified ? LucideIcons.badgeCheck : LucideIcons.audioWaveform,
            size: 20,
            color: isVerified
                ? Colors.green.shade400
                : isDirectUsb
                ? Colors.blue.shade400
                : context.adaptiveTextPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio Signal Path',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              if (isVerified)
                Text(
                  'Bit-perfect verified',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (isDirectUsb)
                Text(
                  'Direct USB experimental',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'BP',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRows(BuildContext context) {
    final rows = <Widget>[];
    final d = diagnostics;

    // Format
    rows.add(
      _buildRow(
        context,
        label: 'Format',
        value: song.isDsd
            ? '${song.fileType.toUpperCase()} (${song.dsdRateLabel})'
            : song.fileType.toUpperCase(),
      ),
    );

    // Resolution / bit depth
    if (song.resolution != null && !song.isDsd) {
      rows.add(
        _buildRow(context, label: 'Resolution', value: song.resolution!),
      );
    }

    // Source sample rate
    if (song.sampleRate != null) {
      rows.add(
        _buildRow(
          context,
          label: 'Source rate',
          value: _formatHz(song.sampleRate!),
        ),
      );
    }

    // Output sample rate
    final outRate =
        d?.reportedOutputSampleRate ??
        d?.requestedOutputSampleRate ??
        deviceStatus?.currentFormat?.sampleRate;
    if (outRate != null) {
      final sourceRate = song.sampleRate;
      final matches = sourceRate != null && sourceRate == outRate;
      rows.add(
        _buildRow(
          context,
          label: 'Output rate',
          value: _formatHz(outRate),
          trailing: matches
              ? Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.green.shade400,
                )
              : Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.amber.shade400,
                ),
        ),
      );
    }

    // Bit depth
    final bitDepth = deviceStatus?.currentFormat?.bitDepth ?? song.bitDepth;
    if (bitDepth != null) {
      rows.add(_buildRow(context, label: 'Bit depth', value: '$bitDepth-bit'));
    }

    // Channels
    final channels = deviceStatus?.currentFormat?.channels;
    if (channels != null) {
      rows.add(
        _buildRow(
          context,
          label: 'Channels',
          value: channels == 1
              ? 'Mono'
              : channels == 2
              ? 'Stereo'
              : '$channels ch',
        ),
      );
    }

    // Decoder / Engine
    final backendDesc = d?.backendDescription;
    if (backendDesc != null && backendDesc.isNotEmpty) {
      rows.add(_buildRow(context, label: 'Engine', value: backendDesc));
    }

    // Output strategy
    final strategy = d?.outputStrategyLabel;
    if (strategy != null && strategy.isNotEmpty) {
      rows.add(_buildRow(context, label: 'Strategy', value: strategy));
    }

    // Device / DAC
    final deviceLabel =
        deviceStatus?.device.productName ??
        d?.outputDeviceLabel ??
        d?.detectedDapBrand;
    if (deviceLabel != null && deviceLabel.isNotEmpty) {
      rows.add(_buildRow(context, label: 'Device', value: deviceLabel));
    }

    // Volume control
    final volMode = deviceStatus?.volumeMode;
    if (volMode != null && volMode != Uac2VolumeMode.unavailable) {
      rows.add(
        _buildRow(context, label: 'Volume', value: _formatVolumeMode(volMode)),
      );
    }

    // Path / Route
    final routeLabel = d?.routeLabel;
    if (routeLabel != null && routeLabel.isNotEmpty) {
      rows.add(
        _buildRow(
          context,
          label: 'Route',
          value: routeLabel,
          trailing: isDirectUsb
              ? _buildTinyBadge('Direct', Colors.blue)
              : (d?.isMixerManaged ?? false)
              ? _buildTinyBadge('Mixer', Colors.grey)
              : null,
        ),
      );
    }

    // Resampler
    if (d != null) {
      rows.add(
        _buildRow(
          context,
          label: 'Resampler',
          value: d.resamplerActive ? 'Active' : 'Inactive',
          trailing: d.resamplerActive
              ? Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.amber.shade400,
                )
              : Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.green.shade400,
                ),
        ),
      );
    }

    // Passthrough
    if (d != null) {
      rows.add(
        _buildRow(
          context,
          label: 'Passthrough',
          value: d.passthroughAllowed ? 'Allowed' : 'Blocked',
          trailing: d.passthroughAllowed
              ? Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.green.shade400,
                )
              : Icon(Icons.block_rounded, size: 14, color: Colors.red.shade400),
        ),
      );
    }

    // URB / USB status
    if (d?.directUsbRegistered == true) {
      final usbParts = <String>[
        if (d!.usbInterfaceClaimed) 'Interface claimed',
        if (d.usbStreamStable) 'Stream stable',
      ];
      if (usbParts.isNotEmpty) {
        rows.add(_buildRow(context, label: 'USB', value: usbParts.join(' · ')));
      }
    }

    // Verification / fallback reason
    final verification = d?.verificationReason;
    final fallback = d?.fallbackReason;
    if (verification != null && verification.isNotEmpty) {
      rows.add(_buildRow(context, label: 'Verified', value: verification));
    } else if (fallback != null && fallback.isNotEmpty) {
      rows.add(_buildRow(context, label: 'Fallback', value: fallback));
    }

    // DSD / DoP mode
    final isDop = deviceStatus?.currentFormat?.isDop ?? false;
    final isNativeDsd = deviceStatus?.currentFormat?.isNativeDsd ?? false;
    if (isDop || isNativeDsd || song.isDsd) {
      final dsdLabel = isNativeDsd
          ? 'Native DSD'
          : isDop
          ? 'DoP'
          : 'DSD';
      rows.add(_buildRow(context, label: 'DSD mode', value: dsdLabel));
    }

    // Source path (truncated)
    if (song.filePath != null) {
      rows.add(
        _buildRow(
          context,
          label: 'Source',
          value: _truncatePath(song.filePath!),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ],
      ),
    );
  }

  Widget _buildTinyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVisualizerPreview(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final colorMode = ref.watch(albumColorModeProvider);
    final dominantColor = ref.watch(albumDominantColorSyncProvider);
    final Color? albumColor =
        (colorMode != AlbumColorMode.off && dominantColor != null)
        ? dominantColor
        : null;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: AudioVisualizer(
              playerService: playerService,
              animationStyle: prefs.visualizerAnimationStyle,
              frequencyMode: prefs.visualizerFrequencyMode,
              movementMode: prefs.visualizerMovementMode,
              albumColor: albumColor,
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Visualizer',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatHz(int rate) {
    if (rate >= 1000000) {
      return '${(rate / 1000000).toStringAsFixed(2)} MHz';
    } else if (rate >= 1000) {
      return '${(rate / 1000).toStringAsFixed(1)} kHz';
    }
    return '$rate Hz';
  }

  static String _formatVolumeMode(Uac2VolumeMode mode) {
    switch (mode) {
      case Uac2VolumeMode.system:
        return 'System (Android mixer)';
      case Uac2VolumeMode.hardware:
        return 'Hardware (USB DAC)';
      case Uac2VolumeMode.software:
        return 'Software (App-controlled)';
      case Uac2VolumeMode.unavailable:
        return 'Unavailable';
    }
  }

  static String _truncatePath(String path, {int max = 48}) {
    if (path.length <= max) return path;
    return '...${path.substring(path.length - max + 3)}';
  }
}
