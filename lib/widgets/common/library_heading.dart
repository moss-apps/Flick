import 'package:flutter/material.dart';

import 'package:flick/l10n/l10n.dart';
import 'package:flick/widgets/common/baybayin_text.dart';

enum LibrarySection { songs, artists, albums, playlists }

class LibraryHeading extends StatelessWidget {
  const LibraryHeading({
    super.key,
    required this.section,
    this.style,
    this.defaultLabel,
  });

  final LibrarySection section;
  final TextStyle? style;
  final String? defaultLabel;

  @override
  Widget build(BuildContext context) => BaybayinText(
    label: switch (section) {
      LibrarySection.songs => BaybayinLabel.songs,
      LibrarySection.artists => BaybayinLabel.artists,
      LibrarySection.albums => BaybayinLabel.albums,
      LibrarySection.playlists => BaybayinLabel.playlists,
    },
    fallback: context.l10n.isFilipino ? null : defaultLabel,
    style: style ?? Theme.of(context).textTheme.headlineSmall,
    header: true,
    caption: true,
  );
}
