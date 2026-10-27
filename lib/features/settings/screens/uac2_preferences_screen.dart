import 'dart:async';
import 'package:flick/widgets/common/flick_snackbar.dart';

import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flick/widgets/common/flick_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/eq_engine_hint.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/src/rust/api/audio_api.dart' as rust_audio;
import 'package:flick/src/rust/audio/engine.dart' show AudioApiPreference;
import 'package:flick/widgets/common/engine_restart_notice.dart';
import 'package:flick/widgets/uac2/uac2_volume_control.dart';
import 'package:flick/features/settings/screens/logs_screen.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/l10n/settings_l10n.dart';
import 'package:flick/features/settings/widgets/settings_scroll_target.dart';

class Uac2PreferencesScreen extends ConsumerStatefulWidget {
  const Uac2PreferencesScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  ConsumerState<Uac2PreferencesScreen> createState() =>
      _Uac2PreferencesScreenState();
}

class _Uac2PreferencesScreenState extends ConsumerState<Uac2PreferencesScreen> {
  bool _pendingEngineRestart = false;

  @override
  Widget build(BuildContext context) {
                    final preferencesService = ref.watch(uac2PreferencesServiceProvider);
                    final formatPrefAsync = ref.watch(uac2FormatPreferenceProvider);
                    final preferredFormatAsync = ref.watch(uac2PreferredFormatProvider);
                    final audioFormatAsync = ref.watch(audioFormatEnabledProvider);
                    final bitPerfectAsync = ref.watch(uac2BitPerfectEnabledProvider);
                    final dapBitPerfectAsync = ref.watch(uac2DapBitPerfectEnabledProvider);
                    final tuning432HzAsync = ref.watch(uac2432HzTuningEnabledProvider);
                    final audioEngineAsync = ref.watch(audioEnginePreferenceProvider);
                    final androidAudioApiAsync = ref.watch(androidAudioApiProvider);
                    final developerModeAsync = ref.watch(developerModeEnabledProvider);
                    final diagnostics = ref.watch(audioOutputDiagnosticsProvider);
                    final killIsochronousUsbOnQuitAsync = ref.watch(killIsochronousUsbOnQuitProvider);
                    final autoEngageUsbDacAsync = ref.watch(autoEngageUsbDacProvider);
                    final declinedUsbDevicesAsync = ref.watch(declinedUsbDevicesProvider);
                    final dsdOutputModeAsync = ref.watch(dsdOutputModeProvider);
                    final currentSong = ref.watch(currentSongProvider);

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
                  child: SettingsScrollTarget(
                    initialSection: widget.initialSection,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_pendingEngineRestart) ...[
                            const EngineRestartNotice(),
                            const SizedBox(height: AppConstants.spacingLg),
                          ],
                          _buildSectionHeader(
                            context,
                            l10n.englishForFilipino.audioFormat,
                            'audioFormat',
                          ),
                          _buildFormatPreferences(
                            context,
                            preferencesService,
                            formatPrefAsync,
                            preferredFormatAsync,
                            audioFormatAsync,
                          ),
                          const SizedBox(height: AppConstants.spacingLg),
                          _buildSectionHeader(
                            context,
                            l10n.englishForFilipino.experimental,
                            'experimental',
                          ),
                          _buildExperimentalWarning(context),
                          _buildDsdOptions(
                            context,
                            preferencesService,
                            dsdOutputModeAsync,
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          _build432HzTuningTile(
                            context,
                            preferencesService,
                            tuning432HzAsync,
                          ),
                          const SizedBox(height: AppConstants.spacingLg),
                          _buildSectionHeader(
                            context,
                            l10n.englishForFilipino.advanced,
                            'advanced',
                          ),
                          _buildAdvancedOptions(
                            context,
                            preferencesService,
                            audioEngineAsync,
                            androidAudioApiAsync,
                            developerModeAsync,
                            bitPerfectAsync,
                            dapBitPerfectAsync,
                            killIsochronousUsbOnQuitAsync,
                            autoEngageUsbDacAsync,
                            declinedUsbDevicesAsync,
                            diagnostics,
                          ),
                          if (audioEngineAsync.when(
                            data: (e) => e == AudioEnginePreference.isochronousUsb,
                            loading: () => false,
                            error: (_, _) => false,
                          )) ...[
                            const SizedBox(height: AppConstants.spacingLg),
                            _buildSectionHeader(
                              context,
                              l10n.englishForFilipino.volume,
                              'volume',
                            ),
                            const Uac2VolumeControl(),
                          ],
                          const SizedBox(height: AppConstants.navBarHeight + 120),
                        ],
                      ),
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
          Text(
            l10n.englishForFilipino.uac2Preferences,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String sectionId,
  ) {
    return SettingsSectionAnchor(
      id: sectionId,
      child: Padding(
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
      ),
    );
  }

  Widget _buildFormatPreferences(
    BuildContext context,
    Uac2PreferencesService service,
    AsyncValue<Uac2FormatPreference> formatPrefAsync,
    AsyncValue<Uac2AudioFormat?> preferredFormatAsync,
    AsyncValue<bool> audioFormatAsync,
  ) {
    final bitPerfectAsync = ref.watch(uac2BitPerfectEnabledProvider);
    final isBitPerfectEnabled = bitPerfectAsync.value ?? false;
    final isAudioFormatEnabled = audioFormatAsync.value ?? true;
    final formatBlocked = !isAudioFormatEnabled || isBitPerfectEnabled;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          // Audio Format master toggle
          audioFormatAsync.when(
            data: (enabled) => _buildSwitchTile(
              context,
              icon: LucideIcons.settings,
              title: l10n.englishForFilipino.audioFormat,
              subtitle: enabled
                  ? l10n.formatStrategyAndCustomFormatControls
                  : l10n.formatControlsAreDisabledTheEngine,
              value: enabled,
              onChanged: (value) async {
                await service.setAudioFormatEnabled(value);
                ref.invalidate(audioFormatEnabledProvider);
              },
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          _buildDivider(),
          formatPrefAsync.when(
            data: (formatPref) => _buildNavigationTile(
              context,
              icon: LucideIcons.slidersHorizontal,
              title: l10n.englishForFilipino.formatStrategy,
              subtitle: formatBlocked
                  ? l10n.disabledInBitPerfectUsbDac
                  : !isAudioFormatEnabled
                  ? l10n.audioFormatIsDisabled
                  : _getFormatPreferenceLabel(formatPref),
              onTap: formatBlocked
                  ? () => isBitPerfectEnabled
                      ? _showBitPerfectBlockedDialog(
                          context,
                          l10n.formatStrategy,
                          l10n.formatStrategyIsDisabledInBit,
                        )
                      : _showBitPerfectBlockedDialog(
                          context,
                          l10n.formatStrategy,
                          l10n.formatStrategyIsUnavailableBecauseAudio,
                        )
                  : () => _showFormatPreferenceDialog(
                      context,
                      service,
                      formatPref,
                    ),
              isDisabled: formatBlocked,
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          _buildDivider(),
          preferredFormatAsync.when(
            data: (format) => _buildNavigationTile(
              context,
              icon: LucideIcons.music,
              title: l10n.englishForFilipino.customFormat,
              subtitle: formatBlocked
                  ? isBitPerfectEnabled
                      ? l10n.disabledInBitPerfectUsbDac
                      : l10n.audioFormatIsDisabled
                  : format != null
                  ? format.isDsdStream
                        ? l10n.ch3(format.displayRateLabel, format.channels)
                        : l10n.khzBitCh(format.sampleRate ~/ 1000, format.bitDepth, format.channels)
                  : l10n.notSet,
              onTap: formatBlocked
                  ? () => isBitPerfectEnabled
                      ? _showBitPerfectBlockedDialog(
                          context,
                          l10n.customFormat,
                          l10n.customFormatIsDisabledInBit,
                        )
                      : _showBitPerfectBlockedDialog(
                          context,
                          l10n.customFormat,
                          l10n.customFormatIsUnavailableBecauseAudio,
                        )
                  : () => _showCustomFormatDialog(context, service, format),
              isDisabled: formatBlocked,
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(
    BuildContext context,
    Uac2PreferencesService service,
    AsyncValue<AudioEnginePreference> audioEngineAsync,
    AsyncValue<AudioApiPreference> androidAudioApiAsync,
    AsyncValue<bool> developerModeAsync,
    AsyncValue<bool> bitPerfectAsync,
    AsyncValue<bool> dapBitPerfectAsync,
    AsyncValue<bool> killIsochronousUsbOnQuitAsync,
    AsyncValue<bool> autoEngageUsbDacAsync,
    AsyncValue<Set<String>> declinedUsbDevicesAsync,
    AudioOutputDiagnostics? diagnostics,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          audioEngineAsync.when(
            data: (engine) => _buildNavigationTile(
              context,
              icon: LucideIcons.audioLines,
              title: l10n.englishForFilipino.playbackEngine,
              subtitle: _audioEnginePreferenceSubtitle(engine),
               onTap: () => _showAudioEngineDialog(
                 context,
                 service,
                 engine,
                 diagnostics: diagnostics,
               ),
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          if (audioEngineAsync.when(
            data: (e) => e == AudioEnginePreference.rustOboe,
            loading: () => false,
            error: (_, _) => false,
          )) ...[
            _buildDivider(),
            androidAudioApiAsync.when(
              data: (pref) => _buildNavigationTile(
                context,
                icon: LucideIcons.circuitBoard,
                title: l10n.englishForFilipino.androidAudioApi,
                subtitle: _androidAudioApiSubtitle(pref),
                onTap: () => _showAndroidAudioApiDialog(context, service, pref),
              ),
              loading: () => _buildLoadingTile(context),
              error: (_, _) => _buildErrorTile(context),
            ),
          ],
          _buildDivider(),
          developerModeAsync.when(
            data: (enabled) => _buildSwitchTile(
              context,
              icon: LucideIcons.badgeInfo,
              title: l10n.englishForFilipino.developerMode,
              subtitle:
                  l10n.showVerboseAudioDiagnosticsAndEngine,
              value: enabled,
              onChanged: (value) async {
                await service.setDeveloperModeEnabled(value);
                ref.invalidate(developerModeEnabledProvider);
              },
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          ...developerModeAsync.maybeWhen(
            data: (enabled) => enabled
                ? [
                    _buildDivider(),
                    _buildNavigationTile(
                      context,
                      icon: LucideIcons.terminal,
                      title: l10n.englishForFilipino.logs,
                      subtitle: l10n.verboseDartRustAndCrashLogs,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LogsScreen(),
                        ),
                      ),
                    ),
                  ]
                : [],
            orElse: () => [],
          ),
          _buildDivider(),
          _buildModeStatusTile(context, diagnostics),
          _buildDivider(),
          bitPerfectAsync.when(
            data: (enabled) => _buildSwitchTile(
              context,
              icon: LucideIcons.lock,
              title: l10n.englishForFilipino.bitPerfectUsbDac,
              subtitle:
                  l10n.useTheVerifiedDirectUsbPath,
              value: enabled,
              onChanged: (value) async {
                final changed = value != enabled;
                final applied = value
                    ? await ref
                          .read(playerServiceProvider)
                          .enableUsbDacBitPerfect()
                    : await ref
                          .read(uac2ServiceProvider)
                          .setBitPerfectEnabled(false);
                ref.invalidate(audioEnginePreferenceProvider);
                ref.invalidate(uac2BitPerfectEnabledProvider);
                ref.invalidate(uac2ExclusiveDacModeProvider);
                ref.invalidate(killIsochronousUsbOnQuitProvider);
                if (!context.mounted) {
                  return;
                }
                if (!applied && value) {
                  ScaffoldMessenger.of(context).showFlickSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.bitPerfectUsbDacCouldNot,
                      ),
                    ),
                  );
                  return;
                }
                if (changed) {
                  if (value && EqEngineHint.parametricPeqActive) {
                    ScaffoldMessenger.of(context).showFlickSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.bitPerfectEnabledParametricEqIs,
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    _showRestartRequiredToast(context);
                  }
                }
              },
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          if (diagnostics?.detectedDap == true) ...[
            _buildDivider(),
            dapBitPerfectAsync.when(
              data: (enabled) => _buildSwitchTile(
                context,
                icon: LucideIcons.headphones,
                title: l10n.englishForFilipino.bitPerfectDapInternal,
                subtitle:
                    l10n.bypassAllDspEqDynamicsCrossfade,
                value: enabled,
                onChanged: (value) async {
                  await PlayerService().setDapBitPerfectEnabled(value);
                  ref.invalidate(uac2DapBitPerfectEnabledProvider);
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showFlickSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? l10n.bitPerfectDapInternalEnabledAll
                            : l10n.bitPerfectDapInternalDisabledSoftware,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _showRestartRequiredToast(context);
                },
              ),
              loading: () => _buildLoadingTile(context),
              error: (_, _) => _buildErrorTile(context),
            ),
          ],
          _buildDivider(),
          autoEngageUsbDacAsync.when(
            data: (enabled) => _buildSwitchTile(
              context,
              icon: LucideIcons.zap,
              title: l10n.englishForFilipino.autoBitPerfectForUsbDacs,
              subtitle:
                  l10n.switchToTheExclusiveUsbPath,
              value: enabled,
              onChanged: (value) async {
                await service.setAutoEngageUsbDacEnabled(value);
                ref.invalidate(autoEngageUsbDacProvider);
              },
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          declinedUsbDevicesAsync.maybeWhen(
            data: (declined) => declined.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _buildDivider(),
                      _buildNavigationTile(
                        context,
                        icon: LucideIcons.rotateCcw,
                        title: l10n.englishForFilipino.resetDeclinedUsbDacs,
                        subtitle:
                            l10n.dacWillBeOfferedAgain(declined.length),
                        onTap: () async {
                          await service.clearDeclinedUsbDevices();
                          ref.invalidate(declinedUsbDevicesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showFlickSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.usbDacAutoBitPerfectOffers,
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          _buildDivider(),
          killIsochronousUsbOnQuitAsync.when(
            data: (killOnQuit) => _buildSwitchTile(
              context,
              icon: LucideIcons.power,
              title: l10n.englishForFilipino.stopUsbOnQuit,
              subtitle: killOnQuit
                  ? l10n.theIsochronousUsbEngineWillBe
                  : l10n.theIsochronousUsbEngineWillStay,
              value: killOnQuit,
              onChanged: (value) async {
                await service.setKillIsochronousUsbOnQuit(value);
                ref.invalidate(killIsochronousUsbOnQuitProvider);
                unawaited(Uac2Service.instance.syncKillIsochronousUsbOnQuitToNative());
              },
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          _buildDivider(),
          _buildNavigationTile(
            context,
            icon: LucideIcons.trash2,
            title: l10n.englishForFilipino.resetPreferences,
            subtitle: l10n.clearAllUac2Settings,
            onTap: () => _showResetConfirmation(context, service),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    String? disabledSubtitle,
  }) {
    final effectiveSubtitle =
        !enabled && disabledSubtitle != null ? disabledSubtitle : subtitle;
    final tile = Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(icon, color: context.adaptiveTextSecondary, size: 20),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  effectiveSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled ? value : false,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
    if (!enabled) {
      return Opacity(opacity: 0.55, child: tile);
    }
    return tile;
  }

  String _audioEnginePreferenceSubtitle(AudioEnginePreference engine) {
    return switch (engine) {
      AudioEnginePreference.exoPlayer => l10n.justAudioExoplayerDefault,
      AudioEnginePreference.rustOboe => l10n.rustViaOboe,
      AudioEnginePreference.isochronousUsb => l10n.isochronousUsb,
    };
  }

  String _androidAudioApiSubtitle(AudioApiPreference pref) {
    return switch (pref) {
      AudioApiPreference.auto => l10n.aaudioWithOpenslEsFallbackDefault,
      AudioApiPreference.aAudio => l10n.aaudioAndroid81,
      AudioApiPreference.openSles => l10n.openslEsLegacy,
    };
  }

  Future<void> _showAndroidAudioApiDialog(
    BuildContext context,
    Uac2PreferencesService service,
    AudioApiPreference current,
  ) async {
    await showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.androidAudioApi,
      builder: (dialogContext) {
        return FlickDialog(
          title: l10n.englishForFilipino.androidAudioApi,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.auto,
                subtitle:
                    l10n.letOboePickTheBestApi,
                selected: current == AudioApiPreference.auto,
                onTap: () async {
                  final changed = current != AudioApiPreference.auto;
                  await service.setAndroidAudioApi(AudioApiPreference.auto);
                  rust_audio.audioSetAudioApi(preference: AudioApiPreference.auto);
                  ref.invalidate(androidAudioApiProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (changed && context.mounted) {
                    _showRestartRequiredToast(context);
                  }
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.aaudio,
                subtitle:
                    l10n.useAaudioDirectlyLowestLatencyOn,
                selected: current == AudioApiPreference.aAudio,
                onTap: () async {
                  final changed = current != AudioApiPreference.aAudio;
                  await service.setAndroidAudioApi(AudioApiPreference.aAudio);
                  rust_audio.audioSetAudioApi(preference: AudioApiPreference.aAudio);
                  ref.invalidate(androidAudioApiProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (changed && context.mounted) {
                    _showRestartRequiredToast(context);
                  }
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.openslEs,
                subtitle:
                    l10n.useTheLegacyOpenslEsBackend,
                selected: current == AudioApiPreference.openSles,
                onTap: () async {
                  final changed = current != AudioApiPreference.openSles;
                  await service.setAndroidAudioApi(AudioApiPreference.openSles);
                  rust_audio.audioSetAudioApi(preference: AudioApiPreference.openSles);
                  ref.invalidate(androidAudioApiProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (changed && context.mounted) {
                    _showRestartRequiredToast(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAudioEngineDialog(
    BuildContext context,
    Uac2PreferencesService service,
    AudioEnginePreference current, {
    AudioOutputDiagnostics? diagnostics,
  }) async {
    final dapBothOff = diagnostics?.detectedDap == true &&
        !(await service.getBitPerfectEnabled()) &&
        !(await service.getDapBitPerfectEnabled());
    final effective =
        (dapBothOff && current == AudioEnginePreference.exoPlayer)
            ? AudioEnginePreference.rustOboe
            : current;
    if (dapBothOff && current == AudioEnginePreference.exoPlayer) {
      await PlayerService().setAudioEnginePreference(AudioEnginePreference.rustOboe);
      ref.invalidate(audioEnginePreferenceProvider);
    }

    await showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.playbackEngine,
      builder: (dialogContext) {
        return FlickDialog(
          title: l10n.englishForFilipino.playbackEngine,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dapBothOff) ...[
                _buildEngineLockCallout(dialogContext),
                const SizedBox(height: AppConstants.spacingMd),
              ],
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.justAudioExoplayer,
                subtitle: dapBothOff
                    ? l10n.disabledWhileBothBitPerfectOptions
                    : l10n.defaultAndroidPlaybackEngineUsedBy,
                selected: effective == AudioEnginePreference.exoPlayer,
                enabled: !dapBothOff,
                badgeText: dapBothOff ? l10n.locked : null,
                onTap: dapBothOff
                    ? null
                    : () async {
                        final wasBitPerfectEnabled =
                            await service.getBitPerfectEnabled();
                        await PlayerService().setAudioEnginePreference(
                          AudioEnginePreference.exoPlayer,
                        );
                        if (wasBitPerfectEnabled) {
                          await ref
                              .read(uac2ServiceProvider)
                              .setBitPerfectEnabled(false);
                          ref.invalidate(uac2BitPerfectEnabledProvider);
                          ref.invalidate(uac2ExclusiveDacModeProvider);
                          ref.invalidate(killIsochronousUsbOnQuitProvider);
                        }
                        ref.invalidate(audioEnginePreferenceProvider);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (current != AudioEnginePreference.exoPlayer &&
                            context.mounted) {
                          setState(() => _pendingEngineRestart = true);
                        }
                      },
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.rustViaOboe,
                subtitle: dapBothOff
                    ? l10n.keepsSoftwareVolumeAndDspActive
                    : l10n.androidManagedRustPlaybackPathUsing,
                selected: effective == AudioEnginePreference.rustOboe,
                badgeText:
                    (dapBothOff && effective != current) ? l10n.active : null,
                onTap: () async {
                  final wasBitPerfectEnabled =
                      await service.getBitPerfectEnabled();
                  await PlayerService().setAudioEnginePreference(
                    AudioEnginePreference.rustOboe,
                  );
                  if (wasBitPerfectEnabled) {
                    await ref
                        .read(uac2ServiceProvider)
                        .setBitPerfectEnabled(false);
                    ref.invalidate(uac2BitPerfectEnabledProvider);
                    ref.invalidate(uac2ExclusiveDacModeProvider);
                    ref.invalidate(killIsochronousUsbOnQuitProvider);
                  }
                  ref.invalidate(audioEnginePreferenceProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (current != AudioEnginePreference.rustOboe &&
                      context.mounted) {
                    setState(() => _pendingEngineRestart = true);
                  }
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _buildAudioEngineOption(
                dialogContext,
                title: l10n.englishForFilipino.isochronousUsb,
                subtitle:
                    l10n.directLibusbIsochronousUsbEngineBest,
                selected: effective == AudioEnginePreference.isochronousUsb,
                onTap: () async {
                  await PlayerService().setAudioEnginePreference(
                    AudioEnginePreference.isochronousUsb,
                  );
                  ref.invalidate(audioEnginePreferenceProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (current != AudioEnginePreference.isochronousUsb &&
                      context.mounted) {
                    setState(() => _pendingEngineRestart = true);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEngineLockCallout(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.lock,
            color: AppColors.accent,
            size: 18,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              l10n.bothBitPerfectOptionsAreOff,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioEngineOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    bool enabled = true,
    String? badgeText,
    String? disabledText,
    VoidCallback? onTap,
  }) {
    final chipText = badgeText ?? (!enabled ? disabledText : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : AppColors.glassBorder,
              ),
              color: AppColors.surfaceLight.withValues(alpha: 0.35),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? AppColors.accent
                      : context.adaptiveTextTertiary,
                  size: 20,
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.adaptiveTextPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (chipText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSm,
                                ),
                              ),
                              child: Text(
                                chipText,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRestartRequiredToast(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showFlickSnackBar(
      SnackBar(
        content: Text(l10n.restartTheAppToApplyPlayback),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeviceRestartRequiredToast(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showFlickSnackBar(
      SnackBar(
        content: Text(l10n.restartYourDeviceToApplyOutput),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFormatWarningCallout(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade300,
            size: 18,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeStatusTile(
    BuildContext context,
    AudioOutputDiagnostics? diagnostics,
  ) {
    final modeLabel = _currentPlaybackModeLabel(diagnostics);
    final modeDescription = switch (diagnostics?.pathManagement) {
      AudioPathManagement.directUsbExperimental =>
        l10n.exclusiveUsbIsActiveAndBypassing,
      AudioPathManagement.alsaDirectDap =>
        l10n.directAlsaOutputIsActiveAnd,
      AudioPathManagement.managedDirectExclusive =>
        l10n.exclusiveDirectPcmIsActiveAnd,
      AudioPathManagement.androidManagedLowLatency =>
        l10n.playbackIsUsingAndroidManagedOutput,
      AudioPathManagement.androidManagedShared =>
        l10n.playbackIsUsingTheStandardAndroid,
      null =>
        l10n.playbackModeWillUpdateAfterThe,
    };

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              LucideIcons.badgeInfo,
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
                  l10n.englishForFilipino.currentPlaybackMode,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modeDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currentPlaybackModeLabel(AudioOutputDiagnostics? diagnostics) {
    return diagnostics?.capabilityStateLabel ?? l10n.waitingForPlayback;
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isDisabled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive
                        ? Colors.red.shade400
                        : context.adaptiveTextSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDestructive
                              ? Colors.red.shade400
                              : context.adaptiveTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDisabled)
                  Icon(
                    LucideIcons.chevronRight,
                    color: context.adaptiveTextTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingTile(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppConstants.spacingMd),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Text(
        l10n.errorLoadingPreference,
        style: TextStyle(color: Colors.red.shade400),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: AppColors.glassBorder);
  }

  String _getFormatPreferenceLabel(Uac2FormatPreference pref) {
    switch (pref) {
      case Uac2FormatPreference.highestQuality:
        return l10n.highestQuality;
      case Uac2FormatPreference.compatibility:
        return l10n.compatibility;
      case Uac2FormatPreference.custom:
        return l10n.custom;
    }
  }

  void _showFormatPreferenceDialog(
    BuildContext context,
    Uac2PreferencesService service,
    Uac2FormatPreference current,
  ) {
    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.formatStrategy,
      builder: (context) => FlickDialog(
        title: l10n.englishForFilipino.formatStrategy,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormatWarningCallout(
              context,
              l10n.changingSampleRateBitDepthOr,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            _buildFormatOption(
              context,
              Uac2FormatPreference.highestQuality,
              l10n.highestQuality,
              l10n.useTheHighestFixedOutputRate,
              current,
              service,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildFormatOption(
              context,
              Uac2FormatPreference.compatibility,
              l10n.compatibility,
              l10n.useAFixed48khz16bitOutput,
              current,
              service,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildFormatOption(
              context,
              Uac2FormatPreference.custom,
              l10n.custom,
              'Use your selected fixed sample rate, bit depth, and channels',
              current,
              service,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
    BuildContext context,
    Uac2FormatPreference preference,
    String title,
    String description,
    Uac2FormatPreference current,
    Uac2PreferencesService service,
  ) {
    final isSelected = preference == current;
    return FlickOptionTile(
      title: title,
      description: description,
      selected: isSelected,
      onTap: () async {
        final changed = preference != current;
        await service.setFormatPreference(preference);
        ref.invalidate(uac2FormatPreferenceProvider);
        if (context.mounted) Navigator.of(context).pop();
        if (changed && mounted) {
          _showDeviceRestartRequiredToast(this.context);
        }
      },
    );
  }

  void _showCustomFormatDialog(
    BuildContext context,
    Uac2PreferencesService service,
    Uac2AudioFormat? current,
  ) {
    int sampleRate = current?.sampleRate ?? 48000;
    int bitDepth = current?.bitDepth ?? 16;
    int channels = current?.channels ?? 2;

    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.customFormat,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => FlickDialog(
          title: l10n.englishForFilipino.customFormat,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormatWarningCallout(
                context,
                l10n.customFormatForcesPlaybackToThe,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                l10n.englishForFilipino.sampleRate2,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: 8,
                children:
                    [
                      44100,
                      48000,
                      88200,
                      96000,
                      176400,
                      192000,
                      352800,
                      384000,
                    ].map((rate) {
                      return ChoiceChip(
                        label: Text(l10n.khz(rate ~/ 1000)),
                        selected: sampleRate == rate,
                        onSelected: (selected) {
                          if (selected) setState(() => sampleRate = rate);
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                l10n.englishForFilipino.bitDepth2,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: 8,
                children: [16, 24, 32].map((depth) {
                  return ChoiceChip(
                    label: Text(l10n.bit(depth)),
                    selected: bitDepth == depth,
                    onSelected: (selected) {
                      if (selected) setState(() => bitDepth = depth);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                l10n.englishForFilipino.channels,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: 8,
                children: [1, 2].map((ch) {
                  return ChoiceChip(
                    label: Text(ch == 1 ? l10n.englishForFilipino.mono : l10n.englishForFilipino.stereo),
                    selected: channels == ch,
                    onSelected: (selected) {
                      if (selected) setState(() => channels = ch);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            FlickDialogButton(
              label: l10n.englishForFilipino.cancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FlickDialogButton(
              label: l10n.englishForFilipino.save,
              style: FlickDialogButtonStyle.primary,
              onPressed: () async {
                final formatChanged =
                    current?.sampleRate != sampleRate ||
                    current?.bitDepth != bitDepth ||
                    current?.channels != channels;
                final previousPreference = await service.getFormatPreference();
                final format = Uac2AudioFormat(
                  sampleRate: sampleRate,
                  bitDepth: bitDepth,
                  channels: channels,
                );
                await service.savePreferredFormat(format);
                await service.setFormatPreference(Uac2FormatPreference.custom);
                ref.invalidate(uac2PreferredFormatProvider);
                ref.invalidate(uac2FormatPreferenceProvider);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if ((formatChanged ||
                        previousPreference != Uac2FormatPreference.custom) &&
                    mounted) {
                  _showDeviceRestartRequiredToast(this.context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(
    BuildContext context,
    Uac2PreferencesService service,
  ) {
    unawaited(
      FlickDialogs.confirm(
        context,
        title: l10n.englishForFilipino.resetPreferences,
        message:
            l10n.areYouSureYouWantTo3,
        confirmLabel: l10n.englishForFilipino.reset,
        destructive: true,
      ).then((confirmed) async {
        if (!confirmed) return;
        await service.clearAllPreferences();
        await ref
            .read(uac2ServiceProvider)
            .setBitPerfectEnabled(false, persist: false);
        ref.invalidate(uac2FormatPreferenceProvider);
        ref.invalidate(uac2PreferredFormatProvider);
        ref.invalidate(uac2BitPerfectEnabledProvider);
        ref.invalidate(uac2ExclusiveDacModeProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showFlickSnackBar(
            SnackBar(
              content: Text(l10n.uac2PreferencesResetSuccessfully),
            ),
          );
        }
      }),
    );
  }

  void _showBitPerfectBlockedDialog(
    BuildContext context,
    String featureName,
    String message,
  ) {
    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.unavailable(featureName),
      builder: (dialogContext) => FlickDialog(
        title: l10n.englishForFilipino.unavailable(featureName),
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.amber.shade300,
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          FlickDialogButton(
            label: 'OK',
            style: FlickDialogButtonStyle.primary,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDsdOptions(
    BuildContext context,
    Uac2PreferencesService service,
    AsyncValue<DsdOutputMode> outputModeAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          outputModeAsync.when(
            data: (mode) => _buildNavigationTile(
              context,
              icon: LucideIcons.radio,
              title: l10n.englishForFilipino.dsdOutputMode,
              subtitle: _dsdOutputModeSubtitle(mode),
              onTap: () => _showDsdOutputModeDialog(context, service, mode),
            ),
            loading: () => _buildLoadingTile(context),
            error: (_, _) => _buildErrorTile(context),
          ),
          _buildDivider(),
          ValueListenableBuilder<DsdWireVariant>(
            valueListenable: Uac2PreferencesService.dsdWireVariantNotifier,
            builder: (context, variant, _) => _buildNavigationTile(
              context,
              icon: LucideIcons.binary,
              title: l10n.englishForFilipino.dapNativeBitOrder,
              subtitle: _dsdWireVariantSubtitle(variant),
              onTap: () => _showDsdWireVariantDialog(context, service, variant),
            ),
          ),
          _buildDivider(),
          ValueListenableBuilder<DsdWireGrouping>(
            valueListenable: Uac2PreferencesService.dsdWireGroupingNotifier,
            builder: (context, grouping, _) => _buildNavigationTile(
              context,
              icon: LucideIcons.columns2,
              title: l10n.englishForFilipino.dapNativeByteGrouping,
              subtitle: _dsdWireGroupingSubtitle(grouping),
              onTap: () => _showDsdWireGroupingDialog(context, service, grouping),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build432HzTuningTile(
    BuildContext context,
    Uac2PreferencesService service,
    AsyncValue<bool> tuningAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: tuningAsync.when(
        data: (enabled) => _buildSwitchTile(
          context,
          icon: LucideIcons.music2,
          title: l10n.englishForFilipino.hzTuning,
          subtitle:
              l10n.experimentalDownTunePlaybackBy432,
          value: enabled,
          onChanged: (value) async {
            if (value && !enabled && !_awaiting432HzConfirm) {
              final confirmed = await _confirmEnable432HzTuning(context);
              if (!confirmed || !context.mounted) return;
            }
            await service.set432HzTuningEnabled(value);
            rust_audio.audioSet432HzTuningEnabled(enabled: value);
            ref.invalidate(uac2432HzTuningEnabledProvider);
          },
        ),
        loading: () => _buildLoadingTile(context),
        error: (_, _) => _buildErrorTile(context),
      ),
    );
  }

  bool _awaiting432HzConfirm = false;

  Future<bool> _confirmEnable432HzTuning(BuildContext context) {
    if (_awaiting432HzConfirm) return Future.value(false);
    _awaiting432HzConfirm = true;
    return FlickDialogs.confirm(
      context,
      title: l10n.englishForFilipino.enable432HzTuning,
      message:
          l10n.thisSlowsPlaybackTo432440,
      confirmLabel: l10n.englishForFilipino.enable,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.amber,
    ).then((result) {
      _awaiting432HzConfirm = false;
      return result;
    });
  }

  Widget _buildExperimentalWarning(BuildContext context) {
    const warnColor = Colors.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: warnColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: warnColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: warnColor),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                l10n.notRecommendedForNormalUsageDsd,
                style: TextStyle(
                  color: warnColor.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dsdOutputModeSubtitle(DsdOutputMode mode) {
    switch (mode) {
      case DsdOutputMode.auto:
        return l10n.autoNativeDsdOnDapsDop;
      case DsdOutputMode.forcePcm:
        return l10n.forcePcmAlwaysConvertDsdTo;
      case DsdOutputMode.forceDop:
        return l10n.forceDopAlwaysUseDsdOver;
      case DsdOutputMode.native:
        return l10n.nativeDsdExperimentalMayBeBuggy;
    }
  }


  void _showDsdOutputModeDialog(
    BuildContext context,
    Uac2PreferencesService service,
    DsdOutputMode current,
  ) {
    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.dsdOutputMode,
      builder: (dialogContext) => FlickDialog(
        title: l10n.englishForFilipino.dsdOutputMode,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDsdOptionTile(
              dialogContext,
              title: l10n.englishForFilipino.auto,
              subtitle: l10n.comingSoon,
              enabled: false,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildDsdOptionTile(
              dialogContext,
              title: l10n.englishForFilipino.forcePcm,
              subtitle: l10n.comingSoon,
              enabled: false,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildDsdOptionTile(
              dialogContext,
              title: l10n.englishForFilipino.forceDop,
              subtitle: l10n.comingSoon,
              enabled: false,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildDsdOptionTile(
              dialogContext,
              title: l10n.englishForFilipino.nativeDsdExperimental,
              subtitle:
                  l10n.rawDsdStreamToDacRequires,
              selected: current == DsdOutputMode.native,
              onTap: () async {
                await service.setDsdOutputMode(DsdOutputMode.native);
                ref.invalidate(dsdOutputModeProvider);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
        actions: [
          FlickDialogButton(
            label: l10n.englishForFilipino.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  String _dsdWireVariantSubtitle(DsdWireVariant variant) {
    switch (variant) {
      case DsdWireVariant.auto:
        return l10n.autoBeMsbDefaultOnlyChange;
      case DsdWireVariant.beMsb:
        return l10n.beMsbBigEndianSubslotMsb;
      case DsdWireVariant.leMsb:
        return l10n.leMsbLittleEndianSubslotMsb;
      case DsdWireVariant.beLsb:
        return l10n.beLsbBigEndianSubslotLsb;
      case DsdWireVariant.leLsb:
        return l10n.leLsbLittleEndianSubslotLsb;
    }
  }

  String _dsdWireGroupingSubtitle(DsdWireGrouping grouping) {
    switch (grouping) {
      case DsdWireGrouping.auto:
        return l10n.autoU8ByteInterleavedRecommended;
      case DsdWireGrouping.u32:
        return l10n.u324ByteSubslotsLlllRrrr;
      case DsdWireGrouping.u16:
        return l10n.u162ByteSubslotsLlRr;
      case DsdWireGrouping.u8:
        return l10n.u8ByteInterleavedLrlr;
    }
  }

  void _showDsdWireGroupingDialog(
    BuildContext context,
    Uac2PreferencesService service,
    DsdWireGrouping current,
  ) {
    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.dapNativeByteGrouping,
      builder: (dialogContext) => FlickDialog(
        title: l10n.englishForFilipino.dapNativeByteGrouping,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (grouping, title, subtitle) in [
              (
                DsdWireGrouping.auto,
                l10n.auto,
                l10n.u8ByteInterleavedRecommendedDefault
              ),
              (
                DsdWireGrouping.u32,
                'U32',
                l10n.bitSubslotsLlllRrrrPer
              ),
              (
                DsdWireGrouping.u16,
                'U16',
                l10n.bitSubslotsLlRrPer
              ),
              (
                DsdWireGrouping.u8,
                'U8',
                l10n.byteInterleavedLrlrStream
              ),
            ]) ...[
              _buildDsdOptionTile(
                dialogContext,
                title: title,
                subtitle: subtitle,
                selected: current == grouping,
                onTap: () async {
                  await service.setDsdWireGrouping(grouping);
                  // Applies to the very next wire write — live A/B while a
                  // DAP native-DSD track is playing.
                  rust_audio.audioSetSasWireGrouping(
                    grouping: switch (grouping) {
                      DsdWireGrouping.auto => 2,
                      DsdWireGrouping.u32 => 0,
                      DsdWireGrouping.u16 => 1,
                      DsdWireGrouping.u8 => 2,
                    },
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
            ],
          ],
        ),
        actions: [
          FlickDialogButton(
            label: l10n.englishForFilipino.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showDsdWireVariantDialog(
    BuildContext context,
    Uac2PreferencesService service,
    DsdWireVariant current,
  ) {
    showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.dapNativeBitOrder,
      builder: (dialogContext) => FlickDialog(
        title: l10n.englishForFilipino.dapNativeBitOrder,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (variant, title, subtitle) in [
              (
                DsdWireVariant.auto,
                l10n.auto,
                l10n.beMsbPackingTheDefaultWire
              ),
              (
                DsdWireVariant.beMsb,
                'BE-MSB',
                l10n.bigEndian32BitSubslotMsb
              ),
              (
                DsdWireVariant.leMsb,
                'LE-MSB',
                l10n.littleEndianSubslotMsbFirstBits
              ),
              (
                DsdWireVariant.beLsb,
                'BE-LSB',
                l10n.bigEndianSubslotLsbFirstBit
              ),
              (
                DsdWireVariant.leLsb,
                'LE-LSB',
                l10n.littleEndianSubslotLsbFirstBits
              ),
            ]) ...[
              _buildDsdOptionTile(
                dialogContext,
                title: title,
                subtitle: subtitle,
                selected: current == variant,
                onTap: () async {
                  await service.setDsdWireVariant(variant);
                  // Applies to the very next wire write — live A/B while a
                  // DAP native-DSD track is playing.
                  rust_audio.audioSetSasWireVariant(
                    variant: switch (variant) {
                      DsdWireVariant.auto => 0,
                      DsdWireVariant.beMsb => 0,
                      DsdWireVariant.leMsb => 1,
                      DsdWireVariant.beLsb => 2,
                      DsdWireVariant.leLsb => 3,
                    },
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
            ],
          ],
        ),
        actions: [
          FlickDialogButton(
            label: l10n.englishForFilipino.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDsdOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: enabled
              ? (selected
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : Colors.transparent)
              : AppColors.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: enabled
                ? (selected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.glassBorder)
                : AppColors.glassBorder.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled
                          ? (selected ? AppColors.accent : context.adaptiveTextPrimary)
                          : context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled
                          ? context.adaptiveTextSecondary
                          : context.adaptiveTextSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
