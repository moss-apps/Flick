import 'dart:convert';

import 'package:http/http.dart' as http;

/// Reads the repository's GitHub contributor list for Settings → App Info.
///
/// The endpoint follows commit history on the default branch, most active
/// first. Bot accounts are skipped. Profile pictures are loaded separately
/// from `github.com/<username>.png`, so this request is not repeated for
/// every portrait.
class GitHubContributorsService {
  static final Uri contributorsUri = Uri.parse(
    'https://api.github.com/repos/moss-apps/Flick/contributors?per_page=100',
  );

  static Future<List<String>> fetch() async {
    final response = await http
        .get(
          contributorsUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'FlickPlayer',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception(
        'GitHub contributors request failed: ${response.statusCode}',
      );
    }

    return parseUsernames(response.body);
  }

  /// Parses a GitHub contributors response into usernames, preserving order.
  static List<String> parseUsernames(String body) {
    final data = jsonDecode(body);
    if (data is! List) return const [];

    final usernames = <String>[];
    for (final entry in data) {
      if (entry is! Map) continue;
      final login = entry['login'];
      if (login is! String || login.trim().isEmpty) continue;
      if (entry['type'] == 'Bot' || login.endsWith('[bot]')) continue;
      usernames.add(login);
    }
    return usernames;
  }
}
