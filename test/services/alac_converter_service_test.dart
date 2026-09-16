import 'dart:convert';
import 'dart:io';

import 'package:flick/services/alac_converter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory cacheDir;
  late Directory sourcesDir;

  final base = DateTime(2020, 1, 1, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('wav_cache_test');
    cacheDir = Directory('${root.path}/wav_cache');
    await cacheDir.create(recursive: true);
    sourcesDir = Directory('${root.path}/sources');
    await sourcesDir.create(recursive: true);
    AlacConverterService.setCacheRootForTesting(cacheDir.path);
  });

  tearDown(() async {
    AlacConverterService.setCacheRootForTesting(null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> writeSource(String name, int bytes) async {
    final file = File('${sourcesDir.path}/$name');
    await file.writeAsBytes(List.filled(bytes, 0));
    return file;
  }

  Future<File> writeWav(String name, int bytes, {DateTime? mtime}) async {
    final file = File('${cacheDir.path}/$name');
    await file.writeAsBytes(List.filled(bytes, 0));
    if (mtime != null) await file.setLastModified(mtime);
    return file;
  }

  Future<void> writeManifest(Map<String, dynamic> entries) async {
    await File('${cacheDir.path}/manifest.json').writeAsString(
      jsonEncode(entries),
    );
  }

  Future<Map<String, dynamic>> readManifest() async {
    final raw = await File('${cacheDir.path}/manifest.json').readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // Seeds one valid cache entry and returns the source path.
  Future<String> seedEntry(
    String key, {
    required int sourceBytes,
    required int wavBytes,
    DateTime? wavMtime,
    int lastUsedAt = 0,
  }) async {
    final source = await writeSource('$key.m4a', sourceBytes);
    final wav = await writeWav('$key.wav', wavBytes, mtime: wavMtime);
    final manifest = await File('${cacheDir.path}/manifest.json').exists()
        ? await readManifest()
        : <String, dynamic>{};
    manifest[source.path] = {
      'wavPath': wav.path,
      'sourceSize': sourceBytes,
      'lastUsedAt': lastUsedAt,
    };
    await writeManifest(manifest);
    return source.path;
  }

  test('tryGetCachedWav returns the wav for a valid entry', () async {
    final sourcePath = await seedEntry(
      'a',
      sourceBytes: 10,
      wavBytes: 100,
      lastUsedAt: 1000,
    );
    final cached = await AlacConverterService.tryGetCachedWav(sourcePath);
    expect(cached, '${cacheDir.path}/a.wav');
  });

  test('tryGetCachedWav refreshes lastUsedAt on hit', () async {
    final sourcePath = await seedEntry(
      'a',
      sourceBytes: 10,
      wavBytes: 100,
      lastUsedAt: 1000,
    );
    await AlacConverterService.tryGetCachedWav(sourcePath);
    final manifest = await readManifest();
    final refreshed = (manifest[sourcePath] as Map)['lastUsedAt'] as int;
    expect(refreshed, greaterThan(1000));
  });

  test('tryGetCachedWav rejects stale, missing, and unknown entries',
      () async {
    final stale = await seedEntry('stale', sourceBytes: 20, wavBytes: 200);
    await File(stale).writeAsBytes(List.filled(99, 0)); // size drift
    expect(await AlacConverterService.tryGetCachedWav(stale), isNull);

    final missingWav = await seedEntry(
      'missing',
      sourceBytes: 10,
      wavBytes: 100,
    );
    await File('${cacheDir.path}/missing.wav').delete();
    expect(await AlacConverterService.tryGetCachedWav(missingWav), isNull);

    expect(
      await AlacConverterService.tryGetCachedWav('${sourcesDir.path}/nope.m4a'),
      isNull,
    );
  });

  test('enforceCacheCap evicts least-recently-used entries first', () async {
    final old = await seedEntry(
      'old',
      sourceBytes: 10,
      wavBytes: 40,
      lastUsedAt: 1000,
    );
    final mid = await seedEntry(
      'mid',
      sourceBytes: 10,
      wavBytes: 40,
      lastUsedAt: 2000,
    );
    final latest = await seedEntry(
      'latest',
      sourceBytes: 10,
      wavBytes: 40,
      lastUsedAt: 3000,
    );

    await AlacConverterService.enforceCacheCap(100);

    expect(await File('${cacheDir.path}/old.wav').exists(), isFalse);
    expect(await File('${cacheDir.path}/mid.wav').exists(), isTrue);
    expect(await File('${cacheDir.path}/latest.wav').exists(), isTrue);
    final manifest = await readManifest();
    expect(manifest.containsKey(old), isFalse);
    expect(manifest.containsKey(mid), isTrue);
    expect(manifest.containsKey(latest), isTrue);
  });

  test('enforceCacheCap never evicts the protected path', () async {
    final old = await seedEntry(
      'old',
      sourceBytes: 10,
      wavBytes: 60,
      lastUsedAt: 1000,
    );
    await seedEntry(
      'mid',
      sourceBytes: 10,
      wavBytes: 60,
      lastUsedAt: 2000,
    );

    // 60 bytes fits, but protecting 'old' must evict 'mid' instead.
    await AlacConverterService.enforceCacheCap(
      60,
      protectPath: '${cacheDir.path}/old.wav',
    );

    expect(await File('${cacheDir.path}/old.wav').exists(), isTrue);
    expect(await File('${cacheDir.path}/mid.wav').exists(), isFalse);
    final manifest = await readManifest();
    expect(manifest.containsKey(old), isTrue);
  });

  test('enforceCacheCap treats <= 0 as unlimited', () async {
    await seedEntry('a', sourceBytes: 10, wavBytes: 500, lastUsedAt: 1000);
    await AlacConverterService.enforceCacheCap(0);
    await AlacConverterService.enforceCacheCap(-1);
    expect(await File('${cacheDir.path}/a.wav').exists(), isTrue);
  });

  test('enforceCacheCap removes dead manifest rows and orphaned files',
      () async {
    final dead = await seedEntry('dead', sourceBytes: 10, wavBytes: 100);
    await File('${cacheDir.path}/dead.wav').delete();
    final orphan = await writeWav('orphan.wav', 50);
    await seedEntry('live', sourceBytes: 10, wavBytes: 100);

    await AlacConverterService.enforceCacheCap(1000);

    final manifest = await readManifest();
    expect(manifest.containsKey(dead), isFalse);
    expect(await orphan.exists(), isFalse);
    expect(await File('${cacheDir.path}/live.wav').exists(), isTrue);
  });

  test('manifests without lastUsedAt are backfilled from file mtime',
      () async {
    final older = await seedEntry(
      'older',
      sourceBytes: 10,
      wavBytes: 40,
      wavMtime: base,
    );
    await seedEntry(
      'newer',
      sourceBytes: 10,
      wavBytes: 40,
      wavMtime: base.add(const Duration(hours: 1)),
    );

    await AlacConverterService.enforceCacheCap(60);

    // mtime order stands in for lastUsedAt: 'older' goes first.
    expect(await File('${cacheDir.path}/older.wav').exists(), isFalse);
    expect(await File('${cacheDir.path}/newer.wav').exists(), isTrue);
    final manifest = await readManifest();
    expect(manifest.containsKey(older), isFalse);
  });

  test('getCacheSize sums wav files and excludes the manifest', () async {
    await seedEntry('a', sourceBytes: 10, wavBytes: 100);
    await seedEntry('b', sourceBytes: 10, wavBytes: 50);
    expect(await AlacConverterService.getCacheSize(), 150);
  });

  test('clearCache empties the cache and resets the manifest', () async {
    final sourcePath = await seedEntry('a', sourceBytes: 10, wavBytes: 100);
    expect(await AlacConverterService.tryGetCachedWav(sourcePath), isNotNull);

    await AlacConverterService.clearCache();

    expect(await File('${cacheDir.path}/a.wav').exists(), isFalse);
    expect(await AlacConverterService.tryGetCachedWav(sourcePath), isNull);
    expect(await AlacConverterService.getCacheSize(), 0);
    final manifest = await readManifest();
    expect(manifest, isEmpty);
  });
}
