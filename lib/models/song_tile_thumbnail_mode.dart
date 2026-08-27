enum SongTileThumbnailMode { artwork, trackNumber, trackNumberOnArt }

extension SongTileThumbnailModeX on SongTileThumbnailMode {
  String get storageValue {
    switch (this) {
      case SongTileThumbnailMode.artwork:
        return 'artwork';
      case SongTileThumbnailMode.trackNumber:
        return 'trackNumber';
      case SongTileThumbnailMode.trackNumberOnArt:
        return 'trackNumberOnArt';
    }
  }

  String get label {
    switch (this) {
      case SongTileThumbnailMode.artwork:
        return 'Album Art';
      case SongTileThumbnailMode.trackNumber:
        return 'Track Number';
      case SongTileThumbnailMode.trackNumberOnArt:
        return 'Number on Art';
    }
  }

  String get description {
    switch (this) {
      case SongTileThumbnailMode.artwork:
        return 'Show album artwork.';
      case SongTileThumbnailMode.trackNumber:
        return 'Show the track number.';
      case SongTileThumbnailMode.trackNumberOnArt:
        return 'Show the number over blurred art.';
    }
  }

  static SongTileThumbnailMode fromStorageValue(String? value) {
    switch (value) {
      case 'trackNumber':
        return SongTileThumbnailMode.trackNumber;
      case 'trackNumberOnArt':
        return SongTileThumbnailMode.trackNumberOnArt;
      case 'artwork':
      default:
        return SongTileThumbnailMode.artwork;
    }
  }
}
