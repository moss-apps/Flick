import 'dart:ui';

import 'playlist_cover_edit.dart';

/// What the artwork editor returns after the user applies an edit.
///
/// The rendered JPEG lives in the temporary directory; the caller owns it and
/// should copy or delete it. [edit] and [crop] are kept so reopening the editor
/// can start from the same framing instead of snapping back to centre.
class ArtworkEditResult {
  const ArtworkEditResult({
    required this.path,
    required this.edit,
    required this.crop,
  });

  final String path;
  final PlaylistCoverEdit edit;

  /// Crop in the oriented image's coordinate space, matching
  /// `calculateArtworkCrop`.
  final Rect crop;
}
