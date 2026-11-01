import 'package:flick/l10n/l10n.dart';

/// Formats the playlist detail header's information line.
///
/// The caller supplies the copy catalog so the screen can force this line to
/// English under Taglish without changing the playlist name or the rest of the
/// playlist interface.
String buildPlaylistHeaderMeta({
  required AppLocalizations l10n,
  required int songCount,
  required String totalDuration,
  required DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return [
    if (songCount > 0) l10n.songs3(songCount),
    if (songCount > 0) totalDuration,
    l10n.created(formatPlaylistDate(createdAt, l10n)),
    if (updatedAt != null && updatedAt != createdAt)
      l10n.updated(formatPlaylistDate(updatedAt, l10n)),
  ].join(' · ');
}

String formatPlaylistDate(DateTime? date, AppLocalizations l10n) {
  if (date == null) return '';
  final months = [
    l10n.jan,
    l10n.feb,
    l10n.mar,
    l10n.apr,
    l10n.may,
    l10n.jun,
    l10n.jul,
    l10n.aug,
    l10n.sep,
    l10n.oct,
    l10n.nov,
    l10n.dec,
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
