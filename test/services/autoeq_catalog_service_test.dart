import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/autoeq_catalog_service.dart';
import 'package:flick/services/eq_preset_service.dart';

const _revision = '7ae0f56d53074872b028649617a22bbb4232feb7';
const _profile = '''
Preamp: -7.123 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.700
Filter 2: ON PK Fc 205.25 Hz Gain -12.2 dB Q 0.180
Filter 3: ON HSC Fc 10000 Hz Gain -2.1 dB Q 0.700
''';
const _index = '''
- [Sennheiser HD 650](./oratory1990/GRAS%2045CA%20over-ear/Sennheiser%20HD%20650)
- [Sennheiser HD 650 (new earpads)](./oratory1990/over-ear/Sennheiser%20HD%20650%20(new%20earpads))
- [Bang & Olufsen Beoplay H95 (ANC On)](./Rtings/over-ear/Bang%20%26%20Olufsen%20Beoplay%20H95%20(ANC%20On))
- [7Hertz Timeless](./Source/in-ear/7Hertz%20Timeless)
- [Simgot Audio EA500LM](./Jaytiss/in-ear/Simgot%20Audio%20EA500LM)
''';

Map<String, dynamic> _entry(String id, String brand, String model) => {
  'id': id,
  'b': brand,
  'm': model,
  't': 'over-ear',
  's': 'test',
  'pa': -7.123,
  'g': [
    [205.25, -12.2, 0.18, 'PK'],
  ],
};

class _Bundle extends CachingAssetBundle {
  _Bundle(this.entries);
  final List<Map<String, dynamic>> entries;
  @override
  Future<ByteData> load(String key) async {
    final data = key.endsWith('autoeq_brands.json')
        ? entries.map((e) => e['b']).toSet().toList()
        : entries;
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('online index is pinned to the generator lock revision', () async {
    final lock =
        jsonDecode(await File('tool/autoeq_catalog.lock.json').readAsString())
            as Map<String, dynamic>;
    expect(AutoEqCatalogService.upstreamRevision, lock['revision']);
  });

  test(
    'bundled catalog loads offline and preserves every low-Q value',
    () async {
      final raw =
          (jsonDecode(
                    await File(
                      'assets/autoeq/autoeq_catalog.json',
                    ).readAsString(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw StateError('No network');
      });
      addTearDown(client.close);
      final service = AutoEqCatalogService(
        bundle: _Bundle(raw),
        client: client,
      );
      final entries = await service.loadBundled();
      final brands = await service.loadBrands();
      expect(entries, hasLength(466));
      expect(brands.toSet(), entries.map((e) => e.brand).toSet());
      final bundledBrands =
          jsonDecode(
                await File('assets/autoeq/autoeq_brands.json').readAsString(),
              )
              as List;
      expect(bundledBrands.toSet(), brands.toSet());
      var lowQCount = 0;
      for (var i = 0; i < entries.length; i++) {
        expect(entries[i].preampDb, raw[i]['pa']);
        final filters = raw[i]['g'] as List;
        for (var j = 0; j < filters.length; j++) {
          expect(entries[i].bands[j].q, filters[j][2]);
          if (entries[i].bands[j].q < 0.2) lowQCount++;
        }
      }
      expect(lowQCount, 21);
      expect(requests, 0);
      expect(identical(await service.loadBundled(), entries), isTrue);
      expect(() => entries.clear(), throwsUnsupportedError);
    },
  );

  test(
    'search supports multi-word order, all tokens, punctuation and brand filters',
    () async {
      final service = AutoEqCatalogService(
        bundle: _Bundle([
          _entry('sony', 'Sony', 'WH-1000XM5'),
          _entry('hd650', 'Sennheiser', 'HD 650'),
          _entry('pads', 'Sennheiser', 'HD 650 (new earpads)'),
          _entry('cra', 'CCA', 'CRA'),
          _entry('plus', 'CCA', 'CRA+'),
          _entry('unicode', '音特美', 'ER4'),
          {..._entry('alias', '7Hz', 'Timeless'), 'n': '7Hertz Timeless'},
        ]),
      );
      await service.loadBundled();
      expect(service.search('HD 650').first.entry.id, 'hd650');
      expect(service.search('650 senn').first.entry.id, 'hd650');
      expect(service.search('senn nonexistent'), isEmpty);
      expect(service.search('sony 1000 xm5').single.entry.id, 'sony');
      expect(
        service.search('wh1000xm5', brand: 'sony').single.entry.id,
        'sony',
      );
      expect(service.search('hd650', brand: 'Sony'), isEmpty);
      expect(service.search('CRA+').single.entry.id, 'plus');
      expect(service.search('音特美 ER4').single.entry.id, 'unicode');
      expect(service.search('7Hertz Timeless').single.entry.id, 'alias');
      expect(service.search('???', limit: 2), hasLength(2));
      expect(service.search('', limit: 0), isEmpty);
      expect(service.search('', limit: -1), isEmpty);
    },
  );

  test('rejects duplicate IDs and unsupported catalog filters', () async {
    final entry = _entry('same', 'Brand', 'Model');
    await expectLater(
      AutoEqCatalogService(bundle: _Bundle([entry, entry])).loadBundled(),
      throwsFormatException,
    );
    expect(
      () => AutoEqEntry.fromJson({
        ...entry,
        'g': [
          [1000, 2, 1, 'AP'],
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'online lookup uses real filenames, one commit, exact variants and provenance',
    () async {
      final requests = <Uri>[];
      final client = _onlineClient(requests);
      addTearDown(client.close);
      final service = AutoEqCatalogService(client: client);
      final entry = await service.fetchOnline('Sennheiser', 'HD 650');
      expect(entry, isNotNull);
      expect(entry!.preampDb, -7.123);
      expect(entry.bands[1].q, 0.18);
      expect(entry.bands.first.type, ParametricBandType.lowShelf);
      expect(entry.bands.last.type, ParametricBandType.highShelf);
      expect(entry.source, 'oratory1990');
      expect(entry.type, 'over-ear');
      expect(entry.rig, 'GRAS 45CA');
      expect(entry.target, isNull);
      expect(entry.upstreamRevision, _revision);
      expect(entry.upstreamSha256, hasLength(64));
      expect(
        entry.upstreamPath,
        endsWith('/Sennheiser HD 650 ParametricEQ.txt'),
      );
      expect(
        requests.last.pathSegments.last,
        'Sennheiser HD 650 ParametricEQ.txt',
      );
      expect(requests.where((uri) => uri.host == 'api.github.com'), isEmpty);
      expect(
        requests
            .where((uri) => uri.host == 'raw.githubusercontent.com')
            .every((uri) => uri.path.contains('/$_revision/')),
        isTrue,
      );
      expect(requests.any((uri) => uri.path.contains('/git/trees/')), isFalse);

      final pads = await service.fetchOnline(
        'Sennheiser',
        'HD 650 (new earpads)',
      );
      expect(pads!.id, isNot(entry.id));
      expect(pads.displayName, contains('(new earpads)'));
      final requestCount = requests.length;
      expect(await service.fetchOnline('Sennheiser', 'HD 65'), isNull);
      expect(requests, hasLength(requestCount));
      final multiWord = await service.fetchOnline(
        '',
        'Bang & Olufsen Beoplay H95 (ANC On)',
      );
      expect(multiWord!.brand, 'Bang & Olufsen');
      expect(multiWord.model, 'Beoplay H95 (ANC On)');
      final alias = await service.fetchOnline('7Hz', 'Timeless');
      expect(alias!.displayName, '7Hertz Timeless');
      expect(alias.brand, '7Hz');

      final canonicalBrand = await service.fetchOnline('Simgot', 'EA500LM');
      expect(canonicalBrand!.displayName, 'Simgot Audio EA500LM');
      expect(canonicalBrand.brand, 'Simgot Audio');
      expect(canonicalBrand.model, 'EA500LM');
      final byFullName = await service.fetchOnline('', 'Simgot EA500LM');
      expect(byFullName!.id, canonicalBrand.id);
      expect(await service.fetchOnline('Sony', 'EA500LM'), isNull);
    },
  );

  test(
    'online failure, rate limit and unsupported data return no substituted preset',
    () async {
      for (final response in [
        http.Response('limited', 429),
        http.Response('missing', 404),
      ]) {
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        expect(
          await AutoEqCatalogService(
            client: client,
          ).fetchOnline('Sennheiser', 'HD 650'),
          isNull,
        );
      }
      for (final invalid in [
        _profile.replaceFirst('0.180', '0.050'),
        _profile.replaceFirst('PK', 'AP'),
        _profile.replaceFirst('Preamp: -7.123 dB\n', ''),
      ]) {
        final client = _onlineClient([], profile: invalid);
        addTearDown(client.close);
        expect(
          await AutoEqCatalogService(
            client: client,
          ).fetchOnline('Sennheiser', 'HD 650'),
          isNull,
        );
      }
    },
  );

  test(
    'saved correction is a settings snapshot independent of later catalog data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = AutoEqEntry.fromJson(_entry('stable', 'Brand', 'Model'));
      final saved = original.toEqPreset();
      final storage = EqPresetService();
      await storage.upsertCustomPreset(saved);
      final updated = AutoEqEntry.fromJson({
        ..._entry('stable', 'Brand', 'Model'),
        'pa': -2,
        'g': [
          [1000, 4, 1, 'PK'],
        ],
      });
      expect(updated.id, original.id);
      final restored = (await EqPresetService().loadCustomPresets()).single;
      expect(restored.toJson(), saved.toJson());
      expect(restored.preampDb, -7.123);
      expect(restored.parametricBands.single.q, 0.18);
    },
  );
}

MockClient _onlineClient(List<Uri> requests, {String profile = _profile}) =>
    MockClient((request) async {
      requests.add(request.url);
      final path = request.url.path;
      if (path.endsWith('/results/README.md')) {
        return http.Response(_index, 200);
      }
      if (path.endsWith('/dbtools/manufacturers.tsv')) {
        return http.Response(
          'Sennheiser\nBang & Olufsen\n7Hz\t7Hertz\nSimgot Audio\tSimgot\n',
          200,
        );
      }
      if (request.url.pathSegments.last.endsWith(' ParametricEQ.txt')) {
        return http.Response(profile, 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
