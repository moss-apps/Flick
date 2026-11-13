import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_autoeq_catalog.dart' as generator;

const _revision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _profile = '''
Preamp: -7.123 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.7
Filter 2: ON PK Fc 205.25 Hz Gain -12.2 dB Q 0.18
Filter 3: ON HSC Fc 10000 Hz Gain -2.1 dB Q 0.7
''';
const _firstPath =
    'results/Source/GRAS over-ear/Brand Alpha (ANC On)/Brand Alpha (ANC On) ParametricEQ.txt';
const _secondPath =
    'results/Other/in-ear/Bang & Olufsen Beta/Bang & Olufsen Beta ParametricEQ.txt';

void main() {
  late Directory temporary;
  late String cache;
  late String output;
  late String lock;
  late List<String> options;

  setUp(() async {
    temporary = await Directory(
      '/tmp/opencode',
    ).createTemp('flick-autoeq-test-');
    cache = '${temporary.path}/cache';
    output = '${temporary.path}/output';
    lock = '${temporary.path}/lock.json';
    options = ['--output=$output', '--cache=$cache', '--lock=$lock'];
    const index = '''
- [Brand Alpha (ANC On)](./Source/GRAS%20over-ear/Brand%20Alpha%20(ANC%20On))
- [Bang & Olufsen Beta](./Other/in-ear/Bang%20%26%20Olufsen%20Beta)
''';
    final inputs = {
      'results/README.md': index,
      'dbtools/manufacturers.tsv': 'Brand\nBang & Olufsen\n',
      'LICENSE': 'Test fixture license\n',
    };
    await File(lock).writeAsString(
      jsonEncode({
        'repository': 'jaakkopasanen/AutoEq',
        'revision': _revision,
        'inputs': {
          for (final entry in inputs.entries)
            entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
        },
      }),
    );
    for (final entry in {
      ...inputs,
      _firstPath: _profile,
      _secondPath: _profile,
    }.entries) {
      final file = File('$cache/$_revision/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  });

  tearDown(() async {
    exitCode = 0;
    await temporary.delete(recursive: true);
  });

  test(
    'pinned offline generation is deterministic with exact values and notices',
    () async {
      expect(await _run(options), 0);
      final catalog = File('$output/autoeq_catalog.json');
      final bytes = await catalog.readAsBytes();
      final entries = (jsonDecode(utf8.decode(bytes)) as List)
          .cast<Map<String, dynamic>>();
      expect(entries, hasLength(2));
      final first = entries.singleWhere((entry) => entry['p'] == _firstPath);
      expect(first['id'], sha256.convert(utf8.encode(_firstPath)).toString());
      expect(first['n'], 'Brand Alpha (ANC On)');
      expect(first['r'], 'GRAS');
      expect(first['c'], _revision);
      expect(first['tg'], isNull);
      expect(first['pa'], -7.123);
      expect(first['g'][1], [205.25, -12.2, 0.18, 'PK']);
      expect(first['h'], sha256.convert(utf8.encode(_profile)).toString());
      final manifest = jsonDecode(
        await File('$output/autoeq_manifest.json').readAsString(),
      );
      expect(
        manifest['files']['autoeq_catalog.json']['sha256'],
        sha256.convert(bytes).toString(),
      );
      expect(manifest['files']['autoeq_catalog.json']['bytes'], bytes.length);
      expect(
        await File('$output/AUTOEQ-LICENSE.txt').readAsString(),
        'Test fixture license\n',
      );
      expect(
        await File('$output/NOTICE.txt').readAsString(),
        contains(_revision),
      );
      expect(await _run([...options, '--check']), 0);
      expect(await catalog.readAsBytes(), bytes);
      expect(await _run(options), 0);
      expect(await catalog.readAsBytes(), bytes);
    },
  );

  test('check detects modified outputs without rewriting them', () async {
    expect(await _run(options), 0);
    final catalog = File('$output/autoeq_catalog.json');
    await catalog.writeAsString('modified');
    expect(await _run([...options, '--check']), 1);
    expect(await catalog.readAsString(), 'modified');
  });

  test(
    'locked input checksum failures do not overwrite a valid catalog',
    () async {
      expect(await _run(options), 0);
      final catalog = File('$output/autoeq_catalog.json');
      final bytes = await catalog.readAsBytes();
      await File('$cache/$_revision/LICENSE').writeAsString('corrupted');
      expect(await _run(options), 1);
      expect(await catalog.readAsBytes(), bytes);
    },
  );

  test(
    'unsupported profiles are reported, excluded only by explicit option',
    () async {
      await File(
        '$cache/$_revision/$_firstPath',
      ).writeAsString(_profile.replaceFirst('0.18', '0.05'));
      expect(await _run(options), 1);
      expect(await File('$output/autoeq_catalog.json').exists(), isFalse);
      final report = jsonDecode(
        await File('$output/autoeq_report.json').readAsString(),
      );
      expect(report['excluded'], hasLength(1));
      expect(report['excluded'][0]['path'], _firstPath);
      expect(report['excluded'][0]['reason'], contains('Q'));
      expect(await _run([...options, '--allow-exclusions']), 0);
      expect(
        jsonDecode(await File('$output/autoeq_catalog.json').readAsString()),
        hasLength(1),
      );
    },
  );

  test(
    'an entirely unsupported selection still writes its review report',
    () async {
      for (final path in [_firstPath, _secondPath]) {
        await File(
          '$cache/$_revision/$path',
        ).writeAsString('Unsupported preset');
      }
      expect(await _run([...options, '--allow-exclusions']), 1);
      expect(await File('$output/autoeq_catalog.json').exists(), isFalse);
      final report = jsonDecode(
        await File('$output/autoeq_report.json').readAsString(),
      );
      expect(report['imported'], 0);
      expect(report['excluded'], hasLength(2));
    },
  );

  test(
    'stale upstream links are reported but other HTTP failures abort',
    () async {
      await File('$cache/$_revision/$_firstPath').delete();
      Future<int> runWithStatus(int status, {bool allow = false}) =>
          HttpOverrides.runZoned(
            () => _run([...options, if (allow) '--allow-exclusions']),
            createHttpClient: (_) => _StatusClient(status),
          );
      expect(await runWithStatus(404), 1);
      final report = jsonDecode(
        await File('$output/autoeq_report.json').readAsString(),
      );
      expect(report['excluded'].single['path'], _firstPath);
      expect(report['excluded'].single['reason'], contains('HTTP 404'));
      expect(await File('$output/autoeq_catalog.json').exists(), isFalse);
      expect(await runWithStatus(404, allow: true), 0);
      final bytes = await File('$output/autoeq_catalog.json').readAsBytes();
      expect(await runWithStatus(403, allow: true), 1);
      expect(await File('$output/autoeq_catalog.json').readAsBytes(), bytes);
    },
  );

  test('partial reports and baseline changes are explicit', () async {
    final baseline = File('${temporary.path}/baseline.json');
    await baseline.writeAsString(
      jsonEncode([
        {
          'b': 'Brand',
          'm': 'Alpha (ANC On)',
          'pa': -3,
          'g': [
            [1000, 1, 1, 'PK'],
          ],
        },
        {
          'b': 'Old',
          'm': 'Model',
          'pa': -2,
          'g': [
            [1000, 1, 1, 'PK'],
          ],
        },
      ]),
    );
    expect(
      await _run([...options, '--limit=1', '--baseline=${baseline.path}']),
      0,
    );
    final report = jsonDecode(
      await File('$output/autoeq_report.json').readAsString(),
    );
    expect(report['partial'], isTrue);
    expect(report['selected'], 1);
    expect(report['changes']['changed'], ['Brand Alpha (ANC On)']);
    expect(report['changes']['removed'], ['Old Model']);
    expect(report['changes']['added'], isEmpty);
  });

  test(
    'generator refuses to write directly into the shipped asset directory',
    () async {
      expect(await _run(['--output=assets/autoeq']), 1);
    },
  );
}

Future<int> _run(List<String> args) async {
  exitCode = 0;
  await generator.main(args);
  final result = exitCode;
  exitCode = 0;
  return result;
}

// Exercise HTTP failure handling without making external requests.
class _StatusClient implements HttpClient {
  _StatusClient(this.status);
  final int status;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StatusRequest(status);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatusRequest implements HttpClientRequest {
  _StatusRequest(this.status);
  final int status;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _StatusResponse(status);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatusResponse extends Stream<List<int>> implements HttpClientResponse {
  _StatusResponse(this.statusCode);
  @override
  final int statusCode;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
