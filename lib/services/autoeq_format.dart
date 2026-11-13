import 'dart:convert';

import 'package:flick/models/eq_limits.dart';

/// Strict, Flutter-independent AutoEq parsing shared by the app and generator.
/// Unlike manual preset imports, catalog data must never be silently clamped.
class AutoEqFilter {
  const AutoEqFilter(this.frequencyHz, this.gainDb, this.q, this.type);

  final double frequencyHz;
  final double gainDb;
  final double q;
  final String type;

  factory AutoEqFilter.fromJson(List<dynamic> values) {
    if (values.length != 4 || values[3] is! String) {
      throw const FormatException('Invalid AutoEq filter');
    }
    final code = (values[3] as String).toUpperCase();
    final type = switch (code) {
      'LSC' => 'LS',
      'HSC' => 'HS',
      _ => code,
    };
    // AutoEq parametric results use these three filter types. Do not substitute
    // an unknown filter with peaking (or a phase-changing all-pass with bypass).
    if (!const {'PK', 'LS', 'HS'}.contains(type)) {
      throw FormatException('Unsupported AutoEq filter type: $code');
    }
    return AutoEqFilter(
      _number(
        values[0],
        'frequency',
        EqLimits.minFrequencyHz,
        EqLimits.maxFrequencyHz,
      ),
      _number(values[1], 'gain', EqLimits.minGainDb, EqLimits.maxGainDb),
      _number(values[2], 'Q', EqLimits.minQ, EqLimits.maxQ),
      type,
    );
  }

  List<dynamic> toJson() => [frequencyHz, gainDb, q, type];
}

class AutoEqProfile {
  const AutoEqProfile._(this.preampDb, this.filters);

  final double preampDb;
  final List<AutoEqFilter> filters;

  factory AutoEqProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['g'];
    if (raw is! List || raw.isEmpty || raw.length > EqLimits.maxBands) {
      throw const FormatException('Unsupported AutoEq band count');
    }
    return AutoEqProfile._(
      _number(json['pa'], 'preamp', EqLimits.minPreampDb, EqLimits.maxPreampDb),
      List.unmodifiable(
        raw.map((band) {
          if (band is! List) {
            throw const FormatException('Invalid AutoEq filter');
          }
          return AutoEqFilter.fromJson(band);
        }),
      ),
    );
  }

  static final _preamp = RegExp(
    r'^Preamp:\s*([+-]?\d+(?:\.\d+)?)\s*dB$',
    caseSensitive: false,
  );
  static final _filter = RegExp(
    r'^Filter\s+(\d+):\s+(ON|OFF)\s+([A-Za-z]+)\s+Fc\s+([+-]?\d+(?:\.\d+)?)\s+Hz\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB\s+Q\s+([+-]?\d+(?:\.\d+)?)$',
    caseSensitive: false,
  );

  factory AutoEqProfile.parse(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const FormatException('Empty AutoEq preset');
    final preamp = _preamp.firstMatch(lines.first);
    if (preamp == null) {
      throw const FormatException('AutoEq preset must include a preamp');
    }
    final filters = <List<dynamic>>[];
    final numbers = <int>{};
    for (final line in lines.skip(1)) {
      final match = _filter.firstMatch(line);
      if (match == null) throw FormatException('Invalid AutoEq filter: $line');
      if (!numbers.add(int.parse(match[1]!))) {
        throw const FormatException('Duplicate AutoEq filter number');
      }
      final values = [
        double.parse(match[4]!),
        double.parse(match[5]!),
        double.parse(match[6]!),
        match[3]!,
      ];
      // Validate disabled filters too, but never activate them during import.
      AutoEqFilter.fromJson(values);
      if (match[2]!.toUpperCase() == 'ON') filters.add(values);
    }
    return AutoEqProfile.fromJson({
      'pa': double.parse(preamp[1]!),
      'g': filters,
    });
  }

  Map<String, dynamic> toJson() => {
    'pa': preampDb,
    'g': filters.map((filter) => filter.toJson()).toList(),
  };
}

/// One exact model/variant chosen by upstream's recommended results index.
class AutoEqRecommendation {
  const AutoEqRecommendation._(
    this.name,
    this.directory,
    this.source,
    this.type,
    this.rig,
  );

  final String name;
  final String directory;
  final String source;
  final String type;
  final String? rig;

  String get path => '$directory/$name ParametricEQ.txt';

  static List<AutoEqRecommendation> parseIndex(String markdown) {
    final entries = <AutoEqRecommendation>[];
    final paths = <String>{};
    // Greedy path capture intentionally retains parentheses in model names.
    final link = RegExp(r'^- \[(.+)\]\(\./(.+)\)$');
    final category = RegExp(r'(?:^| )(in-ear|over-ear|earbud)$');
    for (final line in const LineSplitter().convert(markdown)) {
      if (!line.startsWith('- [')) continue;
      final match = link.firstMatch(line.trimRight());
      if (match == null) {
        throw FormatException('Invalid AutoEq index line: $line');
      }
      final name = match[1]!;
      final directory = 'results/${Uri.decodeComponent(match[2]!)}';
      final parts = directory.split('/');
      if (parts.length != 4 ||
          parts.last != name ||
          parts.any(
            (p) => p.isEmpty || p == '.' || p == '..' || p.contains('\\'),
          )) {
        throw FormatException('Invalid AutoEq result path: $directory');
      }
      final typeMatch = category.firstMatch(parts[2]);
      if (typeMatch == null) {
        throw FormatException('Unknown headphone type: ${parts[2]}');
      }
      final rig = parts[2].substring(0, typeMatch.start).trim();
      if (!paths.add(directory)) {
        throw FormatException('Duplicate AutoEq result: $directory');
      }
      entries.add(
        AutoEqRecommendation._(
          name,
          directory,
          parts[1],
          typeMatch[1]!,
          rig.isEmpty ? null : rig,
        ),
      );
    }
    if (entries.isEmpty) {
      throw const FormatException('Empty AutoEq recommended index');
    }
    return List.unmodifiable(entries);
  }
}

/// Mirrors upstream's longest-prefix manufacturer/alias matching. Unknown
/// manufacturers fail explicitly instead of splitting a multi-word brand badly.
class AutoEqManufacturers {
  AutoEqManufacturers(String tsv) {
    for (final line in const LineSplitter().convert(tsv)) {
      if (line.trim().isEmpty) continue;
      final names = line.trim().split('\t');
      for (final name in names) {
        _aliases[name.toLowerCase()] = names.first;
      }
    }
  }
  final _aliases = <String, String>{};

  /// Resolve a manufacturer alias to the canonical first-column spelling.
  String? canonicalBrand(String name) => _aliases[name.trim().toLowerCase()];

  (String, String) split(String name) {
    for (
      var end = name.lastIndexOf(' ');
      end > 0;
      end = name.lastIndexOf(' ', end - 1)
    ) {
      final brand = _aliases[name.substring(0, end).toLowerCase()];
      if (brand != null) return (brand, name.substring(end + 1));
    }
    throw FormatException('Unknown manufacturer: $name');
  }
}

double _number(Object? raw, String field, double min, double max) {
  if (raw is! num || !raw.toDouble().isFinite || raw < min || raw > max) {
    throw FormatException(
      'AutoEq $field outside supported range ($min..$max): $raw',
    );
  }
  return raw.toDouble();
}
