import 'package:flutter_test/flutter_test.dart';

import 'package:flick/models/eq_limits.dart';
import 'package:flick/services/autoeq_format.dart';

void main() {
  const text = '''
Preamp: -7.123 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.700
Filter 2: ON PK Fc 205.25 Hz Gain -12.2 dB Q 0.180
Filter 3: ON HSC Fc 10000 Hz Gain -2.1 dB Q 0.700
Filter 4: OFF PK Fc 1000 Hz Gain 4.0 dB Q 0.190
''';

  test(
    'strict AutoEq parser preserves precision, preamp, shelves and low Q',
    () {
      final profile = AutoEqProfile.parse(text.replaceAll('\n', '\r\n'));
      expect(profile.preampDb, -7.123);
      expect(profile.filters.map((filter) => filter.type), ['LS', 'PK', 'HS']);
      expect(profile.filters[1].frequencyHz, 205.25);
      expect(profile.filters[1].gainDb, -12.2);
      expect(profile.filters[1].q, 0.18);
      expect(
        AutoEqProfile.fromJson(profile.toJson()).toJson(),
        profile.toJson(),
      );
    },
  );

  test(
    'catalog does not clamp, default missing gain/preamp or substitute types',
    () {
      for (final invalid in [
        '',
        text.replaceFirst('Preamp: -7.123 dB\n', ''),
        text.replaceFirst('-7.123', '-30'),
        text.replaceFirst('205.25', '10'),
        text.replaceFirst('-12.2', '-24'),
        text.replaceFirst('0.180', '0.050'),
        text.replaceFirst('PK', 'AP'),
        text.replaceFirst('PK', 'UNKNOWN'),
        text.replaceFirst(' Gain -12.2 dB', ''),
        text.replaceFirst('Filter 2:', 'Filter 1:'),
        '$text\nUnrecognized trailing data',
      ]) {
        expect(
          () => AutoEqProfile.parse(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test('rejects malformed, non-finite and oversized compact profiles', () {
    for (final filter in [
      [1000, double.nan, 1, 'PK'],
      [1000, 1, double.infinity, 'PK'],
      [1000, 1, 1, 'AP'],
      [1000, 1, 1],
      ['1000', 1, 1, 'PK'],
    ]) {
      expect(
        () => AutoEqProfile.fromJson({
          'pa': -3,
          'g': [filter],
        }),
        throwsFormatException,
      );
    }
    expect(
      () => AutoEqProfile.fromJson({'pa': -3, 'g': []}),
      throwsFormatException,
    );
    expect(
      () => AutoEqProfile.fromJson({
        'pa': -3,
        'g': List.filled(EqLimits.maxBands + 1, [1000, 1, 1, 'PK']),
      }),
      throwsFormatException,
    );
  });

  test(
    'recommended index retains spaces, parentheses, source, category and rig',
    () {
      const index = '''
# Results
- [1MORE Aero (ANC Off)](./HypetheSonics/GRAS%20RA0045%20in-ear/1MORE%20Aero%20(ANC%20Off))
- [Sennheiser HD 650](./oratory1990/over-ear/Sennheiser%20HD%20650)
''';
      final entries = AutoEqRecommendation.parseIndex(index);
      expect(entries, hasLength(2));
      expect(entries.first.name, '1MORE Aero (ANC Off)');
      expect(
        entries.first.path,
        'results/HypetheSonics/GRAS RA0045 in-ear/1MORE Aero (ANC Off)/1MORE Aero (ANC Off) ParametricEQ.txt',
      );
      expect(entries.first.source, 'HypetheSonics');
      expect(entries.first.type, 'in-ear');
      expect(entries.first.rig, 'GRAS RA0045');
      expect(entries.last.rig, isNull);
      final uri = Uri.https(
        'raw.githubusercontent.com',
        '/repo/commit/${entries.first.path}',
      );
      expect(uri.toString(), contains('Aero%20(ANC%20Off)%20ParametricEQ.txt'));
      expect(uri.toString(), isNot(contains('%2520')));
    },
  );

  test('index fails explicitly on malformed, duplicate and unsafe paths', () {
    const valid = '- [Brand Model](./Source/over-ear/Brand%20Model)';
    for (final invalid in [
      '# No results',
      '$valid\n$valid',
      '- [Brand Model](./Source/unknown/Brand%20Model)',
      '- [Brand Model](./Source/over-ear/Different%20Model)',
      '- [..](./Source/over-ear/..)',
      '- [Brand Model](https://example.com/Brand%20Model)',
    ]) {
      expect(
        () => AutoEqRecommendation.parseIndex(invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'manufacturer parsing honors aliases and the longest multi-word prefix',
    () {
      final manufacturers = AutoEqManufacturers(
        'Audio\nAudio Technica\tAudio-Technica\n7Hz\t7Hertz\nBang & Olufsen\nSimgot Audio\tSimgot\n',
      );
      expect(manufacturers.canonicalBrand('Audio-Technica'), 'Audio Technica');
      expect(manufacturers.canonicalBrand('Simgot'), 'Simgot Audio');
      expect(manufacturers.canonicalBrand('Unlisted'), isNull);
      expect(manufacturers.split('Audio Technica ATH-M50x'), (
        'Audio Technica',
        'ATH-M50x',
      ));
      expect(manufacturers.split('Audio-Technica ATH-M50x'), (
        'Audio Technica',
        'ATH-M50x',
      ));
      expect(manufacturers.split('7Hertz Timeless'), ('7Hz', 'Timeless'));
      expect(manufacturers.split('Bang & Olufsen Beoplay H95 (ANC On)'), (
        'Bang & Olufsen',
        'Beoplay H95 (ANC On)',
      ));
      expect(
        () => manufacturers.split('Unlisted Model'),
        throwsFormatException,
      );
    },
  );
}
