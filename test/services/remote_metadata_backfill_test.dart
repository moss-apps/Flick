import 'dart:async';

import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/remote_source_service.dart';
import 'package:flick/src/rust/api/scanner.dart';
import 'package:flutter_test/flutter_test.dart';

SongEntity listing() => SongEntity()
  ..filePath = 'smb://7/album/song.flac'
  ..remoteId = 'album/song.flac'
  ..remoteServerId = 7
  ..sourceType = 'smb'
  ..title = 'song'
  ..artist = 'folder'
  ..fileSize = 100
  ..dateAdded = DateTime(2026);

void main() {
  const song = Song(
    id: '1',
    title: 'song',
    artist: 'artist',
    duration: Duration.zero,
    fileType: 'flac',
    sourceType: 'smb',
    filePath: 'smb://7/album/song.flac',
  );

  test(
    'backfills duration/format from cached original without changing remote path',
    () async {
      final gate = Completer<AudioFileMetadata?>();
      var reads = 0;
      var writes = 0;
      final service = RemoteSourceService.create(
        metadataReader: (path) {
          expect(path, '/cache/original.flac');
          reads++;
          return gate.future;
        },
        metadataWriter: (path, {sampleRate, bitDepth, durationMs}) async {
          expect(path, song.filePath);
          expect(durationMs, 123456);
          expect(sampleRate, 96000);
          expect(bitDepth, 24);
          writes++;
        },
      );
      final first = service.backfillAudioMetadata(song, '/cache/original.flac');
      await service.backfillAudioMetadata(song, '/cache/original.flac');
      gate.complete(
        AudioFileMetadata(
          path: '/cache/original.flac',
          format: 'flac',
          lastModified: 0,
          fileSize: BigInt.from(100),
          durationMs: BigInt.from(123456),
          sampleRate: 96000,
          bitDepth: 24,
        ),
      );
      await first;
      await service.backfillAudioMetadata(song, '/cache/original.flac');
      expect(reads, 1);
      expect(writes, 1);
    },
  );

  test(
    'failed metadata extraction is nonfatal and not repeated every play',
    () async {
      var reads = 0;
      final service = RemoteSourceService.create(
        metadataReader: (_) async {
          reads++;
          throw StateError('unsupported metadata');
        },
        metadataWriter: (_, {sampleRate, bitDepth, durationMs}) async =>
            fail('must not write'),
      );
      await service.backfillAudioMetadata(song, '/cache/file');
      await service.backfillAudioMetadata(song, '/cache/file');
      expect(reads, 1);
    },
  );

  test('partial format metadata does not prevent duration backfill', () {
    final entity = listing()..sampleRate = 44100;
    expect(
      SongRepository.fillMissingAudioMetadata(
        entity,
        sampleRate: 96000,
        bitDepth: 24,
        durationMs: 123456,
      ),
      isTrue,
    );
    expect(entity.sampleRate, 44100);
    expect(entity.bitDepth, 24);
    expect(entity.durationMs, 123456);
    expect(
      SongRepository.fillMissingAudioMetadata(
        entity,
        sampleRate: 0,
        bitDepth: 0,
        durationMs: -1,
      ),
      isFalse,
    );
  });

  test('SMB resync retains backfill, local edits, date and row identity', () {
    final existing = listing()
      ..id = 42
      ..title = 'My title'
      ..artist = 'My artist'
      ..album = 'My album'
      ..hasLocalEdits = true
      ..durationMs = 123456
      ..sampleRate = 96000
      ..bitDepth = 24
      ..trackNumber = 5
      ..dateAdded = DateTime(2020);
    final merged = SongRepository.mergeSmbListing(listing(), existing);
    expect(merged.id, 42);
    expect(merged.filePath, 'smb://7/album/song.flac');
    expect(merged.remoteId, 'album/song.flac');
    expect(merged.title, 'My title');
    expect(merged.artist, 'My artist');
    expect(merged.album, 'My album');
    expect(merged.trackNumber, 5);
    expect(merged.dateAdded, DateTime(2020));
    expect(merged.durationMs, 123456);
    expect(merged.sampleRate, 96000);
    expect(merged.bitDepth, 24);
  });

  test('changed file size clears stale audio properties on resync', () {
    final existing = listing()
      ..durationMs = 123456
      ..sampleRate = 96000
      ..bitDepth = 24;
    final merged = SongRepository.mergeSmbListing(
      listing()..fileSize = 200,
      existing,
    );
    expect(merged.durationMs, isNull);
    expect(merged.sampleRate, isNull);
    expect(merged.bitDepth, isNull);
  });
}
