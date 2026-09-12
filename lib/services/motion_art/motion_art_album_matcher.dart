/// Pure string/edition matching for Motion Art album resolution.
///
/// Extracted from [AnimatedArtworkService] so the tricky "Fearless vs
/// Fearless (Taylor's Version)" style logic is unit-testable without network.
class MotionArtAlbumMatcher {
  MotionArtAlbumMatcher._();

  /// Edition words that distinguish otherwise identical albums. Ordered by
  /// specificity so multi-word phrases win before single words.
  static const List<String> editionWords = [
    'taylor s version',
    'super deluxe',
    'deluxe',
    'expanded',
    'remastered',
    'remaster',
    'remix',
    'bonus',
    'platinum',
    'anniversary',
    'edition',
    'version',
    'explicit',
    'clean',
    'live',
    'acoustic',
    'ep',
    'single',
  ];

  static const Map<String, String> _diacritics = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  /// Lowercase, strip diacritics/punctuation, collapse whitespace.
  static String normalize(String s) {
    var x = s.toLowerCase();
    x = x.replaceAll('’', "'").replaceAll('‘', "'");
    x = x.replaceAll('“', '"').replaceAll('”', '"');
    x = x.replaceAll(RegExp('[\u2013\u2014]'), ' ');
    for (final entry in _diacritics.entries) {
      x = x.replaceAll(entry.key, entry.value);
    }
    x = x.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  /// The album name with edition qualifiers and bracketed suffixes removed,
  /// e.g. `"Fearless (Taylor's Version)"` -> `"fearless"`.
  static String baseName(String s) {
    var x = s.toLowerCase();
    x = x.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    x = x.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    x = normalize(x);
    final parts = x
        .split(' ')
        .where((p) => p.isNotEmpty && !editionWords.contains(p));
    return parts.join(' ').trim();
  }

  /// Canonical edition tokens present in [s].
  static Set<String> editionTokens(String s) {
    final x = normalize(s);
    final out = <String>{};
    for (final word in editionWords) {
      // `normalize` already turned apostrophes into spaces, so the phrase is
      // matched as space-separated words.
      if (RegExp('\\b${word.replaceAll(' ', r'\s+')}\\b').hasMatch(x)) {
        out.add(word);
      }
    }
    return out;
  }

  /// Whether the requested edition is fully satisfied by [candidate].
  static bool nameMatchesAlbum({
    required String requested,
    required String candidate,
  }) {
    final reqNorm = normalize(requested);
    final candNorm = normalize(candidate);
    if (reqNorm == candNorm) return true;
    if (baseName(requested) != baseName(candidate)) return false;
    final reqTokens = editionTokens(requested);
    final candTokens = editionTokens(candidate);
    // Every requested edition qualifier must survive; a plain request accepts
    // any edition of the same base album.
    return reqTokens.every(candTokens.contains);
  }

  /// Loose artist comparison that tolerates `feat.`, `&`, and local variants.
  static bool artistMatches(String requested, String candidate) {
    final req = normalize(requested);
    if (req.isEmpty) return true;
    final cand = normalize(candidate);
    if (cand.isEmpty) return false;
    if (cand == req || cand.contains(req) || req.contains(cand)) return true;
    final reqTokens = req.split(' ').toSet();
    final candTokens = cand.split(' ').toSet();
    final overlap = reqTokens.intersection(candTokens).length;
    final slack = reqTokens.length <= 2 ? 0 : 1;
    return overlap >= reqTokens.length - slack;
  }

  /// Pick the best iTunes `collectionId` for [album]/[artist] from search
  /// [results], preserving editions. Returns null when nothing scores.
  static String? pickCollectionId({
    required String album,
    required String artist,
    required List<Map<String, dynamic>> results,
  }) {
    final reqBase = baseName(album);
    if (reqBase.isEmpty) return null;
    final reqTokens = editionTokens(album);
    String? bestId;
    var bestScore = 0; // require a positive score
    for (final r in results) {
      final cName = (r['collectionName'] as String?) ?? '';
      final aName = (r['artistName'] as String?) ?? '';
      if (!artistMatches(artist, aName)) continue;
      if (baseName(cName) != reqBase) continue;
      var score = 30;
      final candTokens = editionTokens(cName);
      for (final token in reqTokens) {
        // Missing a qualifier the user asked for is the worst signal.
        score += candTokens.contains(token) ? 6 : -10;
      }
      for (final token in candTokens) {
        if (!reqTokens.contains(token)) score -= 3;
      }
      if (score > bestScore) {
        bestScore = score;
        bestId = r['collectionId']?.toString();
      }
    }
    return bestId;
  }
}
