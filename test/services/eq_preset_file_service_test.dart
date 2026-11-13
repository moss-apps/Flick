import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/eq_preset_file_service.dart';
import 'package:flick/services/eq_preset_service.dart';

void main() {
  const service = EqPresetFileService();

  test('parses TXT equalizer presets', () {
    const text = '''
Preamp: -6.0 dB
Filter 1: ON PK Fc 24 Hz Gain -0.8 dB Q 1.100
Filter 2: ON PK Fc 190 Hz Gain -2.8 dB Q 0.500
Filter 3: ON PK Fc 1500 Hz Gain -1.7 dB Q 1.600
Filter 4: ON PK Fc 2700 Hz Gain 1.8 dB Q 2.000
Filter 5: ON PK Fc 3800 Hz Gain 5.6 dB Q 0.900
Filter 6: ON PK Fc 5000 Hz Gain -1.4 dB Q 0.500
Filter 7: ON PK Fc 13000 Hz Gain -3.0 dB Q 2.000
Filter 8: ON PK Fc 15000 Hz Gain 2.9 dB Q 0.500
Filter 9: ON PK Fc 15000 Hz Gain 4.4 dB Q 2.000
''';

    final preset = service.fromFileText(text: text, fileName: 'My Import.txt');

    expect(preset.name, 'My Import');
    expect(preset.mode, EqMode.parametric);
    expect(preset.preampDb, -6.0);
    expect(preset.parametricBands, hasLength(9));
    expect(preset.parametricBands.first.frequencyHz, 24.0);
    expect(preset.parametricBands.first.gainDb, -0.8);
    expect(preset.parametricBands.first.q, 1.1);
  });

  test('exports TXT equalizer presets', () {
    final preset = EqPreset(
      id: 'test',
      name: 'Example',
      enabled: true,
      mode: EqMode.parametric,
      preampDb: -6.0,
      graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
      parametricBands: const [
        ParametricBand(frequencyHz: 24, gainDb: -0.8, q: 1.1),
        ParametricBand(frequencyHz: 190, gainDb: -2.8, q: 0.5),
      ],
    );

    final text = service.toTxtText(preset);

    expect(text, contains('Preamp: -6.0 dB'));
    expect(text, contains('Filter 1: ON PK Fc 24 Hz Gain -0.8 dB Q 1.100'));
    expect(text, contains('Filter 2: ON PK Fc 190 Hz Gain -2.8 dB Q 0.500'));
  });

  test('preserves Q above the old 10 limit and reports no warnings', () {
    const text = '''
Preamp: -4.0 dB
Filter 1: ON PK Fc 1000 Hz Gain 2.0 dB Q 15.000
''';

    final result = service.parseFileText(text: text, fileName: 'tight.txt');

    expect(result.warnings, isEmpty);
    expect(result.preset.parametricBands.single.q, 15.0);
  });

  test('clamps out-of-range values and reports warnings', () {
    const text = '''
Preamp: -4.0 dB
Filter 1: ON PK Fc 500000 Hz Gain 24.0 dB Q 30.000
Filter 2: ON PK Fc 1000 Hz Gain -2.0 dB Q 1.000
''';

    final result = service.parseFileText(text: text, fileName: 'extreme.txt');

    expect(result.hasWarnings, isTrue);
    expect(result.warnings, hasLength(3));
    expect(result.preset.parametricBands.first.frequencyHz, 20000.0);
    expect(result.preset.parametricBands.first.gainDb, 20.0);
    expect(result.preset.parametricBands.first.q, 20.0);
    expect(result.preset.parametricBands[1].gainDb, -2.0);
    expect(result.preset.parametricBands[1].q, 1.0);
  });

  test('JSON imports produce no warnings', () {
    final preset = EqPreset(
      id: 'test',
      name: 'JsonPreset',
      enabled: true,
      mode: EqMode.parametric,
      preampDb: -3.0,
      graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
      parametricBands: const [
        ParametricBand(frequencyHz: 1000, gainDb: 5.0, q: 8.0),
      ],
    );

    final result = service.parseFileText(
      text: jsonEncode(preset.toJson()),
      fileName: 'preset.json',
    );

    expect(result.warnings, isEmpty);
    expect(result.preset.parametricBands.single.q, 8.0);
  });

  test('TXT and JSON preserve broad AutoEq filters without warnings', () {
    const text = '''
Preamp: -7.123 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.700
Filter 2: ON PK Fc 205.25 Hz Gain -12.2 dB Q 0.180
Filter 3: ON HSC Fc 10000 Hz Gain -2.1 dB Q 0.190
''';
    final imported = service.parseFileText(text: text, fileName: 'broad.txt');
    expect(imported.warnings, isEmpty);
    expect(imported.preset.preampDb, -7.123);
    expect(imported.preset.parametricBands[1].q, 0.18);
    expect(imported.preset.parametricBands.last.q, 0.19);
    final restored = service.parseFileText(
      text: service.toJsonText(imported.preset),
      fileName: 'broad.json',
    );
    expect(restored.warnings, isEmpty);
    expect(restored.preset.toJson(), imported.preset.toJson());
  });

  test(
    'JSON import reports all supported-range adjustments including preamp',
    () {
      final result = service.parseFileText(
        text: jsonEncode({
          'mode': 'parametric',
          'preampDb': -30,
          'parametricBands': [
            {'type': 'peaking', 'frequencyHz': 500000, 'gainDb': 24, 'q': 30},
          ],
        }),
        fileName: 'extreme.json',
      );
      expect(result.warnings, hasLength(4));
      expect(result.preset.preampDb, -24);
      expect(result.preset.parametricBands.single.frequencyHz, 20000);
      expect(result.preset.parametricBands.single.gainDb, 20);
      expect(result.preset.parametricBands.single.q, 20);
    },
  );

  test('TXT preamp adjustment is reported', () {
    final result = service.parseFileText(
      text: 'Preamp: -30 dB\nFilter 1: ON PK Fc 1000 Hz Gain 1 dB Q 1',
      fileName: 'preamp.txt',
    );
    expect(result.warnings, hasLength(1));
    expect(result.preset.preampDb, -24);
  });

  test(
    'rejects unknown types, missing gain, duplicates and oversized presets',
    () {
      for (final text in [
        'Filter 1: ON PK Fc 1000 Hz Q 1',
        'Filter 1: ON UNKNOWN Fc 1000 Hz Gain 1 dB Q 1',
        'Filter 1: ON PK Fc 1000 Hz Gain 1 dB Q 1\nFilter 1: ON PK Fc 2000 Hz Gain 1 dB Q 1',
        List.generate(
          32,
          (i) => 'Filter ${i + 1}: ON PK Fc 1000 Hz Gain 1 dB Q 1',
        ).join('\n'),
        jsonEncode({
          'mode': 'parametric',
          'parametricBands': [
            {'type': 'mystery'},
          ],
        }),
        jsonEncode({
          'mode': 'parametric',
          'parametricBands': List.generate(32, (_) => {'type': 'peaking'}),
        }),
        jsonEncode({'mode': 'parametric', 'parametricBands': []}),
        '{"mode":"parametric","parametricBands":[{"type":"peaking","q":1e999}]}',
      ]) {
        expect(
          () => service.parseFileText(text: text, fileName: 'bad'),
          throwsFormatException,
          reason: text,
        );
      }
    },
  );
}
