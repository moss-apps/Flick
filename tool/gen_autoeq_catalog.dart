// Dev-only, pinned AutoEq catalog generator. See docs/AUTOEQ.md.
// Uses Dart's HTTP client and the project's existing crypto dependency.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flick/services/autoeq_format.dart';

const _repository = 'jaakkopasanen/AutoEq';
const _encoder = JsonEncoder.withIndent('  ');

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
      'dart run tool/gen_autoeq_catalog.dart --output=<staging-dir> '
      '[--cache=<dir>] [--lock=<file>] [--limit=<count>] '
      '[--baseline=<catalog.json>] [--allow-exclusions] [--check]',
    );
    return;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final options = _Options(args);
    await _generateCatalog(options, client);
  } catch (error) {
    stderr.writeln('AutoEq generation failed: $error');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

class _Options {
  _Options(List<String> args) {
    for (final arg in args) {
      if (arg == '--check') {
        check = true;
      } else if (arg == '--allow-exclusions') {
        allowExclusions = true;
      } else {
        final split = arg.indexOf('=');
        if (split < 0) throw ArgumentError('Expected --option=value: $arg');
        final key = arg.substring(0, split);
        final value = arg.substring(split + 1);
        if (value.isEmpty) throw ArgumentError('Empty option: $key');
        switch (key) {
          case '--output':
            output = value;
          case '--cache':
            cache = value;
          case '--lock':
            lock = value;
          case '--limit':
            limit = int.parse(value);
          case '--baseline':
            baseline = value;
          default:
            throw ArgumentError('Unknown option: $key');
        }
      }
    }
    if (output == null) {
      throw ArgumentError('--output=<staging-dir> is required');
    }
    if (limit != null && limit! <= 0) {
      throw ArgumentError('--limit must be positive');
    }
    // Keep imports staged until their report and source permissions are reviewed.
    final destination = Directory(output!).absolute.uri.normalizePath();
    final bundled = Directory('assets/autoeq').absolute.uri.normalizePath();
    if (destination == bundled) {
      throw ArgumentError(
        'Generate into a staging directory, not assets/autoeq',
      );
    }
  }

  String? output;
  String cache = '.dart_tool/autoeq_cache';
  String lock = 'tool/autoeq_catalog.lock.json';
  int? limit;
  String? baseline;
  bool check = false;
  bool allowExclusions = false;
}

Future<void> _generateCatalog(_Options options, HttpClient client) async {
  final lock =
      jsonDecode(await File(options.lock).readAsString())
          as Map<String, dynamic>;
  final revision = lock['revision'] as String;
  if (lock['repository'] != _repository ||
      !RegExp(r'^[a-f0-9]{40}$').hasMatch(revision)) {
    throw const FormatException(
      'Lock must identify AutoEq and a full commit SHA',
    );
  }
  final expected = (lock['inputs'] as Map).cast<String, String>();
  const requiredInputs = [
    'results/README.md',
    'dbtools/manufacturers.tsv',
    'LICENSE',
  ];
  if (!requiredInputs.every(expected.containsKey)) {
    throw const FormatException('Lock is missing input checksums');
  }
  final reader = _PinnedReader(client, options.cache, revision);
  final inputBytes = <String, List<int>>{};
  for (final path in requiredInputs) {
    final bytes = await reader.read(path);
    if (_hash(bytes) != expected[path]) {
      throw StateError('Checksum mismatch: $path');
    }
    inputBytes[path] = bytes;
  }
  final recommended = AutoEqRecommendation.parseIndex(
    utf8.decode(inputBytes['results/README.md']!),
  );
  final manufacturers = AutoEqManufacturers(
    utf8.decode(inputBytes['dbtools/manufacturers.tsv']!),
  );
  final selected = recommended
      .take(options.limit ?? recommended.length)
      .toList();
  final entries = <Map<String, dynamic>>[];
  final excluded = <Map<String, String>>[];
  var next = 0;

  // Bounded parallel downloads. All output ordering is canonicalized afterwards.
  await Future.wait(
    List.generate(8, (_) async {
      while (next < selected.length) {
        final item = selected[next++];
        try {
          final bytes = await reader.read(item.path);
          final profile = AutoEqProfile.parse(utf8.decode(bytes));
          final (brand, model) = manufacturers.split(item.name);
          entries.add({
            'id': _hash(utf8.encode(item.path)),
            'b': brand, 'm': model, 'n': item.name,
            't': item.type, 's': item.source, 'r': item.rig,
            'p': item.path, 'c': revision, 'h': _hash(bytes),
            // These files do not identify exact target versions. Do not guess.
            'tg': null,
            ...profile.toJson(),
          });
        } on _HttpFailure catch (error) {
          // A stale recommended-index link is a reviewable upstream omission.
          // Other HTTP/transport failures must abort, not look like exclusions.
          if (error.status != 404) rethrow;
          excluded.add({
            'name': item.name,
            'path': item.path,
            'reason': 'Missing upstream parametric file (HTTP 404)',
          });
        } on FormatException catch (error) {
          excluded.add({
            'name': item.name,
            'path': item.path,
            'reason': error.message,
          });
        }
      }
    }),
  );
  entries.sort((a, b) => (a['n'] as String).compareTo(b['n'] as String));
  excluded.sort((a, b) => a['path']!.compareTo(b['path']!));
  if (entries.map((e) => e['id']).toSet().length != entries.length) {
    throw StateError('Duplicate IDs; no catalog written');
  }
  final brands = entries.map((e) => e['b'] as String).toSet().toList()..sort();
  final sources = <String, int>{};
  for (final entry in entries) {
    final source = entry['s'] as String;
    sources[source] = (sources[source] ?? 0) + 1;
  }
  final sourceNames = sources.keys.toList()..sort();
  final report = <String, dynamic>{
    'schemaVersion': 2,
    'repository': 'https://github.com/$_repository',
    'revision': revision,
    'recommended': recommended.length,
    'selected': selected.length,
    'partial': selected.length != recommended.length,
    'imported': entries.length,
    'brands': brands.length,
    'sources': {for (final source in sourceNames) source: sources[source]},
    'unknownTargets': entries.length,
    'excluded': excluded,
    'redistributionReview':
        'Required before promoting staged assets; upstream MIT '
        'license is not a blanket clearance of third-party measurements or targets.',
    if (options.baseline != null)
      'changes': await _changes(entries, options.baseline!),
  };
  final output = Directory(options.output!);
  if (entries.isEmpty || (excluded.isNotEmpty && !options.allowExclusions)) {
    if (!options.check) {
      await output.create(recursive: true);
      await File(
        '${output.path}/autoeq_report.json',
      ).writeAsString('${_encoder.convert(report)}\n');
    }
    if (entries.isEmpty) {
      throw StateError('No supported profiles; review autoeq_report.json');
    }
    throw StateError(
      '${excluded.length} unsupported profiles. Review autoeq_report.json; '
      'no catalog written. Use --allow-exclusions only after review.',
    );
  }

  final files = <String, List<int>>{
    'autoeq_catalog.json': utf8.encode(jsonEncode(entries)),
    'autoeq_brands.json': utf8.encode(jsonEncode(brands)),
    'autoeq_report.json': utf8.encode('${_encoder.convert(report)}\n'),
    'AUTOEQ-LICENSE.txt': inputBytes['LICENSE']!,
    'NOTICE.txt': utf8.encode(
      'AutoEq parametric presets\n'
      'Copyright (c) 2018-2022 Jaakko Pasanen\n'
      'https://github.com/$_repository/tree/$revision\n'
      'Upstream license: MIT (see AUTOEQ-LICENSE.txt).\n'
      'Measurement sources are identified on every preset.\n'
      'Only numeric parametric settings are included, not raw measurements, '
      'plots, target data or impulse responses.\n'
      'Exact target versions are unknown unless explicitly documented upstream.\n',
    ),
  };
  files['autoeq_manifest.json'] = utf8.encode(
    '${_encoder.convert({
      'schemaVersion': 2,
      'repository': 'https://github.com/$_repository',
      'revision': revision,
      'inputs': {for (final path in requiredInputs) path: expected[path]},
      'files': {
        for (final file in files.entries) file.key: {'bytes': file.value.length, 'sha256': _hash(file.value)},
      },
    })}\n',
  );
  // No catalog files are touched until fetching and validation have completed.
  if (!options.check) await output.create(recursive: true);
  for (final file in files.entries) {
    final destination = File('${output.path}/${file.key}');
    if (options.check) {
      if (!await destination.exists() ||
          _hash(await destination.readAsBytes()) != _hash(file.value)) {
        throw StateError('Generated output differs: ${destination.path}');
      }
    } else {
      final staging = File('${destination.path}.tmp');
      await staging.writeAsBytes(file.value, flush: true);
      await staging.rename(destination.path);
    }
  }
  stdout.writeln(
    '${options.check ? 'Verified' : 'Staged'} ${entries.length} profiles, '
    '${brands.length} brands; catalog ${files['autoeq_catalog.json']!.length} bytes.',
  );
}

Future<Map<String, dynamic>> _changes(
  List<Map<String, dynamic>> entries,
  String baseline,
) async {
  final bytes = await File(baseline).readAsBytes();
  final old = (jsonDecode(utf8.decode(bytes)) as List)
      .cast<Map<String, dynamic>>();
  String name(Map<String, dynamic> e) =>
      e['n'] as String? ?? '${e['b']} ${e['m']}';
  String settings(Map<String, dynamic> e) =>
      jsonEncode(AutoEqProfile.fromJson(e).toJson());
  final previous = {for (final entry in old) name(entry): settings(entry)};
  final current = {for (final entry in entries) name(entry): settings(entry)};
  return {
    'baselineSha256': _hash(bytes),
    'added': current.keys.where((key) => !previous.containsKey(key)).toList()
      ..sort(),
    'changed':
        current.keys
            .where(
              (key) =>
                  previous.containsKey(key) && previous[key] != current[key],
            )
            .toList()
          ..sort(),
    'removed': previous.keys.where((key) => !current.containsKey(key)).toList()
      ..sort(),
  };
}

class _PinnedReader {
  _PinnedReader(this.client, this.cache, this.revision);
  final HttpClient client;
  final String cache;
  final String revision;

  Future<List<int>> read(String path) async {
    final file = File('$cache/$revision/$path');
    if (await file.exists()) return file.readAsBytes();
    final uri = Uri.https(
      'raw.githubusercontent.com',
      '/$_repository/$revision/$path',
    );
    for (var attempt = 0; ; attempt++) {
      try {
        final bytes = await _download(uri).timeout(const Duration(seconds: 45));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        return bytes;
      } on _HttpFailure catch (error) {
        if (attempt >= 2 || (error.status != 429 && error.status < 500)) {
          rethrow;
        }
      } on IOException {
        if (attempt >= 2) rethrow;
      } on TimeoutException {
        if (attempt >= 2) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }
  }

  Future<List<int>> _download(Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Flick-AutoEq-catalog-generator',
    );
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw _HttpFailure(response.statusCode, uri);
    }
    return response.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  }
}

class _HttpFailure implements Exception {
  const _HttpFailure(this.status, this.uri);
  final int status;
  final Uri uri;
  @override
  String toString() => 'HTTP $status: $uri';
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();
