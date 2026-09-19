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

  static final RegExp _artistSeparator = RegExp(
    r'\s*&\s*|\s*,\s*|\s*×\s*|\s+(?:x|with|feat\.?|featuring|vs\.?)\s+',
    caseSensitive: false,
  );

  /// Artist strings to try against search APIs, most specific first.
  ///
  /// Collab credits ("Tiësto & Tate McRae") resolve to the wrong catalog on
  /// boidu's text search; the primary artist is the reliable fallback. Single
  /// artists return just themselves so no extra request is made.
  static List<String> artistVariants(String artist) {
    final full = artist.trim();
    if (full.isEmpty) return const [];
    final primary = full.split(_artistSeparator).first.trim();
    if (primary.length < 2 || normalize(primary) == normalize(full)) {
      return [full];
    }
    return [full, primary];
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
    final ids = rankCollectionIds(
      album: album,
      artist: artist,
      results: results,
    );
    return ids.isEmpty ? null : ids.first;
  }

  /// All matching album `collectionId`s ordered best-first, deduped.
  ///
  /// [pickCollectionId] only needs the winner, but motion art may live on a
  /// sibling edition, so the service probes every candidate. Ties keep the
  /// original iTunes result order.
  static List<String> rankCollectionIds({
    required String album,
    required String artist,
    required List<Map<String, dynamic>> results,
  }) {
    final reqBase = baseName(album);
    if (reqBase.isEmpty) return const [];
    final reqTokens = editionTokens(album);
    final scored = <({int index, int score, String id})>[];
    final seen = <String>{};
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      final cName = (r['collectionName'] as String?) ?? '';
      final aName = (r['artistName'] as String?) ?? '';
      if (!artistMatches(artist, aName)) continue;
      if (baseName(cName) != reqBase) continue;
      final id = r['collectionId']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      var score = 30;
      final candTokens = editionTokens(cName);
      for (final token in reqTokens) {
        // Missing a qualifier the user asked for is the worst signal.
        score += candTokens.contains(token) ? 6 : -10;
      }
      for (final token in candTokens) {
        if (!reqTokens.contains(token)) score -= 3;
      }
      if (score > 0) scored.add((index: i, score: score, id: id));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return [for (final s in scored) s.id];
  }

  /// Album `collectionId`s extracted from iTunes *song* search [results].
  ///
  /// Songs are only a backup way to discover collection ids (album search can
  /// miss an album entirely, see DRIVE/Tiësto). Only collections that still
  /// match [album] via [nameMatchesAlbum] qualify; the collection containing
  /// [representativeSongTitle] ranks first and the rest keep iTunes order.
  static List<String> rankCollectionIdsFromSongs({
    required String album,
    required String artist,
    String? representativeSongTitle,
    required List<Map<String, dynamic>> results,
  }) {
    final wantedSong = normalize(representativeSongTitle ?? '');
    final preferred = <String>[];
    final rest = <String>[];
    final seen = <String>{};
    for (final r in results) {
      final aName = (r['artistName'] as String?) ?? '';
      if (!artistMatches(artist, aName)) continue;
      final cName = (r['collectionName'] as String?) ?? '';
      if (cName.isNotEmpty &&
          !nameMatchesAlbum(requested: album, candidate: cName)) {
        continue;
      }
      final id = r['collectionId']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      final songName = normalize((r['trackName'] as String?) ?? '');
      if (wantedSong.isNotEmpty && songName == wantedSong) {
        preferred.add(id);
      } else {
        rest.add(id);
      }
    }
    return [...preferred, ...rest];
  }
}
