import 'package:freezed_annotation/freezed_annotation.dart';

part 'apple_music_models.freezed.dart';
part 'apple_music_models.g.dart';

/// An artist resolved through the iTunes Search API.
@freezed
abstract class AppleMusicArtist with _$AppleMusicArtist {
  const factory AppleMusicArtist({
    required String artistId,
    required String name,
    String? genre,
    String? url,
  }) = _AppleMusicArtist;

  factory AppleMusicArtist.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicArtistFromJson(json);
}

/// A name scraped from an artist page's "Similar Artists" section.
@freezed
abstract class AppleMusicSimilarArtist with _$AppleMusicSimilarArtist {
  const factory AppleMusicSimilarArtist({required String name}) =
      _AppleMusicSimilarArtist;

  factory AppleMusicSimilarArtist.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicSimilarArtistFromJson(json);
}

/// Biography, image and similar artists scraped from an Apple Music artist
/// page. All fields are optional: Apple does not fill every page.
@freezed
abstract class AppleMusicArtistInfo with _$AppleMusicArtistInfo {
  const factory AppleMusicArtistInfo({
    required String artistId,
    required String name,
    required String storefront,
    required String url,
    String? biography,
    String? imageUrl,
    @Default(<AppleMusicSimilarArtist>[])
    List<AppleMusicSimilarArtist> similarArtists,
  }) = _AppleMusicArtistInfo;

  factory AppleMusicArtistInfo.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicArtistInfoFromJson(json);
}

/// A popular song from the iTunes lookup API.
@freezed
abstract class AppleMusicTopSong with _$AppleMusicTopSong {
  const factory AppleMusicTopSong({
    required String trackName,
    required String artistName,
    String? collectionName,
    int? durationMs,
  }) = _AppleMusicTopSong;

  factory AppleMusicTopSong.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicTopSongFromJson(json);
}

/// An album matched in an artist's iTunes discography.
@freezed
abstract class AppleMusicAlbumMatch with _$AppleMusicAlbumMatch {
  const factory AppleMusicAlbumMatch({
    required String collectionId,
    required String name,
    required String artistName,
    required String url,
    String? artworkUrl,
    String? releaseDate,
    String? genre,
    int? trackCount,
  }) = _AppleMusicAlbumMatch;

  factory AppleMusicAlbumMatch.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicAlbumMatchFromJson(json);
}

/// Editorial album notes (the "Apple Music Review") plus canonical URL.
@freezed
abstract class AppleMusicAlbumInfo with _$AppleMusicAlbumInfo {
  const factory AppleMusicAlbumInfo({
    required String collectionId,
    required String url,
    String? notes,
  }) = _AppleMusicAlbumInfo;

  factory AppleMusicAlbumInfo.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicAlbumInfoFromJson(json);
}

/// A track from an album, used to match local files by duration and order.
@freezed
abstract class AppleMusicTrack with _$AppleMusicTrack {
  const factory AppleMusicTrack({
    required String trackName,
    String? trackId,
    String? artistName,
    int? trackNumber,
    int? discNumber,
    int? durationMs,
    String? url,
  }) = _AppleMusicTrack;

  factory AppleMusicTrack.fromJson(Map<String, dynamic> json) =>
      _$AppleMusicTrackFromJson(json);
}
