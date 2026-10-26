import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/features/player/widgets/audio_signal_report.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/english_l10n.dart';

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
                fontFamily: 'GoogleSansFlex',
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
      useRootNavigator: true,
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

class _AudioInfoBottomSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_AudioInfoBottomSheet> createState() =>
      _AudioInfoBottomSheetState();
}

class _AudioInfoBottomSheetState extends ConsumerState<_AudioInfoBottomSheet> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isExpanded = false;

  static const double _collapsedHeight = 100.0;

  bool get _showPageView => widget.isVerified;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final colorMode = ref.watch(albumColorModeProvider);
    final dominantColor = ref.watch(albumDominantColorSyncProvider);
    final Color? albumColor =
        (colorMode != AlbumColorMode.off && dominantColor != null)
            ? dominantColor
            : null;

    return Container(
      decoration: AppBottomSheetSurface.decoration,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle (always visible).
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: _buildDragHandle(),
            ),
            // Header crossfade: full header in collapsed, compact bar in expanded.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOutCubic,
              firstCurve: Curves.easeInOutCubic,
              secondCurve: Curves.easeInOutCubic,
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildHeader(context),
              ),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _buildExpandedTopBar(context),
              ),
            ),
            // Info rows: collapse to 0 height when expanded.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _buildInfoRows(context),
                    ),
            ),
            // Page view: animated height + decoration.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                height: _isExpanded ? 480 : _collapsedHeight,
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildPageView(
                        context,
                        albumColor: albumColor,
                        prefs: prefs,
                        expanded: _isExpanded,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _buildPageLabelBadge(context),
                    ),
                    if (_showPageView)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _toggleExpanded,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: Icon(
                                _isExpanded
                                    ? Icons.close_fullscreen_rounded
                                    : Icons.open_in_full_rounded,
                                key: ValueKey(_isExpanded),
                                size: 14,
                                color: context.adaptiveTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Page dots: only when bit-perfect AND collapsed.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              child: _showPageView && !_isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: _buildPageDots(context),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            // Bottom padding.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              child: SizedBox(height: _isExpanded ? 16 : 24),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact top bar shown when expanded: drag-handle region + Bit-perfect chip + close.
  Widget _buildExpandedTopBar(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const Spacer(),
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
                Icon(Icons.verified_rounded, size: 12, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text(
                  l10n.bitPerfect2,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Shared widgets ----

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
            color: widget.isVerified
                ? Colors.green.withValues(alpha: 0.15)
                : widget.isDirectUsb
                    ? Colors.blue.withValues(alpha: 0.15)
                    : AppColors.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.isVerified ? LucideIcons.badgeCheck : LucideIcons.audioWaveform,
            size: 20,
            color: widget.isVerified
                ? Colors.green.shade400
                : widget.isDirectUsb
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
                l10n.audioSignalPath,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              if (widget.isVerified)
                Text(
                  l10n.bitPerfectVerified,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 12,
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (widget.isDirectUsb)
                Text(
                  l10n.directUsbExperimental,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 12,
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (widget.isVerified)
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
                    fontFamily: 'GoogleSansFlex',
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
    final d = ref.watch(audioOutputDiagnosticsProvider) ?? widget.diagnostics;

    rows.add(
      _buildRow(
        context,
        label: l10n.format,
        value: widget.song.isDsd
            ? '${widget.song.fileType.toUpperCase()} (${widget.song.dsdRateLabel})'
            : widget.song.fileType.toUpperCase(),
      ),
    );

    if (widget.song.resolution != null && !widget.song.isDsd) {
      rows.add(
        _buildRow(context, label: l10n.resolution, value: widget.song.resolution!),
      );
    }

    if (widget.song.sampleRate != null) {
      rows.add(
        _buildRow(
          context,
          label: l10n.sourceRate,
          value: _formatHz(widget.song.sampleRate!),
        ),
      );
    }

    final outRate =
        d?.reportedOutputSampleRate ??
        d?.requestedOutputSampleRate ??
        widget.deviceStatus?.currentFormat?.sampleRate;
    if (outRate != null) {
      // DSD transports report a divided rate (native ÷8, DoP ÷16, wire ÷32).
      // Show the DSD bit rate like the DAP does; any valid domain matches.
      int displayRate = outRate;
      var matches = false;
      final dsdBitRate = widget.song.isDsd ? widget.song.sampleRate : null;
      if (dsdBitRate != null) {
        if (outRate == dsdBitRate) {
          displayRate = dsdBitRate;
          matches = true;
        } else if (outRate * 8 == dsdBitRate ||
            outRate * 16 == dsdBitRate ||
            outRate * 32 == dsdBitRate) {
          displayRate = dsdBitRate;
          matches = true;
        }
      } else {
        final sourceRate = widget.song.sampleRate;
        matches = sourceRate != null && sourceRate == outRate;
      }
      rows.add(
        _buildRow(
          context,
          label: l10n.outputRate,
          value: _formatHz(displayRate),
          trailing: matches
              ? Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade400)
              : Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade400),
        ),
      );
    }

    final bitDepth = widget.deviceStatus?.currentFormat?.bitDepth ?? widget.song.bitDepth;
    if (bitDepth != null) {
      rows.add(_buildRow(context, label: l10n.bitDepth, value: '$bitDepth-bit'));
    }

    final channels = widget.deviceStatus?.currentFormat?.channels;
    if (channels != null) {
      rows.add(
        _buildRow(
          context,
          label: l10n.channels,
          value: channels == 1 ? l10n.mono : channels == 2 ? l10n.stereo : l10n.ch(channels),
        ),
      );
    }

    final backendDesc = d?.backendDescription;
    if (backendDesc != null && backendDesc.isNotEmpty) {
      rows.add(_buildRow(context, label: l10n.engine, value: backendDesc));
    }

    final strategy = d?.outputStrategyLabel;
    if (strategy != null && strategy.isNotEmpty) {
      rows.add(_buildRow(context, label: l10n.strategy, value: strategy));
    }

    final deviceLabel =
        widget.deviceStatus?.device.productName ??
        d?.outputDeviceLabel ??
        d?.detectedDapBrand;
    if (deviceLabel != null && deviceLabel.isNotEmpty) {
      rows.add(_buildRow(context, label: l10n.device, value: deviceLabel));
    }

    final volumeTier = ref.watch(volumeTierProvider);
    rows.add(_buildRow(context, label: l10n.volume, value: _formatVolumeTier(volumeTier)));
    if (d?.hardwareVolumeError != null) {
      rows.add(_buildRow(
        context,
        label: l10n.hardwareUsbDac,
        value: l10n.usbHardwareVolumeError(d!.hardwareVolumeError!),
      ));
    }

    final routeLabel = d?.routeLabel;
    if (routeLabel != null && routeLabel.isNotEmpty) {
      rows.add(
        _buildRow(
          context,
          label: l10n.route,
          value: routeLabel,
          trailing: widget.isDirectUsb
              ? _buildTinyBadge(l10n.direct, Colors.blue)
              : (d?.isMixerManaged ?? false)
                  ? _buildTinyBadge(l10n.mixer, Colors.grey)
                  : null,
        ),
      );
    }

    if (d != null) {
      rows.add(
        _buildRow(
          context,
          label: l10n.resampler,
          value: d.resamplerActive ? l10n.active : l10n.inactive,
          trailing: d.resamplerActive
              ? Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade400)
              : Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade400),
        ),
      );
    }

    if (d != null) {
      // A multichannel DSD source on a stereo DAC is deliberately folded down
      // to PCM. That is an expected limitation, not a broken passthrough, so
      // show an informational marker instead of the red blocked icon.
      final isMultichannelDsdFoldDown = d.dsdTransport == 'usb-pcm-folddown';
      rows.add(
        _buildRow(
          context,
          label: l10n.passthrough,
          value: d.passthroughAllowed ? l10n.allowed : l10n.blocked,
          trailing: d.passthroughAllowed
              ? Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade400)
              : isMultichannelDsdFoldDown
                  ? Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Colors.amber.shade400,
                    )
                  : Icon(Icons.block_rounded, size: 14, color: Colors.red.shade400),
        ),
      );
    }

    if (d?.directUsbRegistered == true) {
      final usbParts = <String>[
        if (d!.usbInterfaceClaimed) l10n.interfaceClaimed,
        if (d.usbStreamStable) l10n.streamStable,
      ];
      if (usbParts.isNotEmpty) {
        rows.add(_buildRow(context, label: 'USB', value: usbParts.join(' · ')));
      }
    }

    final verification = d?.verificationReason;
    final fallback = d?.fallbackReason;
    if (verification != null && verification.isNotEmpty) {
      // `verificationReason` also carries expected limitations (for example a
      // multichannel DSD fold-down). Only call it "Verified" when the path is
      // actually bit-perfect; otherwise present it as the active fallback.
      final isBitPerfect = d?.passthroughAllowed == true;
      rows.add(
        _buildRow(
          context,
          label: isBitPerfect ? l10n.verified : l10n.fallback,
          value: verification,
          trailing: isBitPerfect
              ? null
              : Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.amber.shade400,
                ),
        ),
      );
    } else if (fallback != null && fallback.isNotEmpty) {
      rows.add(_buildRow(context, label: l10n.fallback, value: fallback));
    }

    final isDop = widget.deviceStatus?.currentFormat?.isDop ?? false;
    final isNativeDsd = widget.deviceStatus?.currentFormat?.isNativeDsd ?? false;
    if (isDop || isNativeDsd || widget.song.isDsd) {
      // The device-status format is derived from the DSD preference, not from
      // what the engine actually negotiated (e.g. an Auto multichannel source
      // converts to PCM). Prefer the runtime mode when diagnostics carry it.
      final actualDsdMode = d?.dsdEffectiveMode;
      final String dsdLabel;
      if (actualDsdMode == 'native') {
        dsdLabel = l10n.nativeDsd;
      } else if (actualDsdMode == 'dop') {
        dsdLabel = l10n.dop;
      } else if (actualDsdMode == 'pcm') {
        dsdLabel = 'PCM conversion';
      } else {
        dsdLabel = isNativeDsd
            ? l10n.nativeDsd
            : isDop
                ? l10n.dop
                : 'DSD';
      }
      rows.add(_buildRow(context, label: l10n.dsdMode, value: dsdLabel));
    }

    if (widget.song.filePath != null) {
      rows.add(
        _buildRow(context, label: l10n.source, value: _truncatePath(widget.song.filePath!)),
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
                fontFamily: 'GoogleSansFlex',
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
                fontFamily: 'GoogleSansFlex',
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
          fontFamily: 'GoogleSansFlex',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ---- PageView area ----

  Widget _buildPageLabelBadge(BuildContext context) {
    final label = _showPageView ? _pageLabel(_currentPage) : l10n.visualizer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildPageDots(BuildContext context) {
    const pageCount = 4;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? Colors.green.shade400
                : AppColors.textTertiary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildPageView(
    BuildContext context, {
    required Color? albumColor,
    required AppPreferences prefs,
    required bool expanded,
  }) {
    if (!_showPageView) {
      return AudioVisualizer(
        playerService: widget.playerService,
        animationStyle: prefs.visualizerAnimationStyle,
        frequencyMode: prefs.visualizerFrequencyMode,
        movementMode: prefs.visualizerMovementMode,
        albumColor: albumColor,
        enabled: prefs.visualizerEnabled,
      );
    }

    return PageView(
      controller: _pageController,
      children: [
        AudioVisualizer(
          playerService: widget.playerService,
          animationStyle: prefs.visualizerAnimationStyle,
          frequencyMode: prefs.visualizerFrequencyMode,
          movementMode: prefs.visualizerMovementMode,
          albumColor: albumColor,
          enabled: prefs.visualizerEnabled,
        ),
        for (final page in AudioSignalReportPage.values)
          AudioSignalReport(
            song: widget.song,
            diagnostics: widget.diagnostics,
            page: page,
            expanded: expanded,
          ),
      ],
    );
  }

  String _pageLabel(int page) {
    switch (page) {
      case 0:
        return l10n.visualizer;
      case 1:
        return l10n.source;
      case 2:
        return l10n.urbTransfer;
      case 3:
        return l10n.recorded;
      default:
        return '';
    }
  }

  // ---- Helpers ----

  static String _formatHz(int rate) {
    if (rate >= 1000000) {
      return l10n.mhz((rate / 1000000).toStringAsFixed(2));
    } else if (rate >= 1000) {
      return l10n.khz2((rate / 1000).toStringAsFixed(1));
    }
    return l10n.hz(rate);
  }

  static String _formatVolumeTier(VolumeTier tier) {
    switch (tier) {
      case VolumeTier.system:
        return l10n.systemAndroidMixer;
      case VolumeTier.hardware:
        return l10n.hardwareUsbDac;
      case VolumeTier.software:
        return l10n.softwareAppControlled;
      case VolumeTier.unavailable:
        return l10n.unavailable2;
    }
  }

  static String _truncatePath(String path, {int max = 48}) {
    if (path.length <= max) return path;
    return '...${path.substring(path.length - max + 3)}';
  }
}
