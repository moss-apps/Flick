import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/l10n/english_l10n.dart';

enum AudioSignalReportPage { source, urb, recorded }

/// A readout of known file, USB transport, or rip-log information.
/// Transport values are a snapshot supplied by the caller, not live telemetry.
class AudioSignalReport extends StatelessWidget {
  const AudioSignalReport({
    super.key,
    required this.song,
    required this.diagnostics,
    required this.page,
    required this.expanded,
  });

  final Song song;
  final AudioOutputDiagnostics? diagnostics;
  final AudioSignalReportPage page;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final report = switch (page) {
      AudioSignalReportPage.source => _sourceReport(song),
      AudioSignalReportPage.urb => _urbReport(diagnostics?.urbTransport),
      AudioSignalReportPage.recorded => _recordedReport(song),
    };

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              report.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 12,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      children: [
        Text(
          report.headline,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          report.summary,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          report.description,
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 13,
            height: 1.35,
            color: context.adaptiveTextSecondary,
          ),
        ),
        if (report.fields.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final field in report.fields) _ReportRow(field: field),
        ],
        if (report.buffer != null) ...[
          const SizedBox(height: 22),
          _BufferMeter(buffer: report.buffer!),
        ],
      ],
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.headline,
    required this.summary,
    required this.description,
    this.fields = const [],
    this.buffer,
  });

  final String headline;
  final String summary;
  final String description;
  final List<_ReportField> fields;
  final _BufferData? buffer;
}

class _ReportField {
  const _ReportField(this.label, this.value, {this.status});

  final String label;
  final String value;
  final _ReportStatus? status;
}

enum _ReportStatus { good, warning }

class _BufferData {
  const _BufferData(this.fill, this.capacity, this.target);

  final int fill;
  final int capacity;
  final int? target;
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

String _reported(String? value) =>
    _hasValue(value) ? value! : l10n.signalNotReported;

String _formatHz(int rate) {
  if (rate >= 1000000) return l10n.mhz((rate / 1000000).toStringAsFixed(2));
  if (rate >= 1000) return l10n.khz2((rate / 1000).toStringAsFixed(1));
  return l10n.hz(rate);
}

_ReportData _sourceReport(Song song) {
  final rate = song.sampleRate;
  final depth = song.bitDepth;
  final format = song.fileType.toUpperCase();
  final headline = song.isDsd ? '$format · ${song.dsdRateLabel}' : format;
  final summary = [
    if (rate != null) _formatHz(rate),
    if (song.isDsd) '1-bit' else if (depth != null) '$depth-bit',
  ].join(' · ');

  return _ReportData(
    headline: headline,
    summary: summary.isEmpty ? l10n.signalSourceDetails : summary,
    description: l10n.signalSourceDescription,
    fields: [
      _ReportField(l10n.signalFileFormat, format),
      _ReportField(
        song.isDsd ? l10n.signalDsdBitRate : l10n.sampleRate,
        rate == null ? l10n.signalNotReported : _formatHz(rate),
      ),
      _ReportField(
        l10n.bitDepth,
        song.isDsd
            ? '1-bit DSD'
            : depth == null
            ? l10n.signalNotReported
            : '$depth-bit',
      ),
      if (song.resolution != null && song.resolution!.trim().isNotEmpty)
        _ReportField(l10n.resolution, song.resolution!),
    ],
  );
}

_ReportData _urbReport(UrbTransportInfo? urb) {
  if (urb == null) {
    return _ReportData(
      headline: l10n.signalUsbUnavailable,
      summary: l10n.noUrbData,
      description: l10n.signalUsbMissingDescription,
    );
  }

  final endpoint = urb.activeEndpointAddress;
  final endpointLabel = endpoint == null
      ? l10n.signalNotReported
      : '0x${endpoint.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  final fill = urb.bufferFillMs;
  final capacity = urb.bufferCapacityMs;
  final target = urb.bufferTargetMs;
  final validBuffer =
      fill != null && capacity != null && capacity > 0 && fill >= 0;
  final snapshotDetails = [
    if (endpoint != null) 'EP $endpointLabel',
    if (urb.transportFormat != null && urb.transportFormat!.isNotEmpty)
      urb.transportFormat!,
  ].join(' · ');

  return _ReportData(
    headline: l10n.signalUsbTransport,
    summary: snapshotDetails.isEmpty
        ? l10n.signalSnapshotAtOpen
        : '${l10n.signalSnapshot} · $snapshotDetails',
    description: l10n.signalUsbDescription,
    fields: [
      _ReportField(l10n.endpoint, endpointLabel),
      _ReportField(
        l10n.signalAltSetting,
        urb.activeAltSetting?.toString() ?? l10n.signalNotReported,
      ),
      _ReportField(l10n.signalTransportFormat, _reported(urb.transportFormat)),
      _ReportField(l10n.signalSyncType, _reported(urb.activeSyncType)),
      _ReportField(l10n.signalUsageType, _reported(urb.activeUsageType)),
      _ReportField(
        l10n.signalSubslot,
        urb.transportSubslot == null
            ? l10n.signalNotReported
            : '${urb.transportSubslot} B',
      ),
      _ReportField(
        l10n.resolution,
        urb.transportBitResolution == null
            ? l10n.signalNotReported
            : '${urb.transportBitResolution}-bit',
      ),
      _ReportField(
        l10n.signalMaxPacket,
        urb.activeMaxPacketBytes == null
            ? l10n.signalNotReported
            : '${urb.activeMaxPacketBytes} B',
      ),
      _ReportField(
        l10n.signalServiceInterval,
        urb.activeServiceIntervalUs == null
            ? l10n.signalNotReported
            : '${urb.activeServiceIntervalUs} µs',
      ),
      _ReportField(
        l10n.signalFramesPerPacket,
        urb.framesPerPacket?.toString() ?? l10n.signalNotReported,
      ),
      _ReportField(
        l10n.signalBufferFill,
        fill == null ? l10n.signalNotReported : '$fill ms',
      ),
      _ReportField(
        l10n.signalBufferTarget,
        target == null ? l10n.signalNotReported : '$target ms',
      ),
      _ReportField(
        l10n.signalBufferCapacity,
        capacity == null ? l10n.signalNotReported : '$capacity ms',
      ),
      _ReportField(
        l10n.signalUnderruns,
        urb.underrunCount?.toString() ?? l10n.signalNotReported,
        status: urb.underrunCount != null && urb.underrunCount! > 0
            ? _ReportStatus.warning
            : null,
      ),
      _ReportField(
        l10n.signalDriftFromTarget,
        urb.driftMsFromTarget == null
            ? l10n.signalNotReported
            : '${urb.driftMsFromTarget} ms',
      ),
    ],
    buffer: validBuffer ? _BufferData(fill, capacity, target) : null,
  );
}

_ReportData _recordedReport(Song song) {
  final hasRipData =
      _hasValue(song.ripper) ||
      _hasValue(song.readMode) ||
      _hasValue(song.testCrc) ||
      _hasValue(song.copyCrc) ||
      song.accurateRip != null;
  if (!hasRipData) {
    return _ReportData(
      headline: l10n.noRipData,
      summary: l10n.signalRecordingUnavailable,
      description: l10n.signalNoRipDescription,
    );
  }

  final testCrc = song.testCrc;
  final copyCrc = song.copyCrc;
  final hasBothCrc =
      testCrc != null &&
      testCrc.trim().isNotEmpty &&
      copyCrc != null &&
      copyCrc.trim().isNotEmpty;
  final crcMatches =
      hasBothCrc &&
      testCrc.trim().toUpperCase() == copyCrc.trim().toUpperCase();
  final crcResult = hasBothCrc
      ? (crcMatches ? l10n.signalCrcMatch : l10n.signalCrcMismatch)
      : l10n.signalCrcCannotCompare;
  final accurateRip = song.accurateRip;
  final verification = accurateRip == true
      ? l10n.signalAccurateVerified
      : accurateRip == false
      ? l10n.signalAccurateUnverified
      : l10n.signalVerificationMissing;

  return _ReportData(
    headline: l10n.signalRipProvenance,
    summary: hasBothCrc
        ? '${l10n.signalCrcComparison}: $crcResult · $verification'
        : verification,
    description: l10n.signalRipDescription,
    fields: [
      _ReportField(l10n.signalRipper, _reported(song.ripper)),
      _ReportField(l10n.readMode, _reported(song.readMode)),
      _ReportField(l10n.signalTestCrc, _reported(testCrc)),
      _ReportField(l10n.signalCopyCrc, _reported(copyCrc)),
      _ReportField(
        l10n.signalCrcComparison,
        crcResult,
        status: !hasBothCrc
            ? null
            : crcMatches
            ? _ReportStatus.good
            : _ReportStatus.warning,
      ),
      _ReportField(
        l10n.accuraterip,
        accurateRip == null
            ? l10n.signalNotReported
            : accurateRip
            ? l10n.signalVerifiedInLog
            : l10n.signalNotVerified,
        status: accurateRip == true ? _ReportStatus.good : null,
      ),
    ],
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.field});

  final _ReportField field;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (field.status) {
      _ReportStatus.good => AppColors.success,
      _ReportStatus.warning => AppColors.error,
      null => context.adaptiveTextPrimary,
    };
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
            width: 108,
            child: Text(
              field.label,
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
              field.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                fontWeight: field.status == null
                    ? FontWeight.w400
                    : FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static occupancy and target marks, drawn only when capacity and fill exist.
class _BufferMeter extends StatelessWidget {
  const _BufferMeter({required this.buffer});

  final _BufferData buffer;

  @override
  Widget build(BuildContext context) {
    final fraction = (buffer.fill / buffer.capacity).clamp(0.0, 1.0);
    final target = buffer.target;
    final targetFraction =
        target != null && target >= 0 && target <= buffer.capacity
        ? target / buffer.capacity
        : null;

    return Semantics(
      label:
          '${l10n.signalBufferOccupancy}: ${buffer.fill} / ${buffer.capacity} ms${targetFraction == null ? '' : ', ${l10n.signalTarget} $target ms'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.signalBufferOccupancy,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 12,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 4, color: AppColors.glassBorderStrong),
                  Container(
                    height: 4,
                    width: constraints.maxWidth * fraction,
                    color: context.adaptiveTextPrimary,
                  ),
                  if (targetFraction != null)
                    Positioned(
                      left: (constraints.maxWidth * targetFraction - 1).clamp(
                        0.0,
                        constraints.maxWidth - 2,
                      ),
                      child: Container(
                        width: 2,
                        height: 12,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            targetFraction == null
                ? '${buffer.fill} / ${buffer.capacity} ms'
                : '${buffer.fill} / ${buffer.capacity} ms   ·   ${l10n.signalTarget} $target ms',
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 12,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
