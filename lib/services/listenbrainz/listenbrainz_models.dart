import 'package:freezed_annotation/freezed_annotation.dart';

part 'listenbrainz_models.freezed.dart';
part 'listenbrainz_models.g.dart';

/// Represents a ListenBrainz session after token validation.
@freezed
abstract class ListenBrainzSession with _$ListenBrainzSession {
  const factory ListenBrainzSession({
    required String token,
    required String username,
  }) = _ListenBrainzSession;

  factory ListenBrainzSession.fromJson(Map<String, dynamic> json) =>
      _$ListenBrainzSessionFromJson(json);
}

/// A single track ready to be submitted to ListenBrainz.
/// Stored flat for queue persistence; the service maps it to LB's nested
/// JSON shape when submitting.
@freezed
abstract class ListenBrainzListenEntry with _$ListenBrainzListenEntry {
  const factory ListenBrainzListenEntry({
    required String artistName,
    required String trackName,
    required int listenedAt,
    String? releaseName,
    int? durationSeconds,
  }) = _ListenBrainzListenEntry;

  factory ListenBrainzListenEntry.fromJson(Map<String, dynamic> json) =>
      _$ListenBrainzListenEntryFromJson(json);
}
