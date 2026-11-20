import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/duration_format.dart';
import 'package:flick/l10n/english_l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/audio_analysis.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Suggested normalization target used by the existing ReplayGain scanner.
/// The analysis view only reports this value; it is never applied or stored.
const double _suggestedGainTargetLufs = -18.0;

const double _spectrogramImageHeight = 190;

const Set<AudioSourceAnalysisStatus> _retryableStatuses = {
  AudioSourceAnalysisStatus.unreadable,
  AudioSourceAnalysisStatus.noAudioStream,
  AudioSourceAnalysisStatus.noSamples,
  AudioSourceAnalysisStatus.cancelled,
  AudioSourceAnalysisStatus.busy,
};

/// Returns null when source analysis can run for [song], otherwise the reason
/// it cannot. Kept in one place so the entry point and the sheet agree.
String? audioAnalysisUnavailableReason(Song song) {
  if (song.sourceType != null && song.sourceType!.isNotEmpty) {
    return l10n.audioAnalysisLocalOnly;
  }
  if (song.startOffsetMs != null || song.endOffsetMs != null) {
    return l10n.audioAnalysisCueUnsupported;
  }
  final path = song.filePath;
  if (path == null || path.isEmpty) {
    return l10n.audioAnalysisUnavailable;
  }
  if (path.startsWith('content://')) {
    return l10n.audioAnalysisDocumentProviderUnsupported;
  }
  if (song.isDsd || song.isWavPack) {
    return l10n.audioAnalysisUnsupportedFormat;
  }
  return null;
}

void showAudioAnalysisSheet(BuildContext context, Song song) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AudioAnalysisSheet(song: song),
  );
}

class _AudioAnalysisSheet extends StatefulWidget {
  const _AudioAnalysisSheet({required this.song});

  final Song song;

  @override
  State<_AudioAnalysisSheet> createState() => _AudioAnalysisSheetState();
}

class _AudioAnalysisSheetState extends State<_AudioAnalysisSheet> {
  AudioSourceAnalysis? _analysis;
  String? _blockedReason;
  String? _failure;
  AudioSourceAnalysisStatus? _status;
  bool _loading = false;
  double _progress = 0;
  int _runId = 0;
  Timer? _progressTimer;
  _SpectrogramView _spectrogramView = _SpectrogramView.all;
  final Map<_SpectrogramView, ui.Image> _spectrogramImages = {};
  final Set<_SpectrogramView> _buildingSpectrograms = {};
  final Set<_SpectrogramView> _failedSpectrograms = {};
  AudioSourceAnalysisJob? _job;
  Future<AudioSourceAnalysis>? _activeDecode;

  String get _path => widget.song.filePath!;

  @override
  void initState() {
    super.initState();
    _blockedReason = audioAnalysisUnavailableReason(widget.song);
    if (_blockedReason == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_run());
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _job?.cancel();
    for (final image in _spectrogramImages.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    if (_blockedReason != null || _loading) return;
    final runId = ++_runId;
    _progressTimer?.cancel();

    _clearSpectrogramImages();
    setState(() {
      _analysis = null;
      _failure = null;
      _status = null;
      _loading = true;
      _progress = 0;
      _spectrogramView = _SpectrogramView.all;
    });

    // A cancelled decode may still be unwinding. Reuse its slot only after
    // it exits; meanwhile the new request can also be cancelled.
    final previous = _activeDecode;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // This run has already replaced the previous run's UI state.
      }
    }
    if (!mounted || runId != _runId) return;

    AudioSourceAnalysisJob? job;
    Future<AudioSourceAnalysis>? decode;
    try {
      final currentJob = createSourceAudioAnalysisJob();
      job = _job = currentJob;
      _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || runId != _runId) return;
        final value = currentJob.progress();
        if (value > _progress) setState(() => _progress = value);
      });
      decode = _activeDecode = currentJob.analyze(path: _path);
      final result = await decode;
      if (!mounted || runId != _runId) return;
      _progressTimer?.cancel();
      setState(() {
        _loading = false;
        _progress = 1;
        _analysis = result;
        _status = result.status;
      });
    } catch (_) {
      if (!mounted || runId != _runId) return;
      _progressTimer?.cancel();
      setState(() {
        _loading = false;
        _failure = l10n.audioAnalysisFailed;
      });
    } finally {
      if (identical(_activeDecode, decode)) _activeDecode = null;
      if (identical(_job, job)) _job = null;
      job?.dispose();
    }
  }

  void _cancel() {
    ++_runId;
    _progressTimer?.cancel();
    _job?.cancel();
    setState(() {
      _loading = false;
      _progress = 0;
      _analysis = null;
      _failure = null;
      _status = AudioSourceAnalysisStatus.cancelled;
    });
  }

  void _clearSpectrogramImages() {
    final images = _spectrogramImages.values.toList();
    _spectrogramImages.clear();
    _buildingSpectrograms.clear();
    _failedSpectrograms.clear();
    if (images.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final image in images) {
        image.dispose();
      }
    });
  }

  String _messageForStatus(AudioSourceAnalysisStatus status) {
    return switch (status) {
      AudioSourceAnalysisStatus.ok => '',
      AudioSourceAnalysisStatus.unsupportedFormat =>
        l10n.audioAnalysisUnsupportedFormat,
      AudioSourceAnalysisStatus.unsupportedMultichannel =>
        l10n.audioAnalysisUnsupportedMultichannel,
      AudioSourceAnalysisStatus.unreadable => l10n.audioAnalysisUnreadable,
      AudioSourceAnalysisStatus.noAudioStream =>
        l10n.audioAnalysisNoAudioStream,
      AudioSourceAnalysisStatus.noSamples => l10n.audioAnalysisNoSamples,
      AudioSourceAnalysisStatus.cancelled => l10n.audioAnalysisCancelled,
      AudioSourceAnalysisStatus.busy => l10n.audioAnalysisBusy,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetSurface(
      scrollable: true,
      padding: EdgeInsets.zero,
      maxHeightRatio: 0.92,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildHeader(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.audioAnalysis,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.audioAnalysisSubtitle,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 12,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_blockedReason != null) {
      return _buildMessage(context, _blockedReason!, canRetry: false);
    }
    if (_loading) {
      return _buildLoading(context);
    }
    if (_failure != null) {
      return _buildMessage(context, _failure!, canRetry: true);
    }
    final analysis = _analysis;
    final status = _status;
    if (analysis == null || status != AudioSourceAnalysisStatus.ok) {
      return _buildMessage(
        context,
        status == null
            ? l10n.audioAnalysisUnavailable
            : _messageForStatus(status),
        canRetry: _retryableStatuses.contains(status),
      );
    }
    return _buildResult(context, analysis);
  }

  Widget _buildMessage(
    BuildContext context,
    String message, {
    required bool canRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 13,
                    height: 1.35,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (canRetry) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.audioAnalysisRetry),
              style: _actionButtonStyle(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final percent = (_progress * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            percent > 0
                ? '${l10n.audioAnalysisAnalyzing} $percent%'
                : l10n.audioAnalysisAnalyzing,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 13,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent > 0 ? _progress : null,
              minHeight: 4,
              backgroundColor: AppColors.glassBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.audioAnalysisSourceNote,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 11,
              height: 1.4,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: context.adaptiveTextSecondary,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l10n.audioAnalysisCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, AudioSourceAnalysis analysis) {
    final channels = analysis.channels;
    final clipped = analysis.clippedSamples.toInt();
    final headroom = analysis.truePeakDb == null ? null : -analysis.truePeakDb!;
    final suggestedGain = analysis.lufs == null
        ? null
        : _suggestedGainTargetLufs - analysis.lufs!;
    final tagGain = widget.song.replaygainTrackGain;
    final tagPeak = widget.song.replaygainTrackPeak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnalysisSection(
          title: l10n.audioAnalysisFileSection,
          children: [
            _AnalysisRow(
              label: l10n.audioAnalysisDuration,
              value: _formatSeconds(analysis.durationSeconds),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisFileSize,
              value: _formatBytes(analysis.fileSizeBytes.toInt()),
            ),
            _AnalysisRow(
              label: l10n.sampleRate,
              value: analysis.sampleRate == null
                  ? '—'
                  : _formatSampleRate(analysis.sampleRate!),
            ),
            _AnalysisRow(
              label: l10n.channels,
              value: switch (channels) {
                null => '—',
                1 => l10n.mono,
                2 => l10n.stereo,
                _ => '$channels',
              },
            ),
            _AnalysisRow(
              label: l10n.bitDepth,
              value: analysis.bitDepth == null
                  ? '—'
                  : '${analysis.bitDepth}-bit',
            ),
          ],
        ),
        _AnalysisSection(
          title: l10n.audioAnalysisLevelsSection,
          children: [
            _AnalysisRow(
              label: l10n.audioAnalysisPeak,
              value: _channelLevels(analysis.channelPeakDb),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisRms,
              value: _channelLevels(analysis.channelRmsDb),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisCrest,
              value: _crestFactor(
                analysis.channelPeakDb,
                analysis.channelRmsDb,
              ),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisBalance,
              value: _balanceLabel(analysis.balanceDb),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisSideMid,
              value: _signedLevel(analysis.sideMidDb),
            ),
          ],
        ),
        _AnalysisSection(
          title: l10n.audioAnalysisLoudnessSection,
          children: [
            _AnalysisRow(
              label: l10n.audioAnalysisIntegratedLoudness,
              value: _lufs(analysis.lufs),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisLoudnessRange,
              value: _loudnessRange(analysis.lra),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisTruePeak,
              value: _truePeak(analysis.truePeakDb),
              warning: analysis.truePeakDb != null && analysis.truePeakDb! > 0,
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisHeadroom,
              value: _signedLevel(headroom),
              warning: headroom != null && headroom < 0,
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisDynamicRange,
              value: _number(analysis.dr),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisSuggestedGain,
              value: _signedLevel(suggestedGain),
            ),
            _Note(
              l10n.audioAnalysisSuggestedGainTarget(
                _suggestedGainTargetLufs.toStringAsFixed(0),
              ),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisClipping,
              value: clipped > 0
                  ? l10n.audioAnalysisClippingCount(clipped)
                  : l10n.audioAnalysisClippingNone,
              warning: analysis.clipping,
            ),
          ],
        ),
        _AnalysisSection(
          title: l10n.audioAnalysisSilenceSection,
          children: [
            _AnalysisRow(
              label: l10n.audioAnalysisLeadingSilence,
              value: _formatSeconds(analysis.leadingSilenceSeconds),
            ),
            _AnalysisRow(
              label: l10n.audioAnalysisTrailingSilence,
              value: _formatSeconds(analysis.trailingSilenceSeconds),
            ),
            if (analysis.silent) _Note(l10n.audioAnalysisAllSilent),
          ],
        ),
        _AnalysisSection(
          title: l10n.audioAnalysisReplayGainSection,
          children: [
            if (tagGain == null && tagPeak == null)
              _AnalysisRow(
                label: l10n.replaygain,
                value: l10n.audioAnalysisNoTag,
              )
            else ...[
              _AnalysisRow(
                label: l10n.audioAnalysisReplayGainTag,
                value: _signedLevel(tagGain),
              ),
              _AnalysisRow(
                label: l10n.audioAnalysisReplayGainPeak,
                value: _tagPeak(tagPeak),
              ),
              _Note(l10n.audioAnalysisNotApplied),
            ],
          ],
        ),
        _AnalysisSection(
          title: l10n.audioAnalysisSpectrogramSection,
          children: [
            if (analysis.spectrogram == null ||
                analysis.spectrogram!.columns == 0)
              _Note(l10n.audioAnalysisSpectrogramUnavailable)
            else
              _buildSpectrogram(context, analysis.spectrogram!),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          l10n.audioAnalysisSourceNote,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 11,
            height: 1.4,
            color: context.adaptiveTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSpectrogram(BuildContext context, AudioSourceSpectrogram data) {
    final view = _spectrogramView;
    final image = _spectrogramImages[view];
    final failed = _failedSpectrograms.contains(view);
    if (image == null && !failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_analysis?.spectrogram, data)) {
          unawaited(_ensureSpectrogramImage(view, data));
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ViewChip(
              label: l10n.all,
              selected: _spectrogramView == _SpectrogramView.all,
              onTap: () => _selectSpectrogramView(_SpectrogramView.all),
            ),
            if (data.rightDb.isNotEmpty) ...[
              _ViewChip(
                label: l10n.left,
                selected: _spectrogramView == _SpectrogramView.left,
                onTap: () => _selectSpectrogramView(_SpectrogramView.left),
              ),
              _ViewChip(
                label: l10n.right,
                selected: _spectrogramView == _SpectrogramView.right,
                onTap: () => _selectSpectrogramView(_SpectrogramView.right),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (failed)
          _Note(l10n.audioAnalysisSpectrogramUnavailable)
        else if (image == null)
          const SizedBox(
            height: _spectrogramImageHeight,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.success,
                ),
              ),
            ),
          )
        else
          _buildSpectrogramImage(context, data, image),
        const SizedBox(height: 8),
        Text(
          l10n.audioAnalysisSpectrogramCaption,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 10,
            color: context.adaptiveTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSpectrogramImage(
    BuildContext context,
    AudioSourceSpectrogram data,
    ui.Image image,
  ) {
    final duration = _analysis?.durationSeconds;
    final ticks = _frequencyTicks(data.maxFrequencyHz);
    return Column(
      children: [
        SizedBox(
          height: _spectrogramImageHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 38,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final frequency in ticks)
                      Positioned(
                        right: 4,
                        top: _frequencyLabelTop(
                          frequency,
                          data.minFrequencyHz,
                          data.maxFrequencyHz,
                        ),
                        child: Text(
                          _frequencyLabel(frequency),
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 9,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColoredBox(
                    color: AppColors.surfaceDark,
                    child: RawImage(
                      image: image,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _axisLabel(context, '0:00'),
                  _axisLabel(context, _midTime(duration)),
                  _axisLabel(context, _endTime(duration)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectSpectrogramView(_SpectrogramView view) {
    if (_spectrogramView == view) return;
    setState(() => _spectrogramView = view);
  }

  Future<void> _ensureSpectrogramImage(
    _SpectrogramView view,
    AudioSourceSpectrogram data,
  ) async {
    final runId = _runId;
    if (_spectrogramImages.containsKey(view) ||
        _buildingSpectrograms.contains(view)) {
      return;
    }
    _buildingSpectrograms.add(view);
    try {
      final image = await _renderSpectrogram(data, view);
      if (!mounted || runId != _runId) {
        image.dispose();
        return;
      }
      setState(() {
        _buildingSpectrograms.remove(view);
        _spectrogramImages[view] = image;
      });
    } catch (_) {
      if (!mounted || runId != _runId) return;
      setState(() {
        _buildingSpectrograms.remove(view);
        _failedSpectrograms.add(view);
      });
    }
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 2),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 12,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                fontWeight: warning ? FontWeight.w600 : FontWeight.w400,
                color: warning ? AppColors.error : context.adaptiveTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontSize: 11,
          height: 1.4,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.glassBorderStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.textTertiary : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? context.adaptiveTextPrimary
                : context.adaptiveTextSecondary,
          ),
        ),
      ),
    );
  }
}

enum _SpectrogramView { all, left, right }

ButtonStyle _actionButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    foregroundColor: context.adaptiveTextPrimary,
    side: const BorderSide(color: AppColors.glassBorderStrong),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _formatSampleRate(int rate) {
  if (rate >= 1000000) return l10n.mhz((rate / 1000000).toStringAsFixed(2));
  if (rate >= 1000) return l10n.khz2((rate / 1000).toStringAsFixed(1));
  return l10n.hz(rate);
}

String _formatSeconds(double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0) return '—';
  final duration = Duration(microseconds: (seconds * 1000000).round());
  return formatDuration(duration);
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit >= 2 ? 1 : 0;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String _level(double? value) {
  if (value == null || !value.isFinite || value <= -119.9) return '—';
  return '${value.toStringAsFixed(1)} dBFS';
}

String _signedLevel(double? value) {
  if (value == null || !value.isFinite || value <= -119.9) return '—';
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)} dB';
}

String _channelLevels(Float64List values) {
  if (values.isEmpty) return '—';
  if (values.length == 1) return _level(values[0]);
  return 'L ${_level(values[0])} · R ${_level(values[1])}';
}

String _crestFactor(Float64List peaks, Float64List rms) {
  if (peaks.isEmpty || rms.isEmpty) return '—';
  String one(int index) {
    if (index >= peaks.length || index >= rms.length) return '—';
    if (peaks[index] <= -119.9 || rms[index] <= -119.9) return '—';
    return '${(peaks[index] - rms[index]).toStringAsFixed(1)} dB';
  }

  if (peaks.length == 1) return one(0);
  return 'L ${one(0)} · R ${one(1)}';
}

String _balanceLabel(double? balanceDb) {
  if (balanceDb == null || !balanceDb.isFinite) return '—';
  if (balanceDb.abs() < 0.05) return '0.0 dB';
  if (balanceDb > 0) {
    return 'L +${balanceDb.toStringAsFixed(1)} dB';
  }
  return 'R +${(-balanceDb).toStringAsFixed(1)} dB';
}

String _lufs(double? value) {
  if (value == null || !value.isFinite) return '—';
  return '${value.toStringAsFixed(1)} LUFS';
}

String _loudnessRange(double? value) {
  if (value == null || !value.isFinite) return '—';
  return '${value.toStringAsFixed(1)} LU';
}

String _truePeak(double? value) {
  if (value == null || !value.isFinite) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)} dBTP';
}

String _number(double? value) {
  if (value == null || !value.isFinite) return '—';
  return value.toStringAsFixed(1);
}

String _tagPeak(double? linear) {
  if (linear == null || !linear.isFinite || linear <= 0) return '—';
  final db = 20 * math.log(linear) / math.ln10;
  return '${linear.toStringAsFixed(3)} · ${db.toStringAsFixed(1)} dBFS';
}

String _midTime(double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds <= 0) return '—';
  return _formatSeconds(seconds / 2);
}

String _endTime(double? seconds) => _formatSeconds(seconds);

Widget _axisLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: 9,
      color: context.adaptiveTextSecondary,
    ),
  );
}

List<int> _frequencyTicks(double maxFrequencyHz) {
  const candidates = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
  return [
    for (final frequency in candidates)
      if (frequency <= maxFrequencyHz) frequency,
  ];
}

double _frequencyLabelTop(
  int frequency,
  double minFrequencyHz,
  double maxFrequencyHz,
) {
  final fraction = _logPosition(
    frequency.toDouble(),
    minFrequencyHz,
    maxFrequencyHz,
  );
  final top = (1 - fraction) * _spectrogramImageHeight - 6;
  return top.clamp(0.0, _spectrogramImageHeight - 12);
}

double _logPosition(
  double frequency,
  double minFrequencyHz,
  double maxFrequencyHz,
) {
  if (frequency <= minFrequencyHz) return 0;
  if (frequency >= maxFrequencyHz) return 1;
  return math.log(frequency / minFrequencyHz) /
      math.log(maxFrequencyHz / minFrequencyHz);
}

String _frequencyLabel(int frequency) {
  if (frequency >= 1000) return '${frequency ~/ 1000}k';
  return '$frequency';
}

Future<ui.Image> _renderSpectrogram(
  AudioSourceSpectrogram data,
  _SpectrogramView view,
) {
  final columns = data.columns;
  final bins = data.bins;
  final pixels = Uint8List(columns * bins * 4);
  final left = data.leftDb;
  final right = data.rightDb;
  final all = view == _SpectrogramView.all;
  final useRight = view == _SpectrogramView.right && right.isNotEmpty;
  final lut = _spectrogramLut;

  for (var column = 0; column < columns; column++) {
    final base = column * bins;
    for (var bin = 0; bin < bins; bin++) {
      final l = left[base + bin];
      double db;
      if (all) {
        final r = right.isEmpty ? l : right[base + bin];
        final maxDb = math.max(l, r);
        final minDb = math.min(l, r);
        db =
            maxDb +
            10 * math.log(1 + math.pow(10, (minDb - maxDb) / 10)) / math.ln10 -
            3.010299956639812;
      } else if (useRight) {
        db = right[base + bin];
      } else {
        db = l;
      }
      final level = ((db + 120) / 120).clamp(0.0, 1.0);
      final lutIndex = (level * 255).round() * 3;
      final row = bins - 1 - bin;
      final pixel = (row * columns + column) * 4;
      pixels[pixel] = lut[lutIndex];
      pixels[pixel + 1] = lut[lutIndex + 1];
      pixels[pixel + 2] = lut[lutIndex + 2];
      pixels[pixel + 3] = 255;
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    columns,
    bins,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

final Uint8List _spectrogramLut = _buildSpectrogramLut();

Uint8List _buildSpectrogramLut() {
  const stops = <(double, int, int, int)>[
    (0.0, 5, 5, 13),
    (0.16, 26, 11, 61),
    (0.34, 85, 15, 121),
    (0.52, 176, 26, 122),
    (0.68, 232, 75, 47),
    (0.84, 247, 176, 43),
    (1.0, 255, 255, 242),
  ];
  final lut = Uint8List(256 * 3);
  var stop = 0;
  for (var i = 0; i < 256; i++) {
    final t = i / 255;
    while (stop < stops.length - 2 && t > stops[stop + 1].$1) {
      stop++;
    }
    final start = stops[stop];
    final end = stops[stop + 1];
    final fraction = ((t - start.$1) / (end.$1 - start.$1)).clamp(0.0, 1.0);
    lut[i * 3] = (start.$2 + (end.$2 - start.$2) * fraction).round();
    lut[i * 3 + 1] = (start.$3 + (end.$3 - start.$3) * fraction).round();
    lut[i * 3 + 2] = (start.$4 + (end.$4 - start.$4) * fraction).round();
  }
  return lut;
}
