// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listenbrainz_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ListenBrainzSession _$ListenBrainzSessionFromJson(Map<String, dynamic> json) =>
    _ListenBrainzSession(
      token: json['token'] as String,
      username: json['username'] as String,
    );

Map<String, dynamic> _$ListenBrainzSessionToJson(
  _ListenBrainzSession instance,
) => <String, dynamic>{'token': instance.token, 'username': instance.username};

_ListenBrainzListenEntry _$ListenBrainzListenEntryFromJson(
  Map<String, dynamic> json,
) => _ListenBrainzListenEntry(
  artistName: json['artistName'] as String,
  trackName: json['trackName'] as String,
  listenedAt: (json['listenedAt'] as num).toInt(),
  releaseName: json['releaseName'] as String?,
  durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
);

Map<String, dynamic> _$ListenBrainzListenEntryToJson(
  _ListenBrainzListenEntry instance,
) => <String, dynamic>{
  'artistName': instance.artistName,
  'trackName': instance.trackName,
  'listenedAt': instance.listenedAt,
  'releaseName': instance.releaseName,
  'durationSeconds': instance.durationSeconds,
};
