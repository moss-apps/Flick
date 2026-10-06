import 'package:flutter/material.dart';

import 'package:flick/l10n/l10n.dart';

/// Layout presets offered by the share sheet.
///
/// The display names live in [label] rather than in a `label` field on purpose:
/// enum values are implicitly `const`, so they can only hold compile-time
/// constants and a localized string is resolved at runtime. Storing the name as
/// a field would force the whole enum to stay English.
enum ShareTemplate {
  lyric(icon: Icons.music_note_rounded),
  solidColor(icon: Icons.palette_rounded),
  minimal(icon: Icons.crop_square_rounded),
  albumArt(icon: Icons.album_rounded);

  final IconData icon;

  const ShareTemplate({required this.icon});

  /// Localized display name.
  String label(AppLocalizations l10n) => switch (this) {
        ShareTemplate.lyric => l10n.lyric,
        ShareTemplate.solidColor => l10n.color,
        ShareTemplate.minimal => l10n.minimal,
        ShareTemplate.albumArt => l10n.album,
      };
}
