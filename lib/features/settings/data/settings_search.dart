import 'package:flutter/widgets.dart';

/// Keep this catalog limited to navigation: opening a result must never invoke
/// a setting's callback or change the user's preferences.
class SettingsSearchPage {
  const SettingsSearchPage({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.buildPage,
    this.keywords = '',
    this.sections = const [],
  });

  final String id;
  final String title;
  final String category;
  final IconData icon;
  final Widget Function(String? sectionId) buildPage;
  final String keywords;
  final List<SettingsSearchSection> sections;
}

class SettingsSearchSection {
  const SettingsSearchSection(
    this.id,
    this.title,
    this.items, {
    this.keywords = '',
  });

  final String id;
  final String title;
  final List<SettingsSearchItem> items;
  final String keywords;
}

class SettingsSearchItem {
  const SettingsSearchItem(this.id, this.title, {this.keywords = ''});

  final String id;
  final String title;
  final String keywords;
}

class SettingsSearchMatch {
  const SettingsSearchMatch(this.section, this.item, this.score);

  final SettingsSearchSection section;
  final SettingsSearchItem? item;
  final int score;

  String get title => item?.title ?? section.title;
}

class SettingsSearchResult {
  const SettingsSearchResult(this.page, this.matches, this.score);

  final SettingsSearchPage page;
  final List<SettingsSearchMatch> matches;
  final int score;
}

// Unicode letters/numbers are retained (including Chinese). Punctuation and
// spacing are ignored, so "replay gain" and "ReplayGain" match identically.
final _nonSearchCharacters = RegExp(r'[^\p{L}\p{N}]', unicode: true);

String _compact(String value) =>
    value.toLowerCase().replaceAll(_nonSearchCharacters, '');

int _titleScore(String title, String query) {
  final text = _compact(title);
  if (text == query) return 600;
  if (text.startsWith(query)) return 500;
  if (text.contains(query)) return 400;
  return 0;
}

int _score(
  String title,
  String keywords,
  String context,
  List<String> tokens,
  String query,
) {
  final ownText = _compact('$title $keywords');
  final allText = '$ownText ${_compact(context)}';
  if (!tokens.every(allText.contains)) return 0;
  final titleScore = _titleScore(title, query);
  if (titleScore > 0) return titleScore;
  if (_compact(keywords).contains(query)) return 300;
  if (tokens.every(ownText.contains)) return 250;
  if (tokens.any(ownText.contains)) return 200;
  return 100;
}

/// No I/O, preference reads, fuzzy guesses, or locale-dependent navigation.
List<SettingsSearchResult> searchSettings(
  String query,
  List<SettingsSearchPage> pages,
) {
  final compactQuery = _compact(query);
  if (compactQuery.isEmpty) return const [];
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(_compact)
      .where((token) => token.isNotEmpty)
      .toList();
  final results = <SettingsSearchResult>[];
  for (final page in pages) {
    final pageScore = _score(
      page.title,
      page.keywords,
      '',
      tokens,
      compactQuery,
    );
    final matches = <SettingsSearchMatch>[];
    for (final section in page.sections) {
      final sectionScore = _score(
        section.title,
        section.keywords,
        '${page.title} ${page.keywords}',
        tokens,
        compactQuery,
      );
      final sectionMatches = <SettingsSearchMatch>[];
      for (final item in section.items) {
        final score = _score(
          item.title,
          item.keywords,
          '${section.title} ${section.keywords} ${page.title} ${page.keywords}',
          tokens,
          compactQuery,
        );
        // A page-only match should not flood the list with every setting.
        if (score > 100) {
          sectionMatches.add(SettingsSearchMatch(section, item, score));
        }
      }
      if (sectionScore > 100 &&
          !sectionMatches.any((match) => match.item?.id == section.id)) {
        matches.add(SettingsSearchMatch(section, null, sectionScore));
      }
      matches.addAll(sectionMatches);
    }
    if (pageScore == 0 && matches.isEmpty) continue;
    // Indexed tie-breaks make order deterministic even with an unstable sort.
    final ordered = matches.indexed.toList()
      ..sort((a, b) {
        final score = b.$2.score.compareTo(a.$2.score);
        return score != 0 ? score : a.$1.compareTo(b.$1);
      });
    final best = matches.fold(
      pageScore,
      (best, match) => match.score > best ? match.score : best,
    );
    results.add(
      SettingsSearchResult(
        page,
        ordered.map((entry) => entry.$2).toList(),
        best,
      ),
    );
  }
  final ordered = results.indexed.toList()
    ..sort((a, b) {
      final score = b.$2.score.compareTo(a.$2.score);
      return score != 0 ? score : a.$1.compareTo(b.$1);
    });
  return ordered.map((entry) => entry.$2).toList();
}
