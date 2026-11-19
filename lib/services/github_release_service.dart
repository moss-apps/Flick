/// A semantic version parsed from a GitHub release tag.
class SemVer implements Comparable<SemVer> {
  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease = const [],
  });

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  bool get isPrerelease => prerelease.isNotEmpty;

  static SemVer? tryParse(String input) {
    var value = input.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }

    final buildIndex = value.indexOf('+');
    if (buildIndex >= 0) {
      value = value.substring(0, buildIndex);
    }

    var prereleaseParts = const <String>[];
    final prereleaseIndex = value.indexOf('-');
    if (prereleaseIndex >= 0) {
      prereleaseParts = value
          .substring(prereleaseIndex + 1)
          .split('.')
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      value = value.substring(0, prereleaseIndex);
    }

    final parts = value.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      if (part.isEmpty || int.tryParse(part) == null) return null;
      numbers.add(int.parse(part));
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }

    return SemVer(
      major: numbers[0],
      minor: numbers[1],
      patch: numbers[2],
      prerelease: prereleaseParts,
    );
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;

    final length = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var i = 0; i < length; i++) {
      final left = prerelease[i];
      final right = other.prerelease[i];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      if (leftNumber != null && rightNumber != null) {
        final result = leftNumber.compareTo(rightNumber);
        if (result != 0) return result;
        continue;
      }
      if (leftNumber != null) return -1;
      if (rightNumber != null) return 1;
      final result = left.compareTo(right);
      if (result != 0) return result;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    if (prerelease.isEmpty) return base;
    return '$base-${prerelease.join('.')}';
  }
}

/// An installable Flick build offered by GitHub.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.isPrerelease,
  });

  final String version;
  final String title;
  final String notes;
  final String releaseUrl;
  final String downloadUrl;
  final bool isPrerelease;
}

/// The newest eligible stable and pre-release builds.
class LatestReleaseUpdates {
  const LatestReleaseUpdates({this.stable, this.beta});

  final AppRelease? stable;
  final AppRelease? beta;

  bool get hasUpdates => stable != null || beta != null;
}

class GitHubReleaseService {
  static const String releasesUri =
      'https://api.github.com/repos/moss-apps/Flick/releases?per_page=100';
  static const String _releaseTagUrl =
      'https://github.com/moss-apps/Flick/releases/tag';

  /// Picks the newest stable and pre-release builds newer than
  /// [currentVersion]. Releases without an attached APK are ignored.
  static LatestReleaseUpdates selectUpdates(
    List<dynamic> releases,
    String currentVersion,
  ) {
    final current = SemVer.tryParse(currentVersion);
    if (current == null) return const LatestReleaseUpdates();

    AppRelease? stable;
    AppRelease? beta;
    SemVer? stableVersion;
    SemVer? betaVersion;

    for (final entry in releases) {
      if (entry is! Map) continue;
      final release = Map<String, dynamic>.from(entry);
      if (release['draft'] == true) continue;

      final tag = release['tag_name'];
      if (tag is! String) continue;
      final version = SemVer.tryParse(tag);
      if (version == null || version.compareTo(current) <= 0) continue;

      final asset = _selectApkAsset(release['assets']);
      if (asset == null) continue;

      final isPrerelease =
          release['prerelease'] == true || version.isPrerelease;
      final name = release['name'];
      final body = release['body'];
      final htmlUrl = release['html_url'];
      final normalizedVersion = version.toString();

      final appRelease = AppRelease(
        version: normalizedVersion,
        title: name is String && name.trim().isNotEmpty
            ? name.trim()
            : normalizedVersion,
        notes: body is String ? body : '',
        releaseUrl: htmlUrl is String && htmlUrl.isNotEmpty
            ? htmlUrl
            : '$_releaseTagUrl/$tag',
        downloadUrl: asset['browser_download_url'] as String,
        isPrerelease: isPrerelease,
      );

      if (isPrerelease) {
        if (betaVersion == null || version.compareTo(betaVersion) > 0) {
          beta = appRelease;
          betaVersion = version;
        }
      } else if (stableVersion == null ||
          version.compareTo(stableVersion) > 0) {
        stable = appRelease;
        stableVersion = version;
      }
    }

    return LatestReleaseUpdates(stable: stable, beta: beta);
  }

  static Map<String, dynamic>? _selectApkAsset(dynamic assets) {
    if (assets is! List) return null;

    final candidates = <Map<String, dynamic>>[];
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || !name.toLowerCase().endsWith('.apk')) continue;
      if (url is! String || url.isEmpty) continue;
      final size = asset['size'];
      if (size is num && size <= 0) continue;
      candidates.add(Map<String, dynamic>.from(asset));
    }

    if (candidates.isEmpty) return null;
    for (final candidate in candidates) {
      final name = candidate['name'] as String;
      if (name.toLowerCase().contains('full')) return candidate;
    }
    return candidates.first;
  }
}
