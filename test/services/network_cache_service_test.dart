import 'dart:io';

import 'package:flick/services/network_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late NetworkCacheService service;

  // FS mtime granularity can be 1s, so LRU order is controlled explicitly.
  final base = DateTime(2020, 1, 1, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('network_cache_test');
    service = NetworkCacheService(
      sizeCapBytes: 100,
      rootDirectory: Directory('${root.path}/network_cache'),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('stash then getPath returns the same file', () async {
    final path = await service.stash(1, 'songA', [1, 2, 3], extension: 'flac');
    final cached = await service.getPath(1, 'songA', extension: 'flac');
    expect(cached, path);
    expect(await File(path).readAsBytes(), [1, 2, 3]);
  });

  test('getPath returns null when not cached or for another server', () async {
    await service.stash(1, 'songA', [1, 2, 3], extension: 'flac');
    expect(await service.getPath(1, 'songB', extension: 'flac'), isNull);
    expect(await service.getPath(2, 'songA', extension: 'flac'), isNull);
  });

  test('cap is enforced and oldest entry is evicted first', () async {
    final p1 = await service.stash(
      1,
      'old',
      List.filled(40, 0),
      extension: 'flac',
    );
    await File(p1).setLastModified(base);
    final p2 = await service.stash(
      1,
      'mid',
      List.filled(40, 0),
      extension: 'flac',
    );
    await File(p2).setLastModified(base.add(const Duration(seconds: 1)));
    final p3 = await service.stash(
      1,
      'new',
      List.filled(40, 0),
      extension: 'flac',
    );
    await File(p3).setLastModified(base.add(const Duration(seconds: 2)));

    await service.stash(1, 'trigger', [1], extension: 'flac');

    expect(await service.getPath(1, 'old', extension: 'flac'), isNull);
    expect(await service.getPath(1, 'mid', extension: 'flac'), isNotNull);
    expect(await service.getPath(1, 'new', extension: 'flac'), isNotNull);
  });

  test('recently accessed entries survive eviction', () async {
    final p1 = await service.stash(
      1,
      'old',
      List.filled(40, 0),
      extension: 'flac',
    );
    await File(p1).setLastModified(base);
    final p2 = await service.stash(
      1,
      'fresh',
      List.filled(40, 0),
      extension: 'flac',
    );
    await File(p2).setLastModified(base.add(const Duration(seconds: 1)));

    expect(await service.getPath(1, 'old', extension: 'flac'), isNotNull);
    await File(p1).setLastModified(base.add(const Duration(seconds: 10)));

    await service.stash(1, 'new', List.filled(40, 0), extension: 'flac');

    expect(await service.getPath(1, 'old', extension: 'flac'), isNotNull);
    expect(await service.getPath(1, 'fresh', extension: 'flac'), isNull);
  });

  test('a single file exceeding the cap is still playable', () async {
    final path = await service.stash(
      1,
      'huge',
      List.filled(200, 0),
      extension: 'flac',
    );
    expect(await File(path).exists(), isTrue);
    expect(await service.getPath(1, 'huge', extension: 'flac'), path);
  });

  test('staging files are never lookup or eviction candidates', () async {
    final dest = await service.pathFor(1, 'pending');
    final staging = File(
      '${File(dest).parent.path}/.${File(dest).uri.pathSegments.last}.1.part',
    );
    await staging.writeAsBytes(List.filled(200, 0));
    final oldStylePart = File('$dest.part');
    await oldStylePart.writeAsBytes([1]);
    expect(await service.getPath(1, 'pending'), isNull);
    await service.stash(1, 'completed', List.filled(40, 0));
    expect(await staging.exists(), isTrue);
    expect(await oldStylePart.exists(), isTrue);
  });

  test(
    'remove drops every extension for one song and leaves staging alone',
    () async {
      final flac = await service.stash(1, 'songA', [1], extension: 'flac');
      final dsf = await service.stash(1, 'songA', [2], extension: 'dsf');
      final other = await service.stash(1, 'songB', [3], extension: 'flac');
      final dest = await service.pathFor(1, 'songA', extension: 'flac');
      final staging = File(
        '${File(dest).parent.path}/.${File(dest).uri.pathSegments.last}.1.part',
      );
      await staging.writeAsBytes([9]);

      await service.remove(1, 'songA');

      expect(await File(flac).exists(), isFalse);
      expect(await File(dsf).exists(), isFalse);
      expect(await staging.exists(), isTrue);
      expect(await File(other).exists(), isTrue);
    },
  );
}
