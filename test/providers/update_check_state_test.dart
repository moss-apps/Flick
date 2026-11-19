import 'package:flutter_test/flutter_test.dart';

import 'package:flick/models/update_channel.dart';
import 'package:flick/providers/update_check_provider.dart';
import 'package:flick/services/github_release_service.dart';

AppRelease _release(String version, {bool isPrerelease = false}) {
  return AppRelease(
    version: version,
    title: version,
    notes: '',
    releaseUrl: 'https://example.com/$version',
    downloadUrl: 'https://example.com/$version.apk',
    isPrerelease: isPrerelease,
  );
}

void main() {
  const stable = UpdateChannel.stable;
  const beta = UpdateChannel.beta;
  const both = UpdateChannel.both;

  test('UpdateChannel falls back to stable for unknown storage values', () {
    expect(UpdateChannel.fromStorage('beta'), UpdateChannel.beta);
    expect(UpdateChannel.fromStorage('both'), UpdateChannel.both);
    expect(UpdateChannel.fromStorage('unknown'), UpdateChannel.stable);
    expect(UpdateChannel.fromStorage(null), UpdateChannel.stable);
  });

  test('Play Store builds ignore the selected channel', () {
    const state = UpdateCheckState(
      isPlayStoreBuild: true,
      updateAvailable: true,
    );

    expect(state.hasUpdateForChannel(stable), isTrue);
    expect(state.hasUpdateForChannel(beta), isTrue);
    expect(state.hasUpdateForChannel(both), isTrue);
  });

  test('stable and beta releases are offered independently', () {
    final state = UpdateCheckState(
      isPlayStoreBuild: false,
      stableRelease: _release('1.2.3'),
      betaRelease: _release('1.3.0-beta.1', isPrerelease: true),
    );

    expect(state.hasUpdateForChannel(stable), isTrue);
    expect(state.hasUpdateForChannel(beta), isTrue);
    expect(state.hasUpdateForChannel(both), isTrue);
  });

  test('a channel without a matching release has no update', () {
    final state = UpdateCheckState(
      isPlayStoreBuild: false,
      betaRelease: _release('1.3.0-beta.1', isPrerelease: true),
    );

    expect(state.hasUpdateForChannel(stable), isFalse);
    expect(state.hasUpdateForChannel(beta), isTrue);
    expect(state.hasUpdateForChannel(both), isTrue);
  });

  test('releaseForChannel returns the newest release and prefers stable', () {
    final stableRelease = _release('1.2.3');
    final betaRelease = _release('1.3.0-beta.1', isPrerelease: true);
    final state = UpdateCheckState(
      isPlayStoreBuild: false,
      stableRelease: stableRelease,
      betaRelease: betaRelease,
    );

    expect(state.releaseForChannel(stable), same(stableRelease));
    expect(state.releaseForChannel(beta), same(betaRelease));
    expect(state.releaseForChannel(both), same(betaRelease));

    final tiedState = UpdateCheckState(
      isPlayStoreBuild: false,
      stableRelease: stableRelease,
      betaRelease: _release('1.2.3'),
    );
    expect(tiedState.releaseForChannel(both), same(stableRelease));
  });
}
