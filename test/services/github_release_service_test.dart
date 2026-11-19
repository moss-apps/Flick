import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/github_release_service.dart';

Map<String, dynamic> _apk(String name, {int size = 1024, String? url}) {
  return {
    'name': name,
    'size': size,
    'browser_download_url': url ?? 'https://example.com/$name',
  };
}

Map<String, dynamic> _release({
  required String tag,
  bool prerelease = false,
  bool draft = false,
  List<Map<String, dynamic>>? assets,
  String? name,
  String body = '',
}) {
  return {
    'tag_name': tag,
    'name': name ?? tag,
    'body': body,
    'html_url': 'https://github.com/moss-apps/Flick/releases/tag/$tag',
    'prerelease': prerelease,
    'draft': draft,
    'assets': assets ?? [_apk('flick_$tag-release-official-full.apk')],
  };
}

void main() {
  group('SemVer', () {
    test('parses tags with v prefixes and optional components', () {
      expect(SemVer.tryParse('v1.2.3-beta.4')?.toString(), '1.2.3-beta.4');
      expect(SemVer.tryParse('1.2')?.toString(), '1.2.0');
      expect(SemVer.tryParse('1')?.toString(), '1.0.0');
      expect(SemVer.tryParse('1.2.3+build.7')?.toString(), '1.2.3');
      expect(SemVer.tryParse('release-1.2.3'), isNull);
    });

    test('orders numeric prerelease identifiers numerically', () {
      final beta9 = SemVer.tryParse('0.23.3-beta.9')!;
      final beta10 = SemVer.tryParse('0.23.3-beta.10')!;
      expect(beta10.compareTo(beta9), greaterThan(0));
      expect(beta9.compareTo(beta10), lessThan(0));
    });

    test('orders prereleases before their stable version', () {
      final beta = SemVer.tryParse('0.23.3-beta.5')!;
      final stable = SemVer.tryParse('0.23.3')!;
      expect(beta.compareTo(stable), lessThan(0));
      expect(stable.compareTo(beta), greaterThan(0));
    });

    test('orders alphanumeric identifiers after numeric ones', () {
      final numeric = SemVer.tryParse('1.0.0-1')!;
      final word = SemVer.tryParse('1.0.0-alpha')!;
      expect(word.compareTo(numeric), greaterThan(0));
    });
  });

  group('GitHubReleaseService.selectUpdates', () {
    test(
      'treats semver betas as pre-releases even when GitHub flag is off',
      () {
        final updates = GitHubReleaseService.selectUpdates([
          _release(tag: '0.23.3-beta.6'),
        ], '0.23.3-beta.5');

        expect(updates.stable, isNull);
        expect(updates.beta?.version, '0.23.3-beta.6');
        expect(updates.beta?.isPrerelease, isTrue);
      },
    );

    test('treats GitHub prerelease flag as a pre-release', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.24.0', prerelease: true),
      ], '0.23.3-beta.5');

      expect(updates.stable, isNull);
      expect(updates.beta?.version, '0.24.0');
      expect(updates.beta?.isPrerelease, isTrue);
    });

    test('ignores releases without an APK asset', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.24.0', assets: const []),
        _release(tag: '0.24.0', assets: [_apk('flick_0.24.0.apk.sha1')]),
      ], '0.23.3');

      expect(updates.hasUpdates, isFalse);
    });

    test('falls back to an older release that has an APK', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.25.0', assets: const []),
        _release(tag: '0.24.0'),
      ], '0.23.3');

      expect(updates.stable?.version, '0.24.0');
    });

    test('does not offer equal or older versions', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.23.3'),
        _release(tag: '0.23.2'),
      ], '0.23.3');

      expect(updates.hasUpdates, isFalse);
    });

    test('skips draft releases', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.24.0', draft: true),
      ], '0.23.3');

      expect(updates.hasUpdates, isFalse);
    });

    test('selects the newest stable and beta independently', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(tag: '0.23.2'),
        _release(tag: '0.24.0'),
        _release(tag: '0.23.3-beta.5'),
        _release(tag: '0.23.3-beta.6'),
      ], '0.23.3-beta.5');

      expect(updates.stable?.version, '0.24.0');
      expect(updates.beta?.version, '0.23.3-beta.6');
    });

    test('prefers the full APK when several are attached', () {
      final updates = GitHubReleaseService.selectUpdates([
        _release(
          tag: '0.24.0',
          assets: [
            _apk('flick_0.24.0-release-official-lite.apk'),
            _apk('flick_0.24.0-release-official-full.apk'),
          ],
        ),
      ], '0.23.3');

      expect(
        updates.stable?.downloadUrl,
        'https://example.com/flick_0.24.0-release-official-full.apk',
      );
    });
  });
}
