import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flick/services/github_contributors_service.dart';

void main() {
  group('GitHubContributorsService.parseUsernames', () {
    test('keeps GitHub order and skips bots', () {
      final body = jsonEncode([
        {'login': 'ultraelectronica', 'type': 'User'},
        {'login': 'dependabot[bot]', 'type': 'Bot'},
        {'login': 'fukiame', 'type': 'User'},
        {'login': 'automation[bot]', 'type': 'User'},
      ]);

      expect(GitHubContributorsService.parseUsernames(body), [
        'ultraelectronica',
        'fukiame',
      ]);
    });

    test('returns an empty list for a non-list response', () {
      expect(
        GitHubContributorsService.parseUsernames(jsonEncode({'message': 'ok'})),
        isEmpty,
      );
    });
  });
}
