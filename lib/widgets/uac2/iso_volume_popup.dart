import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/services/player_service.dart' show VolumeTier;
import 'package:flick/l10n/l10n.dart';

String _volumeToDb(double volume) {
  if (volume <= 0.0) return '-∞';
  if (volume >= 1.0) return '0.0';
  final db = 60.0 * (volume - 1.0);
  return db.toStringAsFixed(1);
}

VoidCallback? showIsoVolumePopup(BuildContext context, GlobalKey buttonKey) {
  final buttonContext = buttonKey.currentContext;
  if (buttonContext == null) return null;

  final renderBox = buttonContext.findRenderObject() as RenderBox;
  final buttonSize = renderBox.size;
  final buttonPosition = renderBox.localToGlobal(Offset.zero);
  final screenSize = MediaQuery.of(buttonContext).size;

  final overlay = Overlay.of(buttonContext);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _IsoVolumePopupOverlay(
      buttonPosition: buttonPosition,
      buttonSize: buttonSize,
      screenSize: screenSize,
      onRemoved: () => entry.remove(),
    ),
  );

  overlay.insert(entry);

  return () {
    if (entry.mounted) {
      entry.remove();
    }
  };
}

class _IsoVolumePopupOverlay extends ConsumerStatefulWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final Size screenSize;
  final VoidCallback onRemoved;

  const _IsoVolumePopupOverlay({
    required this.buttonPosition,
    required this.buttonSize,
    required this.screenSize,
    required this.onRemoved,
  });

  @override
  ConsumerState<_IsoVolumePopupOverlay> createState() =>
      _IsoVolumePopupOverlayState();
}

class _IsoVolumePopupOverlayState extends ConsumerState<_IsoVolumePopupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;

  bool _isDismissing = false;
  bool _muteUpdateInFlight = false;
  double _preMuteVolume = 1.0;
  double? _draggingVolume;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _animController.forward();
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onRemoved();
      }
    });
    _animController.reverse();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onSliderChanged(double volume) {
    setState(() => _draggingVolume = volume);
  }

  Future<void> _onSliderChangeEnd(double volume) async {
    setState(() => _draggingVolume = null);

    final playerService = ref.read(playerServiceProvider);
    final hardwareAuthority = playerService.isHardwareVolumeAuthority;
    if (!hardwareAuthority &&
        volume == 0.0 &&
        playerService.currentVolume > 0.0) {
      _preMuteVolume = playerService.currentVolume.clamp(0.01, 1.0);
    }
    // Do not couple a hardware volume write to an implicit unmute.
    await playerService.setVolume(volume);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final playerService = ref.read(playerServiceProvider);
    setState(() => _muteUpdateInFlight = true);
    try {
      if (playerService.isHardwareVolumeAuthority) {
        final muted = ref.read(uac2DeviceStatusProvider)?.muted;
        if (muted != null) {
          await ref.read(uac2DeviceStatusProvider.notifier).setMute(!muted);
        }
      } else if (playerService.currentVolume > 0.0) {
        _preMuteVolume = playerService.currentVolume.clamp(0.01, 1.0);
        await playerService.setVolume(0.0);
      } else {
        await playerService.setVolume(_preMuteVolume);
      }
    } finally {
      if (mounted) setState(() => _muteUpdateInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceStatus = ref.watch(uac2DeviceStatusProvider);

    if (deviceStatus == null || deviceStatus.state == Uac2State.idle) {
      if (!_isDismissing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _dismiss());
      }
      return const SizedBox.shrink();
    }

    final tier = ref.watch(volumeTierProvider);
    final isAvailable = tier != VolumeTier.unavailable;
    final playerVolume = ref.watch(playerVolumeProvider);
    final hardwareAuthority = tier == VolumeTier.hardware;
    final effectiveVolume = isAvailable
        ? (_draggingVolume ??
                  (hardwareAuthority
                      ? (deviceStatus.volume ?? playerVolume)
                      : playerVolume))
              .clamp(0.0, 1.0)
        : 1.0;
    final effectiveMuted = hardwareAuthority
        ? deviceStatus.muted == true
        : playerVolume <= 0.0;
    final volumeControlWritable =
        (!hardwareAuthority || deviceStatus.volumeControlWritable) &&
        isAvailable &&
        !_muteUpdateInFlight;
    final muteControlWritable =
        volumeControlWritable &&
        (!hardwareAuthority || deviceStatus.muted != null);
    final showDb = tier == VolumeTier.software;
    final volumeLabel = !isAvailable
        ? l10n.unavailable2
        : showDb
        ? l10n.db15(
            (effectiveVolume * 100).round(),
            _volumeToDb(effectiveVolume),
          )
        : '${(effectiveVolume * 100).round()}%';

    final isLeft = widget.buttonPosition.dx < widget.screenSize.width / 2;
    final popupLeft = isLeft ? widget.buttonPosition.dx : null;
    final popupRight = isLeft
        ? null
        : (widget.screenSize.width -
              widget.buttonPosition.dx -
              widget.buttonSize.width);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismiss,
      child: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: const SizedBox.expand(),
          ),
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Positioned(
                left: popupLeft,
                right: popupRight,
                top: widget.buttonPosition.dy - 260 - _slideAnimation.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    alignment: isLeft ? Alignment.topLeft : Alignment.topRight,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: 56,
                        height: 260,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                icon: Icon(
                                  effectiveMuted
                                      ? LucideIcons.volumeX
                                      : LucideIcons.volume2,
                                  size: 18,
                                ),
                                onPressed: muteControlWritable
                                    ? _toggleMute
                                    : null,
                                color: effectiveMuted
                                    ? Colors.red.shade400
                                    : context.adaptiveTextPrimary,
                                padding: EdgeInsets.zero,
                                tooltip: effectiveMuted
                                    ? l10n.unmute
                                    : l10n.mute,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingXs),
                            SizedBox(
                              height: 140,
                              width: 40,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: effectiveVolume,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 100,
                                  label: volumeLabel,
                                  semanticFormatterCallback: !isAvailable
                                      ? (_) => l10n.unavailable2
                                      : null,
                                  onChanged: volumeControlWritable
                                      ? _onSliderChanged
                                      : null,
                                  onChangeEnd: volumeControlWritable
                                      ? _onSliderChangeEnd
                                      : null,
                                  activeColor: AppColors.accent,
                                  inactiveColor: AppColors.textTertiary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingXs),
                            Text(
                              !isAvailable
                                  ? '—'
                                  : showDb
                                  ? l10n.nDb(
                                      (effectiveVolume * 100).round(),
                                      _volumeToDb(effectiveVolume),
                                    )
                                  : '${(effectiveVolume * 100).round()}%',
                              semanticsLabel: volumeLabel,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.adaptiveTextSecondary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                            ),
                            if (!volumeControlWritable) ...[
                              const SizedBox(height: 2),
                              Icon(
                                LucideIcons.lock,
                                size: 10,
                                color: context.adaptiveTextTertiary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
