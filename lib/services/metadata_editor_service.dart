import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:flick/l10n/l10n.dart';

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

typedef MetadataTagReader =
    Future<rust_metadata.TagReadResult?> Function(String path);
typedef MetadataTagWriter =
    Future<rust_metadata.TagWriteResult> Function(
      String path,
      rust_metadata.TagEditFields fields,
    );
typedef MetadataTempTagWriter =
    Future<rust_metadata.TagWriteResult> Function(
      String path,
      rust_metadata.TagEditFields fields,
      String tempDir,
    );
typedef MetadataPersist =
    Future<void> Function(String path, rust_metadata.TagEditFields fields);
typedef MetadataTempDirectory = Future<Directory> Function();

class _StagedContentUri {
  const _StagedContentUri.ok(this.path) : reason = null;
  const _StagedContentUri.failed(this.reason) : path = null;

  final String? path;
  final String? reason;
}

class _ContentUriWrite {
  const _ContentUriWrite(this.success, this.reason);

  final bool success;
  final String? reason;
}

class MetadataEditorService {
  MetadataEditorService._({
    MetadataTagReader? readTagFile,
    MetadataTagWriter? writeTagFile,
    MetadataTempTagWriter? writeTagFileToTemp,
    MetadataPersist? persistMetadata,
    MetadataTempDirectory? temporaryDirectory,
  }) : _readTagFile = readTagFile ?? _readTagsFromRust,
       _writeTagFile = writeTagFile ?? _writeTagsWithRust,
       _writeTagFileToTemp = writeTagFileToTemp ?? _writeTagsToTempWithRust,
       _persistMetadata = persistMetadata ?? _persistToRepository,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static final MetadataEditorService instance = MetadataEditorService._();

  /// Test seam: inject the Rust tagger, DB write, and temp directory so the
  /// content:// orchestration can be exercised in `flutter test`.
  @visibleForTesting
  factory MetadataEditorService.forTesting({
    MetadataTagReader? readTagFile,
    MetadataTagWriter? writeTagFile,
    MetadataTempTagWriter? writeTagFileToTemp,
    MetadataPersist? persistMetadata,
    MetadataTempDirectory? temporaryDirectory,
  }) {
    return MetadataEditorService._(
      readTagFile: readTagFile,
      writeTagFile: writeTagFile,
      writeTagFileToTemp: writeTagFileToTemp,
      persistMetadata: persistMetadata,
      temporaryDirectory: temporaryDirectory,
    );
  }

  final MetadataTagReader _readTagFile;
  final MetadataTagWriter _writeTagFile;
  final MetadataTempTagWriter _writeTagFileToTemp;
  final MetadataPersist _persistMetadata;
  final MetadataTempDirectory _temporaryDirectory;

  static const _channel = MethodChannel('com.mossapps.flick/storage');

  static Future<rust_metadata.TagReadResult?> _readTagsFromRust(String path) =>
      rust_metadata.readTags(path: path);

  static Future<rust_metadata.TagWriteResult> _writeTagsWithRust(
    String path,
    rust_metadata.TagEditFields fields,
  ) => rust_metadata.writeTags(path: path, fields: fields);

  static Future<rust_metadata.TagWriteResult> _writeTagsToTempWithRust(
    String path,
    rust_metadata.TagEditFields fields,
    String tempDir,
  ) => rust_metadata.writeTagsToTemp(
    path: path,
    fields: fields,
    tempDir: tempDir,
  );

  static Future<void> _persistToRepository(
    String path,
    rust_metadata.TagEditFields fields,
  ) {
    return SongRepository().updateSongMetadata(
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
  }

  /// Reads tags from a local path or an Android `content://` document.
  ///
  /// The Rust tagger can only open filesystem paths, so content URIs are first
  /// copied to a private cache file and that copy is removed afterwards.
  Future<rust_metadata.TagReadResult?> readTags(String filePath) async {
    final path = _plainPath(filePath);
    if (path == null) {
      final staged = await _stageContentUri(filePath);
      final stagedPath = staged.path;
      if (stagedPath == null) return null;
      try {
        return await _readTagFile(stagedPath);
      } catch (_) {
        return null;
      } finally {
        await _deleteQuietly(stagedPath);
      }
    }

    try {
      return await _readTagFile(path);
    } catch (_) {
      return null;
    }
  }

  /// Persists [fields] to the actual audio file and verifies them.
  ///
  /// Android Scoped Storage blocks direct writes to most user files. Plain
  /// filesystem paths try the fast in-place write first and fall back to the
  /// SAF pipeline (write tags to an app-cache temp copy, then copy the bytes
  /// back through the folder's document tree grant). Content URIs are staged,
  /// edited in cache, then streamed back to the original document. Either way,
  /// the result is confirmed by re-reading the tags before the local DB is
  /// touched.
  Future<MetadataWriteResult> writeTags(
    Song song,
    rust_metadata.TagEditFields fields,
  ) async {
    if (song.filePath == null) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: l10n.englishForFilipino.thisSongHasNoFilePath,
      );
    }
    if (song.startOffsetMs != null) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: l10n.englishForFilipino.cueSheetTracksCannotBeEdited,
      );
    }
    if (song.isExternal) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: l10n.englishForFilipino.externalSongsCannotBeEdited,
      );
    }

    final source = song.filePath!;
    final path = _plainPath(source);

    // SAF-scanned songs keep a content:// document URI as their filePath. The
    // Rust tagger cannot open that URI, so route it through Android staging.
    if (path == null) {
      return _writeViaContentUri(source, fields);
    }

    final rust_metadata.TagWriteResult direct;
    try {
      // Fast path: direct in-place write. Works for app-owned files and any
      // location the OS lets us write to directly.
      direct = await _writeTagFile(path, fields);
    } catch (e) {
      // A thrown direct write must not skip the SAF fallback.
      final safResult = await _tryWriteViaSaf(song, source, path, fields);
      if (safResult != null) return safResult;

      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: _unexpectedWriteFailure(e),
      );
    }

    if (direct.success) {
      try {
        return await _verifyAndPersist(source, fields);
      } catch (e) {
        return MetadataWriteResult(
          MetadataWriteOutcome.failed,
          message: _unexpectedWriteFailure(e),
        );
      }
    }

    // Direct write failed (typically Scoped Storage EACCES). Try the SAF
    // copy-back pipeline if we have a folder tree grant to write through.
    final safResult = await _tryWriteViaSaf(song, source, path, fields);
    if (safResult != null) return safResult;

    // No SAF route available — surface a message that tells the user what
    // to do instead of the raw "os error 2" from the tagger.
    return MetadataWriteResult(
      MetadataWriteOutcome.failed,
      message: _writeFailureMessage(direct.error),
    );
  }

  /// Stages the document, edits the cache copy with Rust, streams it back to
  /// the original URI, then verifies by re-staging the original.
  Future<MetadataWriteResult> _writeViaContentUri(
    String uri,
    rust_metadata.TagEditFields fields,
  ) async {
    final staging = await _stageContentUri(uri);
    final stagedPath = staging.path;
    if (stagedPath == null) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: _stageFailureMessage(staging.reason),
      );
    }

    try {
      final edited = await _writeTagFile(stagedPath, fields);
      if (!edited.success) {
        return MetadataWriteResult(
          MetadataWriteOutcome.failed,
          message: l10n.englishForFilipino.couldNotPrepareTheEditedFile(
            edited.error ?? l10n.englishForFilipino.unknown,
          ),
        );
      }

      final written = await _writeBytesToContentUri(uri, stagedPath);
      if (!written.success) {
        return MetadataWriteResult(
          MetadataWriteOutcome.failed,
          message: _contentWriteFailureMessage(written.reason),
        );
      }

      return await _verifyAndPersist(uri, fields);
    } catch (e) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: _unexpectedWriteFailure(e),
      );
    } finally {
      await _deleteQuietly(stagedPath);
    }
  }

  /// Re-reads the file's tags, confirms they match [fields], then mirrors the
  /// result into the local DB. The read-back is the integrity guard: it proves
  /// the on-disk file actually holds what we asked for.
  Future<MetadataWriteResult> _verifyAndPersist(
    String source,
    rust_metadata.TagEditFields fields,
  ) async {
    final readBack = await readTags(source);
    final verified = _verifyReadback(readBack, fields);

    await _persistMetadata(source, fields);

    return verified
        ? const MetadataWriteResult(MetadataWriteOutcome.verified)
        : MetadataWriteResult(
            MetadataWriteOutcome.unverified,
            message: l10n.englishForFilipino.tagsWereWrittenButCouldNot,
          );
  }

  Future<MetadataWriteResult?> _tryWriteViaSaf(
    Song song,
    String source,
    String path,
    rust_metadata.TagEditFields fields,
  ) async {
    try {
      return await _writeViaSaf(song, source, path, fields);
    } catch (e) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: _unexpectedWriteFailure(e),
      );
    }
  }

  /// SAF copy-back pipeline. Returns `null` when SAF isn't applicable (no
  /// folder tree grant); a non-null result (which may be a failure) when SAF
  /// was attempted.
  Future<MetadataWriteResult?> _writeViaSaf(
    Song song,
    String source,
    String path,
    rust_metadata.TagEditFields fields,
  ) async {
    final treeUri = song.folderUri;
    if (treeUri == null || treeUri.isEmpty) return null;
    // Defensive: content URIs are handled by _writeViaContentUri.
    if (path.startsWith('content://')) return null;

    final Directory cache;
    try {
      cache = await _temporaryDirectory();
    } catch (_) {
      return null;
    }
    final tempDir = Directory('${cache.path}/metadata_edits');
    await tempDir.create(recursive: true);

    // Stage the edited file in app cache (always writable).
    final temp = await _writeTagFileToTemp(path, fields, tempDir.path);
    if (!temp.success || temp.tempPath == null) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: l10n.englishForFilipino.couldNotPrepareTheEditedFile(
          temp.error ?? l10n.englishForFilipino.unknown,
        ),
      );
    }

    // Copy the staged bytes back over the original via the SAF grant.
    final copied = await _writeFileBytesViaSaf(treeUri, path, temp.tempPath!);

    // Clean up the temp copy regardless of outcome.
    try {
      await File(temp.tempPath!).delete();
    } catch (_) {}

    if (!copied) {
      return MetadataWriteResult(
        MetadataWriteOutcome.failed,
        message: l10n.englishForFilipino.androidBlockedWritingToThisFile,
      );
    }

    return _verifyAndPersist(source, fields);
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

  Future<_StagedContentUri> _stageContentUri(String uri) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'stageContentUriForEdit',
        {'uri': uri, 'extensionHint': _extensionOf(uri)},
      );
      final path = res?['path'];
      if (path is String && path.isNotEmpty) {
        return _StagedContentUri.ok(path);
      }
      final reason = res?['reason'];
      return _StagedContentUri.failed(reason is String ? reason : 'failed');
    } catch (_) {
      return const _StagedContentUri.failed('failed');
    }
  }

  Future<_ContentUriWrite> _writeBytesToContentUri(
    String uri,
    String tempFilePath,
  ) async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'writeBytesToContentUri',
        {'uri': uri, 'tempFilePath': tempFilePath},
      );
      final success = res?['success'] == true;
      final reason = res?['reason'];
      return _ContentUriWrite(success, reason is String ? reason : null);
    } catch (_) {
      return const _ContentUriWrite(false, 'failed');
    }
  }

  /// Maps a `file://` URI to a filesystem path, passes plain paths through,
  /// and returns null for `content://` documents (which Rust cannot open).
  String? _plainPath(String source) {
    if (source.startsWith('content://')) return null;
    if (source.startsWith('file://')) {
      try {
        return Uri.parse(source).toFilePath();
      } catch (_) {
        return source;
      }
    }
    return source;
  }

  /// Best-effort extension hint for the staged cache file. Android resolves
  /// the provider's display name when this is null (e.g. MediaStore URIs).
  String? _extensionOf(String source) {
    final path = Uri.tryParse(source)?.path ?? source;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    final extension = path.substring(dot + 1).toLowerCase();
    if (extension.length > 5 || extension.contains('/')) return null;
    return extension;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  String _stageFailureMessage(String? reason) {
    if (reason == 'no_access') {
      return l10n.englishForFilipino.flickNoLongerHasPermissionToEditThisFile;
    }
    return l10n.englishForFilipino.fileIsNoLongerAvailable;
  }

  String _contentWriteFailureMessage(String? reason) {
    if (reason == 'no_access') {
      return l10n.englishForFilipino.flickNoLongerHasPermissionToEditThisFile;
    }
    if (reason == 'not_found') {
      return l10n.englishForFilipino.fileIsNoLongerAvailable;
    }
    return l10n.englishForFilipino.androidBlockedWritingToThisFile;
  }

  String _writeFailureMessage(String? error) {
    if (_isNoSuchFile(error)) {
      return l10n.englishForFilipino.fileIsNoLongerAvailable;
    }
    if (_isPermissionDenied(error)) {
      return l10n.englishForFilipino.flickNoLongerHasPermissionToEditThisFile;
    }
    return error ?? l10n.englishForFilipino.failedToWriteTagsToTheFile;
  }

  String _unexpectedWriteFailure(Object error) {
    final text = error.toString();
    if (_isNoSuchFile(text)) {
      return l10n.englishForFilipino.fileIsNoLongerAvailable;
    }
    if (_isPermissionDenied(text)) {
      return l10n.englishForFilipino.flickNoLongerHasPermissionToEditThisFile;
    }
    return l10n.englishForFilipino.failedToSaveMetadata(error);
  }

  bool _isNoSuchFile(String? error) {
    final text = error?.toLowerCase() ?? '';
    return text.contains('os error 2') ||
        text.contains('no such file or directory') ||
        text.contains('enoent');
  }

  bool _isPermissionDenied(String? error) {
    final text = error?.toLowerCase() ?? '';
    return text.contains('os error 13') ||
        text.contains('permission denied') ||
        text.contains('operation not permitted') ||
        text.contains('eacces');
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
