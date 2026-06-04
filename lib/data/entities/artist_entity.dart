import 'package:isar_community/isar.dart';

part 'artist_entity.g.dart';

/// Database entity for caching per-artist metadata.
@collection
class ArtistEntity {
  Id id = Isar.autoIncrement;

  /// Canonical artist name. Case-insensitive unique.
  @Index(unique: true, caseSensitive: false)
  late String name;

  /// Path to a local image file used as the artist's picture.
  String? artPath;
}
