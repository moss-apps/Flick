import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/eq_preset_file_service.dart';
import 'package:flick/services/eq_preset_service.dart';

const Map<String, ParametricBandType> _kCodeToBandType = {
  'PK': ParametricBandType.peaking,
  'LS': ParametricBandType.lowShelf,
  'HS': ParametricBandType.highShelf,
  'LP': ParametricBandType.lowPass,
  'HP': ParametricBandType.highPass,
  'BP': ParametricBandType.bandPass,
  'NO': ParametricBandType.notch,
  'AP': ParametricBandType.allPass,
};

class AutoEqEntry {
  const AutoEqEntry({
    required this.id,
    required this.brand,
    required this.model,
    required this.type,
    required this.source,
    required this.preampDb,
    required this.bands,
  });

  final String id;
  final String brand;
  final String model;
  final String type; // in-ear, earbud, over-ear, ...
  final String source; // measurement campaign
  final double preampDb;
  final List<ParametricBand> bands;

  String get displayName => '$brand $model';

  factory AutoEqEntry.fromJson(Map<String, dynamic> j) {
    final raw = (j['g'] as List).cast<List>();
    final bands = raw
        .map((b) {
          final type = _kCodeToBandType[(b[3] as String).toUpperCase()] ??
              ParametricBandType.peaking;
          return ParametricBand(
            frequencyHz: (b[0] as num).toDouble(),
            gainDb: (b[1] as num).toDouble(),
            q: (b[2] as num).toDouble(),
            type: type,
          );
        })
        .toList(growable: false);
    return AutoEqEntry(
      id: j['id'] as String,
      brand: j['b'] as String,
      model: j['m'] as String,
      type: j['t'] as String,
      source: j['s'] as String,
      preampDb: (j['pa'] as num).toDouble(),
      bands: bands,
    );
  }

  EqPreset toEqPreset() => EqPreset(
        id: 'autoeq_$id',
        name: displayName,
        enabled: true,
        mode: EqMode.parametric,
        preampDb: preampDb,
        graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
        parametricBands: bands,
      );
}

class AutoEqSearchResult {
  final AutoEqEntry entry;
  final int score;
  const AutoEqSearchResult(this.entry, this.score);
}

class AutoEqCatalogService {
  AutoEqCatalogService._();
  static final AutoEqCatalogService instance = AutoEqCatalogService._();

  static const _catalogAsset = 'assets/autoeq/autoeq_catalog.json';
  static const _brandsAsset = 'assets/autoeq/autoeq_brands.json';

  // ponytail: process-lifetime cache; catalog is static, no invalidation needed.
  List<AutoEqEntry>? _entriesCache;
  List<String>? _brandsCache;

  // Online path index cache (model-dir -> repo path), lazily fetched.
  Map<String, String>? _onlineIndex;
  static const _repoOwner = 'jaakkopasanen';
  static const _repoName = 'AutoEq';

  Future<List<AutoEqEntry>> loadBundled() async {
    final cached = _entriesCache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_catalogAsset);
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => AutoEqEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    _entriesCache = entries;
    return entries;
  }

  Future<List<String>> loadBrands() async {
    final cached = _brandsCache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_brandsAsset);
    final list = (jsonDecode(raw) as List).cast<String>();
    _brandsCache = list;
    return list;
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Substring + token matching. Empty [query] returns everything (optionally
  /// filtered by [brand]). Score ranks exact-model and brand hits higher.
  List<AutoEqSearchResult> search(
    String query, {
    String? brand,
    int limit = 60,
  }) {
    final entries = _entriesCache ?? const <AutoEqEntry>[];
    final brandNorm = brand == null || brand.isEmpty ? null : _norm(brand);
    final q = query.trim();
    final qNorm = q.isEmpty ? null : _norm(q);
    final qTokens =
        qNorm == null ? <String>[] : qNorm.split(RegExp(r'\s+'))..removeWhere((t) => t.isEmpty);

    final results = <AutoEqSearchResult>[];
    for (final e in entries) {
      if (brandNorm != null && _norm(e.brand) != brandNorm) continue;

      if (qNorm == null) {
        results.add(AutoEqSearchResult(e, 0));
        continue;
      }

      final modelNorm = _norm(e.model);
      final brandNormE = _norm(e.brand);
      var score = 0;
      if ('$brandNormE$modelNorm' == qNorm) {
        score = 1000;
      } else if (modelNorm == qNorm) {
        score = 800;
      } else if (modelNorm.contains(qNorm)) {
        score = 500;
      } else if ('$brandNormE $modelNorm'.contains(qNorm)) {
        score = 300;
      } else if (qTokens.isNotEmpty) {
        var matched = 0;
        for (final t in qTokens) {
          if (modelNorm.contains(t) || brandNormE.contains(t)) matched++;
        }
        if (matched == 0) continue;
        score = 50 * matched;
      } else {
        continue;
      }
      results.add(AutoEqSearchResult(e, score));
    }

    results.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.entry.model.toLowerCase().compareTo(b.entry.model.toLowerCase());
    });
    return results.take(limit).toList(growable: false);
  }

  /// Fetch a model not in the bundled catalog from the AutoEq repo.
  /// Builds an in-memory index of ParametricEQ.txt paths on first use.
  /// Returns null if not found or unavailable.
  Future<AutoEqEntry?> fetchOnline(String brand, String model) async {
    final index = await _loadOnlineIndex();
    if (index == null) return null;

    final modelNorm = _norm(model);
    final brandNorm = _norm(brand);
    String? path;
    // Prefer an exact dir-name match, then a brand+model contains match.
    for (final entry in index.entries) {
      if (_norm(entry.key) == modelNorm) {
        path = entry.value;
        break;
      }
    }
    path ??= index.entries
        .firstWhere(
          (e) => _norm(e.key).contains(modelNorm) && _norm(e.key).contains(brandNorm),
          orElse: () => const MapEntry('', ''),
        )
        .value;
    if (path.isEmpty) return null;

    final uri = Uri.https('raw.githubusercontent.com',
        '/$_repoOwner/$_repoName/master/$path');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final text = resp.body;
      final preset = const EqPresetFileService().fromFileText(
        text: text,
        fileName: '$brand $model',
      );
      return AutoEqEntry(
        id: 'online_$modelNorm',
        brand: brand,
        model: model,
        type: 'online',
        source: 'AutoEq',
        preampDb: preset.preampDb,
        bands: preset.parametricBands,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> _loadOnlineIndex() async {
    final cached = _onlineIndex;
    if (cached != null) return cached;
    final uri = Uri.https('api.github.com',
        '/repos/$_repoOwner/$_repoName/git/trees/master', {'recursive': '1'});
    try {
      final resp = await http.get(uri, headers: {
        'Accept': 'application/vnd.github+json',
      }).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['truncated'] == true) {
        // ponytail: truncated tree — long-tail discovery degrades but common
        // models remain reachable. Acceptable for an opt-in fallback.
      }
      final tree = (body['tree'] as List).cast<Map<String, dynamic>>();
      final index = <String, String>{};
      for (final node in tree) {
        final p = node['path'] as String;
        if (p.endsWith('/ParametricEQ.txt')) {
          final end = p.lastIndexOf('/');
          final start = p.lastIndexOf('/', end - 1) + 1;
          index[p.substring(start, end)] = p;
        }
      }
      _onlineIndex = index;
      return index;
    } catch (_) {
      return null;
    }
  }
}
