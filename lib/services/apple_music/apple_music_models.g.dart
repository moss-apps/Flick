// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_music_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppleMusicArtist _$AppleMusicArtistFromJson(Map<String, dynamic> json) =>
    _AppleMusicArtist(
      artistId: json['artistId'] as String,
      name: json['name'] as String,
      genre: json['genre'] as String?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$AppleMusicArtistToJson(_AppleMusicArtist instance) =>
    <String, dynamic>{
      'artistId': instance.artistId,
      'name': instance.name,
      'genre': instance.genre,
      'url': instance.url,
    };

_AppleMusicSimilarArtist _$AppleMusicSimilarArtistFromJson(
  Map<String, dynamic> json,
) => _AppleMusicSimilarArtist(name: json['name'] as String);

Map<String, dynamic> _$AppleMusicSimilarArtistToJson(
  _AppleMusicSimilarArtist instance,
) => <String, dynamic>{'name': instance.name};

_AppleMusicArtistInfo _$AppleMusicArtistInfoFromJson(
  Map<String, dynamic> json,
) => _AppleMusicArtistInfo(
  artistId: json['artistId'] as String,
  name: json['name'] as String,
  storefront: json['storefront'] as String,
  url: json['url'] as String,
  biography: json['biography'] as String?,
  imageUrl: json['imageUrl'] as String?,
  similarArtists:
      (json['similarArtists'] as List<dynamic>?)
          ?.map(
            (e) => AppleMusicSimilarArtist.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <AppleMusicSimilarArtist>[],
);

Map<String, dynamic> _$AppleMusicArtistInfoToJson(
  _AppleMusicArtistInfo instance,
) => <String, dynamic>{
  'artistId': instance.artistId,
  'name': instance.name,
  'storefront': instance.storefront,
  'url': instance.url,
  'biography': instance.biography,
  'imageUrl': instance.imageUrl,
  'similarArtists': instance.similarArtists,
};

_AppleMusicTopSong _$AppleMusicTopSongFromJson(Map<String, dynamic> json) =>
    _AppleMusicTopSong(
      trackName: json['trackName'] as String,
      artistName: json['artistName'] as String,
      collectionName: json['collectionName'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AppleMusicTopSongToJson(_AppleMusicTopSong instance) =>
    <String, dynamic>{
      'trackName': instance.trackName,
      'artistName': instance.artistName,
      'collectionName': instance.collectionName,
      'durationMs': instance.durationMs,
    };

_AppleMusicAlbumMatch _$AppleMusicAlbumMatchFromJson(
  Map<String, dynamic> json,
) => _AppleMusicAlbumMatch(
  collectionId: json['collectionId'] as String,
  name: json['name'] as String,
  artistName: json['artistName'] as String,
  url: json['url'] as String,
  artworkUrl: json['artworkUrl'] as String?,
  releaseDate: json['releaseDate'] as String?,
  genre: json['genre'] as String?,
  trackCount: (json['trackCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$AppleMusicAlbumMatchToJson(
  _AppleMusicAlbumMatch instance,
) => <String, dynamic>{
  'collectionId': instance.collectionId,
  'name': instance.name,
  'artistName': instance.artistName,
  'url': instance.url,
  'artworkUrl': instance.artworkUrl,
  'releaseDate': instance.releaseDate,
  'genre': instance.genre,
  'trackCount': instance.trackCount,
};

_AppleMusicAlbumInfo _$AppleMusicAlbumInfoFromJson(Map<String, dynamic> json) =>
    _AppleMusicAlbumInfo(
      collectionId: json['collectionId'] as String,
      url: json['url'] as String,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$AppleMusicAlbumInfoToJson(
  _AppleMusicAlbumInfo instance,
) => <String, dynamic>{
  'collectionId': instance.collectionId,
  'url': instance.url,
  'notes': instance.notes,
};

_AppleMusicTrack _$AppleMusicTrackFromJson(Map<String, dynamic> json) =>
    _AppleMusicTrack(
      trackName: json['trackName'] as String,
      trackId: json['trackId'] as String?,
      artistName: json['artistName'] as String?,
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      url: json['url'] as String?,
    );

Map<String, dynamic> _$AppleMusicTrackToJson(_AppleMusicTrack instance) =>
    <String, dynamic>{
      'trackName': instance.trackName,
      'trackId': instance.trackId,
      'artistName': instance.artistName,
      'trackNumber': instance.trackNumber,
      'discNumber': instance.discNumber,
      'durationMs': instance.durationMs,
      'url': instance.url,
    };
