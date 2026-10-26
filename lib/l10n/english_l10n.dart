// Copy-role shim for screens whose Taglish UI is intentionally English.
//
// These screens read the app-wide `l10n` getter instead of a BuildContext, so a
// widget-level override cannot reach them. Import this library instead of
// `l10n.dart`: it re-exports every localization symbol and API, but replaces
// the global `l10n` getter with the English copy role. English and Chinese are
// unchanged (`englishForFilipino` returns the same catalog for them).

import 'package:flick/l10n/l10n.dart' as base;

export 'package:flick/l10n/l10n.dart' hide l10n;

base.AppLocalizations get l10n => base.l10n.englishForFilipino;
