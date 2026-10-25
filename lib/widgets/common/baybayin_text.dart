import 'package:flutter/material.dart';

import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/nav_bar_config.dart';

/// Curated labels only. Metadata and arbitrary UI text are never converted.
enum BaybayinLabel {
  songs,
  artists,
  albums,
  playlists,
  favorites,
  folders,
  queue,
  settings,
  library,
  replay,
  nowPlaying,
  playing,
}

extension BaybayinLabelCopy on BaybayinLabel {
  String text(AppLocalizations l10n) => switch (this) {
    BaybayinLabel.songs => l10n.songs14,
    BaybayinLabel.artists => l10n.artists,
    BaybayinLabel.albums => l10n.albums,
    BaybayinLabel.playlists => l10n.playlists,
    BaybayinLabel.favorites => l10n.favorites,
    BaybayinLabel.folders => l10n.folders,
    BaybayinLabel.queue => l10n.queue,
    BaybayinLabel.settings => l10n.settings,
    BaybayinLabel.library => l10n.libraryLabel,
    BaybayinLabel.replay => l10n.replayShortcutLabel,
    BaybayinLabel.nowPlaying => l10n.nowPlaying,
    BaybayinLabel.playing => l10n.playingLabel,
  };
}

BaybayinLabel? baybayinNavigationLabel(NavBarButton button) => switch (button) {
  NavBarButton.artists => BaybayinLabel.artists,
  NavBarButton.favorites => BaybayinLabel.favorites,
  NavBarButton.folders => BaybayinLabel.folders,
  NavBarButton.settings => BaybayinLabel.settings,
  _ => null,
};

class BaybayinText extends StatelessWidget {
  const BaybayinText({
    super.key,
    required this.label,
    this.fallback,
    this.style,
    this.header = false,
    this.caption = false,
    this.maxLines,
    this.overflow,
  });

  final BaybayinLabel? label;
  final String? fallback;
  final TextStyle? style;
  final bool header;
  final bool caption;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final latin = label?.text(strings) ?? fallback ?? '';
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance,
      builder: (context, _, _) {
        final enabled =
            label != null &&
            strings.isFilipino &&
            LocaleController.instance.baybayinHeadings;
        final text = enabled
            ? label!.text(lookupAppLocalizations(kBaybayinLocale))
            : fallback ?? latin;
        return Semantics(
          header: header,
          label: enabled ? latin : null,
          excludeSemantics: enabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: style, maxLines: maxLines, overflow: overflow),
              if (enabled && caption) ...[
                const SizedBox(height: 4),
                Text(
                  latin,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
