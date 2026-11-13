import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/autoeq_format.dart';
import 'package:flick/services/eq_preset_service.dart';

const Map<String, ParametricBandType> _kCodeToBandType = {
  'PK': ParametricBandType.peaking,
  'LS': ParametricBandType.lowShelf,
  'HS': ParametricBandType.highShelf,
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
    this.upstreamName,
    this.rig,
    this.upstreamPath,
    this.upstreamRevision,
    this.upstreamSha256,
    this.target,
  });

  final String id;
  final String brand;
  final String model;
  final String type; // in-ear, earbud, over-ear, ...
  final String source; // measurement campaign
  final double preampDb;
  final List<ParametricBand> bands;
  final String? upstreamName;
  final String? rig;
  final String? upstreamPath;
  final String? upstreamRevision;
  final String? upstreamSha256;
  // Null means upstream did not identify a target unambiguously. Never infer
  // a Harman version from headphone category alone.
  final String? target;

  String get displayName => upstreamName ?? '$brand $model';

  factory AutoEqEntry.fromJson(Map<String, dynamic> j) {
    final profile = AutoEqProfile.fromJson(j);
    String requiredString(String key) {
      final value = j[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing AutoEq field: $key');
      }
      return value;
    }

    return AutoEqEntry(
      id: requiredString('id'),
      brand: requiredString('b'),
      model: requiredString('m'),
      type: requiredString('t'),
      source: requiredString('s'),
      preampDb: profile.preampDb,
      bands: List.unmodifiable(
        profile.filters.map(
          (filter) => ParametricBand(
            frequencyHz: filter.frequencyHz,
            gainDb: filter.gainDb,
            q: filter.q,
            type: _kCodeToBandType[filter.type]!,
          ),
        ),
      ),
      upstreamName: j['n'] as String?,
      rig: j['r'] as String?,
      upstreamPath: j['p'] as String?,
      upstreamRevision: j['c'] as String?,
      upstreamSha256: j['h'] as String?,
      target: j['tg'] as String?,
    );
  }

  EqPreset toEqPreset() => EqPreset(
    id: 'autoeq_$id',
    name: displayName,
    enabled: true,
    mode: EqMode.parametric,
    preampDb: preampDb,
    graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
    parametricBands: List.unmodifiable(bands),
  );
}

class AutoEqSearchResult {
  final AutoEqEntry entry;
  final int score;
  const AutoEqSearchResult(this.entry, this.score);
}

class AutoEqCatalogService {
  AutoEqCatalogService({AssetBundle? bundle, http.Client? client})
    : _bundle = bundle ?? rootBundle,
      _client = client ?? http.Client();
  static final AutoEqCatalogService instance = AutoEqCatalogService();

  final AssetBundle _bundle;
  final http.Client _client;

  static const _catalogAsset = 'assets/autoeq/autoeq_catalog.json';
  static const _brandsAsset = 'assets/autoeq/autoeq_brands.json';

  List<AutoEqEntry>? _entriesCache;
  List<String>? _brandsCache;

  _OnlineIndex? _onlineIndex;
  static const _repoOwner = 'jaakkopasanen';
  static const _repoName = 'AutoEq';

  /// Pinned to `tool/autoeq_catalog.lock.json`. Fetching raw files at a fixed
  /// commit avoids GitHub's anonymous API rate limit and keeps the index and
  /// profile from the same revision. Update both together deliberately.
  static const upstreamRevision = '7ae0f56d53074872b028649617a22bbb4232feb7';

  Future<List<AutoEqEntry>> loadBundled() async {
    final cached = _entriesCache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_catalogAsset);
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => AutoEqEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    if (entries.map((e) => e.id).toSet().length != entries.length) {
      throw const FormatException('Duplicate AutoEq catalog IDs');
    }
    return _entriesCache = List.unmodifiable(entries);
  }

  Future<List<String>> loadBrands() async {
    final cached = _brandsCache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_brandsAsset);
    final list = (jsonDecode(raw) as List).cast<String>();
    return _brandsCache = List.unmodifiable(list);
  }

  static final _separators = RegExp(r'[^\p{L}\p{N}+]', unicode: true);
  String _norm(String s) => s.toLowerCase().replaceAll(_separators, '');

  /// Substring + token matching. Empty [query] returns everything (optionally
  /// filtered by [brand]). Score ranks exact-model and brand hits higher.
  List<AutoEqSearchResult> search(
    String query, {
    String? brand,
    int limit = 60,
  }) {
    if (limit <= 0) return const [];
    final entries = _entriesCache ?? const <AutoEqEntry>[];
    final brandNorm = brand == null || brand.isEmpty ? null : _norm(brand);
    final q = query.trim();
    final qNorm = _norm(q);
    // Tokenize before stripping separators, so reordered/partial multi-word
    // queries still work. Require every token, not just an unrelated brand hit.
    final qTokens = q
        .split(RegExp(r'\s+'))
        .map(_norm)
        .where((token) => token.isNotEmpty)
        .toList();

    final results = <AutoEqSearchResult>[];
    for (final e in entries) {
      if (brandNorm != null && _norm(e.brand) != brandNorm) continue;

      if (qNorm.isEmpty) {
        results.add(AutoEqSearchResult(e, 0));
        continue;
      }

      final modelNorm = _norm(e.model);
      final brandNormE = _norm(e.brand);
      final nameNorm = _norm(e.displayName);
      var score = 0;
      if ('$brandNormE$modelNorm' == qNorm || nameNorm == qNorm) {
        score = 1000;
      } else if (modelNorm == qNorm) {
        score = 800;
      } else if (modelNorm.contains(qNorm)) {
        score = 500;
      } else if ('$brandNormE$modelNorm'.contains(qNorm)) {
        score = 300;
      } else if (qTokens.isNotEmpty) {
        var matched = 0;
        for (final t in qTokens) {
          if (modelNorm.contains(t) ||
              brandNormE.contains(t) ||
              nameNorm.contains(t)) {
            matched++;
          }
        }
        if (matched != qTokens.length) continue;
        score = 50 * matched;
      } else {
        continue;
      }
      results.add(AutoEqSearchResult(e, score));
    }

    results.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final name = a.entry.displayName.toLowerCase().compareTo(
        b.entry.displayName.toLowerCase(),
      );
      return name != 0 ? name : a.entry.id.compareTo(b.entry.id);
    });
    return results.take(limit).toList(growable: false);
  }

  /// Fetch a model not in the bundled catalog from the AutoEq repo.
  /// Uses upstream's recommended index, avoiding GitHub's truncated recursive
  /// tree and arbitrary source/variant selection. Requests happen only here,
  /// after the user explicitly chooses online search.
  /// Returns null for unavailable, ambiguous or unsupported profiles.
  Future<AutoEqEntry?> fetchOnline(String brand, String model) async {
    if (_norm(model).isEmpty) return null;
    final index = await _loadOnlineIndex();
    if (index == null) return null;

    final manufacturers = index.manufacturers;
    final brandNorm = _norm(brand);
    final modelNorm = _norm(model);
    if (modelNorm.isEmpty) return null;
    // Strip a duplicated brand prefix before trying aliases. A manufacturer's
    // canonical upstream name may add words (Simgot -> Simgot Audio), so match
    // both the user's spelling and the canonical one.
    final modelBody = brandNorm.isNotEmpty && modelNorm.startsWith(brandNorm)
        ? modelNorm.substring(brandNorm.length)
        : modelNorm;
    // A model-only candidate is valid when no brand was supplied or the model
    // already includes it. Otherwise a mismatched brand must not be ignored.
    final candidates = <String>{
      if (brandNorm.isEmpty || modelNorm.startsWith(brandNorm)) modelNorm,
    };
    void addCandidate(String normalizedBrand) {
      if (normalizedBrand.isNotEmpty && modelBody.isNotEmpty) {
        candidates.add('$normalizedBrand$modelBody');
      }
    }

    addCandidate(brandNorm);
    final canonicalBrand = manufacturers.canonicalBrand(brand);
    if (canonicalBrand != null) addCandidate(_norm(canonicalBrand));

    // Also resolve a full "brand model" string through the manufacturer table.
    // This covers an empty brand field and aliases such as 7Hertz -> 7Hz.
    final combined = [
      brand.trim(),
      model.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (combined.isNotEmpty) {
      try {
        final (resolvedBrand, resolvedModel) = manufacturers.split(combined);
        candidates.add(_norm('$resolvedBrand$resolvedModel'));
      } on FormatException {
        // Unknown manufacturer: the raw candidates above may still match.
      }
    }

    final matches = index.entries.where((e) {
      if (candidates.contains(_norm(e.name))) return true;
      try {
        final (resolvedBrand, resolvedModel) = manufacturers.split(e.name);
        return candidates.contains(_norm('$resolvedBrand$resolvedModel'));
      } on FormatException {
        return false;
      }
    }).toList();
    // Never silently substitute e.g. HD 650 for HD 650 (different earpads).
    if (matches.length != 1) return null;
    final match = matches.single;

    final uri = Uri.https(
      'raw.githubusercontent.com',
      '/$_repoOwner/$_repoName/${index.revision}/${match.path}',
    );
    try {
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final profile = AutoEqProfile.parse(utf8.decode(resp.bodyBytes));
      final (resolvedBrand, resolvedModel) = index.manufacturers.split(
        match.name,
      );
      return AutoEqEntry.fromJson({
        'id': sha256.convert(utf8.encode(match.path)).toString(),
        'b': resolvedBrand,
        'm': resolvedModel,
        'n': match.name,
        't': match.type,
        's': match.source,
        'r': match.rig,
        'p': match.path,
        'c': index.revision,
        'h': sha256.convert(resp.bodyBytes).toString(),
        ...profile.toJson(),
      });
    } catch (_) {
      return null;
    }
  }

  Future<_OnlineIndex?> _loadOnlineIndex() async {
    final cached = _onlineIndex;
    if (cached != null) return cached;
    final revision = upstreamRevision;
    try {
      final indexUri = Uri.https(
        'raw.githubusercontent.com',
        '/$_repoOwner/$_repoName/$revision/results/README.md',
      );
      final indexResponse = await _client
          .get(indexUri)
          .timeout(const Duration(seconds: 20));
      if (indexResponse.statusCode != 200) return null;
      final manufacturersUri = Uri.https(
        'raw.githubusercontent.com',
        '/$_repoOwner/$_repoName/$revision/dbtools/manufacturers.tsv',
      );
      final manufacturersResponse = await _client
          .get(manufacturersUri)
          .timeout(const Duration(seconds: 20));
      if (manufacturersResponse.statusCode != 200) return null;
      return _onlineIndex = _OnlineIndex(
        revision,
        AutoEqRecommendation.parseIndex(utf8.decode(indexResponse.bodyBytes)),
        AutoEqManufacturers(utf8.decode(manufacturersResponse.bodyBytes)),
      );
    } catch (_) {
      return null;
    }
  }
}

class _OnlineIndex {
  const _OnlineIndex(this.revision, this.entries, this.manufacturers);
  final String revision;
  final List<AutoEqRecommendation> entries;
  final AutoEqManufacturers manufacturers;
}
