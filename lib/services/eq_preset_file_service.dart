import 'dart:convert';

import 'package:flick/models/eq_limits.dart';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/eq_preset_service.dart';
import 'package:flick/l10n/l10n.dart';

/// Result of parsing a preset file: the preset plus any values that had to be
/// clamped to Flick's supported ranges (so the UI can surface them instead of
/// silently altering the preset).
class EqPresetImportResult {
  const EqPresetImportResult({required this.preset, required this.warnings});

  final EqPreset preset;
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

class EqPresetFileService {
  static final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');

  static const Map<ParametricBandType, String> _bandTypeCodes = {
    ParametricBandType.peaking: 'PK',
    ParametricBandType.lowShelf: 'LS',
    ParametricBandType.highShelf: 'HS',
    ParametricBandType.lowPass: 'LP',
    ParametricBandType.highPass: 'HP',
    ParametricBandType.bandPass: 'BP',
    ParametricBandType.notch: 'NO',
    ParametricBandType.allPass: 'AP',
  };

  static final Map<String, ParametricBandType> _codeToBandType = {
    for (final entry in _bandTypeCodes.entries) entry.value: entry.key,
    // AutoEq emits LSC/HSC for shelves; EqualizerAPO treats them as LS/HS.
    'LSC': ParametricBandType.lowShelf,
    'HSC': ParametricBandType.highShelf,
  };

  static final RegExp _preampLinePattern = RegExp(
    r'^Preamp:\s*([+-]?\d+(?:\.\d+)?)\s*dB$',
    caseSensitive: false,
  );

  static final RegExp _filterLinePattern = RegExp(
    r'^Filter\s+(\d+):\s+(ON|OFF)\s+([A-Za-z]+)\s+Fc\s+([+-]?\d+(?:\.\d+)?)\s+Hz(?:\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB)?\s+Q\s+([+-]?\d+(?:\.\d+)?)$',
    caseSensitive: false,
  );

  const EqPresetFileService();

  String toJsonText(EqPreset preset) => _jsonEncoder.convert(preset.toJson());

  String toTxtText(EqPreset preset) {
    final buffer = StringBuffer()
      ..writeln('Preamp: ${preset.preampDb.toStringAsFixed(1)} dB');

    final bands = preset.mode == EqMode.parametric
        ? preset.parametricBands
        : _graphicBandsAsParametric(preset.graphicGainsDb);

    for (var i = 0; i < bands.length; i++) {
      final band = bands[i];
      final typeCode = _bandTypeCodes[band.type] ?? 'PK';
      final gainSegment = band.type.supportsGain
          ? ' Gain ${band.gainDb.toStringAsFixed(1)} dB'
          : '';
      buffer.writeln(
        'Filter ${i + 1}: ${band.enabled ? 'ON' : 'OFF'} '
        '$typeCode Fc ${_formatHz(band.frequencyHz)} Hz'
        '$gainSegment Q ${band.q.toStringAsFixed(3)}',
      );
    }

    return buffer.toString().trimRight();
  }

  EqPreset fromFileText({required String text, required String fileName}) {
    return parseFileText(text: text, fileName: fileName).preset;
  }

  EqPresetImportResult parseFileText({
    required String text,
    required String fileName,
  }) {
    final normalizedName = _baseNameWithoutExtension(fileName).trim();
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw FormatException(l10n.expectedAJsonObject);
      }
      final json = decoded.cast<String, dynamic>();
      final mode = json['mode'];
      if (mode != null && !EqMode.values.any((value) => value.name == mode)) {
        throw FormatException(l10n.eqPresetUnsupportedSettings);
      }
      final rawBands = json['parametricBands'];
      if (rawBands != null) {
        if (rawBands is! List || rawBands.length > EqLimits.maxBands) {
          throw FormatException(l10n.eqPresetUnsupportedSettings);
        }
        for (final band in rawBands) {
          if (band is! Map ||
              !ParametricBandType.values.any(
                (type) => type.name == band['type'],
              )) {
            throw FormatException(l10n.eqPresetUnsupportedSettings);
          }
        }
      }
      if (mode == EqMode.parametric.name &&
          (rawBands is! List || rawBands.isEmpty)) {
        throw FormatException(l10n.noFiltersFoundInPresetFile);
      }
      final preset = EqPreset.fromJson(json);
      if (preset.graphicGainsDb.length !=
          EqualizerState.defaultGraphicFrequenciesHz.length) {
        throw FormatException(l10n.eqPresetUnsupportedSettings);
      }
      final warnings = <String>[];
      double adjust(double value, double min, double max, String label) {
        _requireFinite(value);
        final clamped = value.clamp(min, max).toDouble();
        if (clamped != value) {
          warnings.add(_adjustmentWarning(label, value, clamped));
        }
        return clamped;
      }

      return EqPresetImportResult(
        preset: preset.copyWith(
          name: preset.name.trim().isEmpty ? normalizedName : preset.name,
          preampDb: adjust(
            preset.preampDb,
            EqLimits.minPreampDb,
            EqLimits.maxPreampDb,
            '${l10n.preamp} (dB)',
          ),
          graphicGainsDb: List.unmodifiable([
            for (var i = 0; i < preset.graphicGainsDb.length; i++)
              adjust(
                preset.graphicGainsDb[i],
                EqLimits.minGainDb,
                EqLimits.maxGainDb,
                '${l10n.graphicEq} · ${l10n.band} ${i + 1} (dB)',
              ),
          ]),
          parametricBands: List.unmodifiable([
            for (var i = 0; i < preset.parametricBands.length; i++)
              preset.parametricBands[i].copyWith(
                frequencyHz: adjust(
                  preset.parametricBands[i].frequencyHz,
                  EqLimits.minFrequencyHz,
                  EqLimits.maxFrequencyHz,
                  '${l10n.filter} ${i + 1} · ${l10n.frequency} (Hz)',
                ),
                gainDb: adjust(
                  preset.parametricBands[i].gainDb,
                  EqLimits.minGainDb,
                  EqLimits.maxGainDb,
                  '${l10n.filter} ${i + 1} · ${l10n.gain} (dB)',
                ),
                q: adjust(
                  preset.parametricBands[i].q,
                  EqLimits.minQ,
                  EqLimits.maxQ,
                  '${l10n.filter} ${i + 1} · Q',
                ),
              ),
          ]),
          bassDb: adjust(
            preset.bassDb,
            EqLimits.minGainDb,
            EqLimits.maxGainDb,
            '${l10n.bass} (dB)',
          ),
          midDb: adjust(
            preset.midDb,
            EqLimits.minGainDb,
            EqLimits.maxGainDb,
            '${l10n.mid} (dB)',
          ),
          trebleDb: adjust(
            preset.trebleDb,
            EqLimits.minGainDb,
            EqLimits.maxGainDb,
            '${l10n.treble} (dB)',
          ),
        ),
        warnings: List.unmodifiable(warnings),
      );
    }

    return _parseTxt(text: text, fileName: normalizedName);
  }

  EqPresetImportResult _parseTxt({
    required String text,
    required String fileName,
  }) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      throw FormatException(l10n.presetFileIsEmpty);
    }

    double preampDb = 0.0;
    var lineIndex = 0;
    final preampMatch = _preampLinePattern.firstMatch(lines.first);
    if (preampMatch != null) {
      preampDb = double.parse(preampMatch.group(1)!);
      lineIndex = 1;
    }

    final warnings = <String>[];
    _requireFinite(preampDb);
    final clampedPreamp = preampDb
        .clamp(EqLimits.minPreampDb, EqLimits.maxPreampDb)
        .toDouble();
    if (clampedPreamp != preampDb) {
      warnings.add(
        _adjustmentWarning('${l10n.preamp} (dB)', preampDb, clampedPreamp),
      );
    }
    preampDb = clampedPreamp;
    final bands = <ParametricBand>[];
    final filterNumbers = <int>{};
    for (var i = lineIndex; i < lines.length; i++) {
      final line = lines[i];
      final match = _filterLinePattern.firstMatch(line);
      if (match == null) {
        throw FormatException(l10n.eqPresetInvalidFilter(line));
      }

      final filterNumber = match.group(1)!;
      if (!filterNumbers.add(int.parse(filterNumber))) {
        throw FormatException(l10n.eqPresetDuplicateFilter(filterNumber));
      }
      final typeCode = match.group(3)!.toUpperCase();
      final type = _codeToBandType[typeCode];
      if (type == null) {
        throw FormatException(l10n.eqPresetUnsupportedFilter(typeCode));
      }

      final rawFreq = double.parse(match.group(4)!);
      final clampedFreq = _clampFrequency(rawFreq);
      if (clampedFreq != rawFreq) {
        warnings.add(
          _adjustmentWarning(
            '${l10n.filter} $filterNumber · ${l10n.frequency} (Hz)',
            rawFreq,
            clampedFreq,
          ),
        );
      }

      final gainMatch = match.group(5);
      if (type.supportsGain && gainMatch == null) {
        throw FormatException(l10n.eqPresetMissingGain(filterNumber));
      }
      var gainDb = 0.0;
      if (type.supportsGain && gainMatch != null) {
        final rawGain = double.parse(gainMatch);
        gainDb = _clampGain(rawGain);
        if (gainDb != rawGain) {
          warnings.add(
            _adjustmentWarning(
              '${l10n.filter} $filterNumber · ${l10n.gain} (dB)',
              rawGain,
              gainDb,
            ),
          );
        }
      }

      final rawQ = double.parse(match.group(6)!);
      final clampedQ = _clampQ(rawQ);
      if (clampedQ != rawQ) {
        warnings.add(
          _adjustmentWarning(
            '${l10n.filter} $filterNumber · Q',
            rawQ,
            clampedQ,
          ),
        );
      }

      bands.add(
        ParametricBand(
          enabled: match.group(2)!.toUpperCase() == 'ON',
          frequencyHz: clampedFreq,
          gainDb: gainDb,
          q: clampedQ,
          type: type,
        ),
      );
    }

    if (bands.isEmpty) {
      throw FormatException(l10n.noFiltersFoundInPresetFile);
    }
    if (bands.length > EqLimits.maxBands) {
      throw FormatException(l10n.eqPresetUnsupportedSettings);
    }

    return EqPresetImportResult(
      preset: EqPreset(
        id: '',
        name: fileName.isEmpty ? l10n.importedPreset : fileName,
        enabled: true,
        mode: EqMode.parametric,
        preampDb: preampDb,
        graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
        parametricBands: List<ParametricBand>.unmodifiable(bands),
      ),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  List<ParametricBand> _graphicBandsAsParametric(List<double> gainsDb) {
    final frequencies = EqualizerState.defaultGraphicFrequenciesHz;
    return List<ParametricBand>.generate(
      gainsDb.length,
      (index) => ParametricBand(
        enabled: gainsDb[index].abs() >= 0.01,
        frequencyHz: frequencies[index],
        gainDb: _clampGain(gainsDb[index]),
        q: 1.0,
      ),
      growable: false,
    );
  }

  static String _baseNameWithoutExtension(String fileName) {
    final slashIndex = fileName.lastIndexOf(RegExp(r'[/\\]'));
    final base = slashIndex >= 0
        ? fileName.substring(slashIndex + 1)
        : fileName;
    final dotIndex = base.lastIndexOf('.');
    return dotIndex > 0 ? base.substring(0, dotIndex) : base;
  }

  static String _formatHz(double hz) {
    final rounded = hz.roundToDouble();
    if ((hz - rounded).abs() < 0.001) {
      return rounded.toStringAsFixed(0);
    }
    return hz.toStringAsFixed(1);
  }

  static String _formatValue(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static double _clampFrequency(double value) {
    _requireFinite(value);
    return value
        .clamp(EqLimits.minFrequencyHz, EqLimits.maxFrequencyHz)
        .toDouble();
  }

  static double _clampGain(double value) {
    _requireFinite(value);
    return value
        .clamp(EqualizerNotifier.gainMinDb, EqualizerNotifier.gainMaxDb)
        .toDouble();
  }

  static double _clampQ(double value) {
    _requireFinite(value);
    return value
        .clamp(EqualizerNotifier.qMin, EqualizerNotifier.qMax)
        .toDouble();
  }

  static void _requireFinite(double value) {
    if (!value.isFinite) {
      throw FormatException(l10n.eqPresetUnsupportedSettings);
    }
  }

  static String _adjustmentWarning(
    String field,
    double value,
    double adjusted,
  ) => l10n.eqPresetValueAdjusted(
    field,
    _formatValue(value),
    _formatValue(adjusted),
  );
}
