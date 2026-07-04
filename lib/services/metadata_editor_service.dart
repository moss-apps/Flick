import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;

/// Outcome of a metadata write attempt.
enum MetadataWriteOutcome {
  /// Tags written to the file, read back, and confirmed to match the intent.
  verified,

  /// Tags reported written but the read-back could not confirm them. The DB
  /// was still updated to the intended values; a rescan will reconcile.
  unverified,

  /// Nothing was written.
  failed,
}

class MetadataWriteResult {
  final MetadataWriteOutcome outcome;
  final String? message;

  const MetadataWriteResult(this.outcome, {this.message});

  bool get saved => outcome != MetadataWriteOutcome.failed;
  bool get verified => outcome == MetadataWriteOutcome.verified;
}

class MetadataEditorService {
  MetadataEditorService._();
  static final MetadataEditorService instance = MetadataEditorService._();

  static const _channel = MethodChannel('com.mossapps.flick/storage');

  Future<rust_metadata.TagReadResult?> readTags(String filePath) async {
    try {
      return await rust_metadata.readTags(path: filePath);
    } catch (_) {
      return null;
    }
  }

  /// Persists [fields] to the actual audio file and verifies them.
  ///
  /// Android Scoped Storage blocks direct writes to most user files, so this
  /// tries the fast in-place write first and falls back to the SAF pipeline
  /// (write tags to an app-cache temp copy, then copy the bytes back through
  /// the folder's document tree grant) when that fails. Either way, the result
  /// is confirmed by re-reading the tags before the local DB is touched.
  Future<MetadataWriteResult> writeTags(
    Song song,
    rust_metadata.TagEditFields fields,
  ) async {
    if (song.filePath == null) {
      return const MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: 'This song has no file path and cannot be edited.',
      );
    }
    if (song.startOffsetMs != null) {
      return const MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: 'CUE sheet tracks cannot be edited.',
      );
    }
    if (song.isExternal) {
      return const MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: 'External songs cannot be edited.',
      );
    }

    final path = song.filePath!;

    try {
      // Fast path: direct in-place write. Works for app-owned files and any
      // location the OS lets us write to directly.
      final direct = await rust_metadata.writeTags(path: path, fields: fields);
      if (direct.success) {
        return await _verifyAndPersist(path, fields);
      }

      // Direct write failed (typically Scoped Storage EACCES). Try the SAF
      // copy-back pipeline if we have a folder tree grant to write through.
      final safResult = await _writeViaSaf(song, path, fields);
      if (safResult != null) return safResult;

      // No SAF route available — surface the original failure.
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: direct.error ?? 'Failed to write tags to the file.',
      );
    } catch (e) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: 'Failed to save metadata: $e',
      );
    }
  }

  /// Re-reads the file's tags, confirms they match [fields], then mirrors the
  /// result into the local DB. The read-back is the integrity guard: it proves
  /// the on-disk file actually holds what we asked for.
  Future<MetadataWriteResult> _verifyAndPersist(
    String path,
    rust_metadata.TagEditFields fields,
  ) async {
    final readBack = await readTags(path);
    final verified = _verifyReadback(readBack, fields);

    await SongRepository().updateSongMetadata(
      path,
      title: fields.title,
      artist: fields.artist,
      album: fields.album,
      albumArtist: fields.albumArtist,
      trackNumber: fields.trackNumber,
      discNumber: fields.discNumber,
      year: fields.year,
      genre: fields.genre,
    );

    return verified
        ? const MetadataWriteResult(MetadataWriteOutcome.verified)
        : const MetadataWriteResult(
            MetadataWriteOutcome.unverified,
            message: 'Tags were written but could not be confirmed by '
                're-reading the file. A library rescan will reconcile '
                'any difference.',
          );
  }

  /// SAF copy-back pipeline. Returns `null` when SAF isn't applicable (no
  /// folder tree grant, or a content:// URI the Rust layer can't open); a
  /// non-null result (which may be a failure) when SAF was attempted.
  Future<MetadataWriteResult?> _writeViaSaf(
    Song song,
    String path,
    rust_metadata.TagEditFields fields,
  ) async {
    final treeUri = song.folderUri;
    if (treeUri == null || treeUri.isEmpty) return null;
    // The Rust tagger opens the file by path; it can't open a content:// URI.
    if (path.startsWith('content://')) return null;

    final Directory cache;
    try {
      cache = await getTemporaryDirectory();
    } catch (_) {
      return null;
    }
    final tempDir = Directory('${cache.path}/metadata_edits');
    await tempDir.create(recursive: true);

    // Stage the edited file in app cache (always writable).
    final temp = await rust_metadata.writeTagsToTemp(
      path: path,
      fields: fields,
      tempDir: tempDir.path,
    );
    if (!temp.success || temp.tempPath == null) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message:
            'Could not prepare the edited file: ${temp.error ?? "unknown error"}',
      );
    }

    // Copy the staged bytes back over the original via the SAF grant.
    final copied = await _writeFileBytesViaSaf(treeUri, path, temp.tempPath!);

    // Clean up the temp copy regardless of outcome.
    try {
      await File(temp.tempPath!).delete();
    } catch (_) {}

    if (!copied) {
      return const MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: 'Android blocked writing to this file. Remove and re-add the '
            'folder in Settings to grant edit access, then try again.',
      );
    }

    return _verifyAndPersist(path, fields);
  }

  Future<bool> _writeFileBytesViaSaf(
    String folderTreeUri,
    String filePath,
    String tempFilePath,
  ) async {
    try {
      final res = await _channel.invokeMethod<bool>('writeFileBytesViaSaf', {
        'folderTreeUri': folderTreeUri,
        'filePath': filePath,
        'tempFilePath': tempFilePath,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Compares the freshly read tags against the fields we intended to set.
  /// Only fields with a concrete intent (non-null) are checked; null fields
  /// mean "leave untouched" and are skipped. String compares are normalized so
  /// cosmetic differences (case/whitespace) don't produce false mismatches.
  bool _verifyReadback(
    rust_metadata.TagReadResult? read,
    rust_metadata.TagEditFields want,
  ) {
    if (read == null) return false;
    return _strMatches(want.title, read.title) &&
        _strMatches(want.artist, read.artist) &&
        _strMatches(want.album, read.album) &&
        _strMatches(want.albumArtist, read.albumArtist) &&
        _strMatches(want.genre, read.genre) &&
        _numMatches(want.year, read.year) &&
        _numMatches(want.trackNumber, read.trackNumber) &&
        _numMatches(want.discNumber, read.discNumber);
  }

  bool _strMatches(String? want, String? got) {
    if (want == null) return true;
    return want.trim().toLowerCase() == (got ?? '').trim().toLowerCase();
  }

  bool _numMatches(int? want, int? got) {
    if (want == null) return true;
    return want == got;
  }
}
