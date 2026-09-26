import 'package:flutter_test/flutter_test.dart';

import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/eq_response_service.dart';

void main() {
  const fs = 48000.0;

  ParametricBand band({
    double frequencyHz = 1000,
    double gainDb = 0,
    double q = 1,
    ParametricBandType type = ParametricBandType.peaking,
    bool enabled = true,
  }) {
    return ParametricBand(
      enabled: enabled,
      frequencyHz: frequencyHz,
      gainDb: gainDb,
      q: q,
      type: type,
    );
  }

  test('peaking band reaches its gain at the center frequency', () {
    final b = band(gainDb: 6, q: 1);
    expect(
      EqResponseService.bandResponseDb(band: b, hz: 1000, sampleRateHz: fs),
      closeTo(6.0, 0.05),
    );
    expect(
      EqResponseService.bandResponseDb(band: b, hz: 100, sampleRateHz: fs),
      closeTo(0.0, 0.5),
    );
  });

  test('disabled and all-pass bands contribute nothing', () {
    expect(
      EqResponseService.bandResponseDb(
        band: band(gainDb: 6, enabled: false),
        hz: 1000,
        sampleRateHz: fs,
      ),
      0.0,
    );
    expect(
      EqResponseService.bandResponseDb(
        band: band(gainDb: 6, type: ParametricBandType.allPass),
        hz: 1000,
        sampleRateHz: fs,
      ),
      0.0,
    );
  });

  test('low and high shelves approach their gain on the shelf side', () {
    expect(
      EqResponseService.bandResponseDb(
        band: band(gainDb: 6, type: ParametricBandType.lowShelf),
        hz: 30,
        sampleRateHz: fs,
      ),
      closeTo(6.0, 0.3),
    );
    expect(
      EqResponseService.bandResponseDb(
        band: band(gainDb: -6, type: ParametricBandType.highShelf),
        hz: 20000,
        sampleRateHz: fs,
      ),
      closeTo(-6.0, 0.3),
    );
  });

  test('higher Q narrows a peaking band', () {
    final wide = EqResponseService.bandResponseDb(
      band: band(gainDb: 6, q: 1),
      hz: 2000,
      sampleRateHz: fs,
    );
    final narrow = EqResponseService.bandResponseDb(
      band: band(gainDb: 6, q: 10),
      hz: 2000,
      sampleRateHz: fs,
    );
    expect(narrow, lessThan(wide));
    expect(narrow, closeTo(0.0, 0.2));
  });

  test('pass filters attenuate outside their pass band', () {
    final lp = band(type: ParametricBandType.lowPass, q: 0.707);
    expect(
      EqResponseService.bandResponseDb(band: lp, hz: 100, sampleRateHz: fs),
      closeTo(0.0, 0.3),
    );
    expect(
      EqResponseService.bandResponseDb(band: lp, hz: 10000, sampleRateHz: fs),
      lessThan(-30.0),
    );
  });

  test('summed response clamps to the provided bounds', () {
    final bands = [band(gainDb: 10), band(gainDb: 10)];
    expect(
      EqResponseService.responseDbAtHz(hz: 1000, bands: bands, sampleRateHz: fs),
      closeTo(12.0, 0.01),
    );
    expect(
      EqResponseService.responseDbAtHz(
        hz: 1000,
        bands: bands,
        sampleRateHz: fs,
        minDb: -20,
        maxDb: 20,
      ),
      closeTo(20.0, 0.01),
    );
  });

  test('response is close between 44.1 kHz and 48 kHz at mid frequencies', () {
    final b = band(gainDb: 6);
    final at44 = EqResponseService.bandResponseDb(
      band: b,
      hz: 1000,
      sampleRateHz: 44100,
    );
    final at48 = EqResponseService.bandResponseDb(
      band: b,
      hz: 1000,
      sampleRateHz: 48000,
    );
    expect(at44, closeTo(at48, 0.05));
  });
}
