import 'package:flutter/foundation.dart';

import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/apple_music/album_identification_service.dart';
import 'package:flick/services/apple_music/apple_music_settings.dart';

/// Outcome of one auto-enrichment pass.
class AutoEnrichSummary {
  const AutoEnrichSummary({
    this.groupsConsidered = 0,
    this.groupsApplied = 0,
    this.groupsQueued = 0,
    this.songsUpdated = 0,
  });

  final int groupsConsidered;
  final int groupsApplied;
  final int groupsQueued;
  final int songsUpdated;
}

/// Identifies untagged album folders against Apple Music after a scan.
/// Only exact artist + album matches with track-length agreement are applied
/// automatically; everything else waits in the "Fix missing metadata" screen.
class AutoMetadataEnricher {
  AutoMetadataEnricher._({
    AlbumIdentificationService? identification,
    AppleMusicSettings? settings,
  }) : _identification =
           identification ?? AlbumIdentificationService.instance,
       _settings = settings ?? AppleMusicSettings();

  static final AutoMetadataEnricher instance = AutoMetadataEnricher._();

  @visibleForTesting
  static AutoMetadataEnricher create({
    AlbumIdentificationService? identification,
    AppleMusicSettings? settings,
  }) => AutoMetadataEnricher._(
    identification: identification,
    settings: settings,
  );

  final AlbumIdentificationService _identification;
  final AppleMusicSettings _settings;

  /// Keeps a single scan pass from hammering the iTunes endpoints; remaining
  /// folders are picked up by the next scan or the review screen.
  static const int _maxGroupsPerRun = 12;
  static const Duration _betweenGroupsDelay = Duration(milliseconds: 800);

  Future<AutoEnrichSummary> enrichMissing(List<Song> songs) async {
    if (!await _settings.autoEnrichEnabled()) {
      return const AutoEnrichSummary();
    }
    final groups = groupMissingByFolder(songs);
    if (groups.isEmpty) return const AutoEnrichSummary();

    final groupList = groups.values.toList();
    var considered = 0;
    var applied = 0;
    var queued = 0;
    var updated = 0;

    for (var index = 0; index < groupList.length; index++) {
      if (considered >= _maxGroupsPerRun) break;
      final group = groupList[index];
      considered++;
      final seeds = AlbumIdentificationService.deriveFolderSeeds(group);
      if (seeds.artist.isEmpty || seeds.album.isEmpty) {
        queued++;
        continue;
      }
      final candidates = await _identification.findCandidates(
        songs: group,
        artist: seeds.artist,
        album: seeds.album,
      );
      final best = candidates.isEmpty ? null : candidates.first;
      if (best == null ||
          !AlbumIdentificationService.matchesSeed(
            best,
            artist: seeds.artist,
            album: seeds.album,
          )) {
        queued++;
      } else {
        try {
          final result = await _identification.applyCandidate(best);
          applied++;
          updated += result.updatedSongs;
        } catch (error) {
          devLog('AutoMetadataEnricher: apply failed: $error');
          queued++;
        }
      }
      if (index < groupList.length - 1) {
        await Future<void>.delayed(_betweenGroupsDelay);
      }
    }

    return AutoEnrichSummary(
      groupsConsidered: considered,
      groupsApplied: applied,
      groupsQueued: queued,
      songsUpdated: updated,
    );
  }

  /// Groups songs by parent folder, keeping only folders where at least one
  /// song still has an unknown artist or album.
  static Map<String, List<Song>> groupMissingByFolder(List<Song> songs) {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      final path = song.filePath;
      if (path == null || path.isEmpty) continue;
      final separator = path.lastIndexOf('/');
      if (separator <= 0) continue;
      final folder = path.substring(0, separator);
      (groups[folder] ??= []).add(song);
    }
    groups.removeWhere(
      (_, group) => !group.any(
        (song) =>
            AlbumIdentificationService.isUnknownName(song.artist) ||
            AlbumIdentificationService.isUnknownName(song.album),
      ),
    );
    return groups;
  }
}
