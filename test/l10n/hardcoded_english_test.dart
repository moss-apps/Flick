// The localization guard that was missing.
//
// `arb_invariants_test` checks the ARB files and `source_guard_test` checks that
// localized values are never used as tokens. Neither of them looks at English
// text that never made it into an ARB at all, so a whole class of copy shipped
// untranslated and both guards stayed green:
//
//   * the five onboarding pages (`onboarding_screen.dart`) -- the very first
//     screen a new user sees, written in `static const _steps`;
//   * the playback-desync snack bar and the "press back again" hint
//     (`app.dart`), the two toasts a user hits without trying;
//   * the Replay look subtitles and the search-playback subtitle
//     (`widget_settings_screen.dart`, `interface_settings_screen.dart`).
//
// The common cause is structural, not carelessness: `const` expressions are
// evaluated at compile time and `l10n` is a runtime accessor, so every one of
// these had to be skipped when the codemod converted literal strings to keys.
//
// What this test does
// -------------------
// It scans `lib/` for string literals that actually reach the screen -- the
// source text of a `Text(...)`, or the label/title/subtitle/tooltip arguments
// of the widgets that render one -- and fails when such a literal looks like
// English prose. Prose means at least two runs of two or more latin letters and
// no `${...}` interpolation: an interpolation is a format string built from
// already-localized parts, and it is handled by an ICU key instead.
//
// The allowlist is per path, because the remaining entries are not call sites
// that can be fixed one by one -- they are documents.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourceDir = 'lib';

/// Paths that legitimately hold English prose, with the reason.
///
/// A new entry here needs the same scrutiny as a new entry in
/// `l10n_allowlist.json`: it is a claim that the English text is correct.
const Map<String, String> _allowedPaths = <String, String>{
  'lib/features/whats_new/data/changelog_data.dart':
      'release notes are historical product copy, one entry per shipped '
          'version; they are not UI strings and are translated as documents',
  'lib/features/settings/widgets/lastfm_settings_tile.dart':
      'the literal is the URL last.fm/api/account/create, shown as link text',
  'lib/features/settings/widgets/language_settings_card.dart':
      'the language names ("English", "Tagalog (Baybayin)") are endonyms, shown '
          'verbatim in every locale the way a language picker always does',
};

/// Where a literal actually gets rendered.
///
/// The first group is the direct case. The second is the one that shipped
/// English twice before it was caught: copy handed to a *project* widget
/// (`SelectionSetting(title: …)`, `SettingsSectionHeader('Background')`), which
/// then renders it. The third is an exception message that a `catch` block puts
/// on screen -- `Text(e.message)`, `_showMessage(error.message)`.
final RegExp _sink = RegExp(
  r'(?:\bText\s*\(\s*'
  r'|\b(?:label|title|subtitle|tooltip|hintText|message|description|header'
  r'|body|caption|summary|confirmLabel|cancelLabel)\s*:\s*'
  r'|\b(?:SettingsSectionHeader|SelectionSetting|ToggleSetting|SliderSetting'
  r'|ChoiceSetting|_ReplayLookOption|SettingsCard)\s*\(\s*'
  r')\s*[\x27"]',
);

final RegExp _word = RegExp(r'[A-Za-z]{2,}');

/// Blanks out `//` and `/* */` comments but keeps every offset and newline, so
/// a reported line number still matches the file on disk. Doc comments are
/// where this app explains itself in English, and they never reach a screen.
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (c == "'" || c == '"') {
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      while (j < src.length) {
        if (src[j] == r'\') {
          j += 2;
          continue;
        }
        if (src.startsWith(quote, j)) {
          j += quote.length;
          break;
        }
        j++;
      }
      out.write(src.substring(i, j));
      i = j;
      continue;
    }
    if (src.startsWith('//', i)) {
      var j = src.indexOf('\n', i);
      if (j < 0) j = src.length;
      out.write(' ' * (j - i));
      i = j;
      continue;
    }
    if (src.startsWith('/*', i)) {
      var j = src.indexOf('*/', i + 2);
      j = j < 0 ? src.length : j + 2;
      for (var k = i; k < j; k++) {
        out.write(src[k] == '\n' ? '\n' : ' ');
      }
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// The literal body starting at [start] (the opening quote), or null when the
/// quote is not an opening one -- e.g. an apostrophe inside `'You\'re'`.
String? _literalAt(String src, int start) {
  final c = src[start];
  final triple = src.startsWith(c * 3, start);
  final quote = triple ? c * 3 : c;
  final body = StringBuffer();
  var i = start + quote.length;
  while (i < src.length) {
    if (src[i] == r'\') {
      body.write(src.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (src.startsWith(quote, i)) return body.toString();
    if (!triple && src[i] == '\n') return null; // unterminated single-line
    body.write(src[i]);
    i++;
  }
  return null;
}

bool _isEnglishProse(String literal) {
  if (literal.contains(r'$')) return false;
  final s = literal.trim();
  if (s.isEmpty) return false;
  // A URL, a path, a MIME type, a bare identifier or a version is not copy.
  if (RegExp(r'^(?:https?://|/|\\)').hasMatch(s)) return false;
  if (RegExp(r'^[\w./-]+\.(?:dart|png|jpg|json|arb|xml|txt)$').hasMatch(s)) return false;
  if (RegExp(r'^[a-z]+/[a-z0-9.+-]+$').hasMatch(s)) return false; // application/json
  if (RegExp(r'^[\w.-]+$').hasMatch(s)) return false;            // single token
  if (RegExp(r'^v?\d+\.\d+(?:\.\d+)*(?:[-+][\w.]+)?$').hasMatch(s)) return false;
  return _word.allMatches(literal).length >= 2;
}

/// Exception classes carrying a message, and where those messages are printed.
///
/// This is the second blind spot this guard closes. A `TidalException` is built
/// in the service layer, but the text is printed by a widget:
/// `Text(_testError ?? …)` after `_humanError(e)`. No `Text('<literal>')` exists
/// anywhere near the literal, so every earlier scan -- and both older guards --
/// missed 60+ strings this way.
final RegExp _throwsProse = RegExp(
  r'\bthrow\s+(?:const\s+)?([A-Z_]\w*(?:Exception|Error))\s*\(\s*[\x27"]',
);

/// A message type counts as user-visible when some widget prints a caught
/// message (`Text(e.message)`, `_showMessage(error.message)`, or the
/// `is Foo ? e.message` form).
bool _messageIsRendered(String src) {
  return RegExp(
    r'(?:Text|_showMessage|_showToast|_showInlineMessage|_showError)\s*\(\s*'
    r'[\w.]+\s*(?:\.message)?\s*[,)]'
    r'|\bis\s+\w*Exception\s*\?\s*\w+\.message',
  ).hasMatch(src);
}

/// Paths whose exception messages are internal assertions, never copy.
///
/// The distinction matters and is easy to get wrong: an engine-level
/// `StateError('Rust audio engine not initialized')` is a programming error
/// that surfaces in logs and crash reports, whereas
/// `FormatException('Preset file is empty.')` is shown to the user by the
/// equalizer's import handler. Only the first kind belongs here.
const Map<String, String> _internalAssertionPaths = <String, String>{
  'lib/services/alac_converter_service.dart':
      'native session state assertions; failures are logged, the UI shows its '
          'own l10n string',
  'lib/services/android_audio_engine.dart':
      'platform-channel state assertions',
  'lib/services/audio_engine_manager.dart':
      'engine-not-attached assertion',
  'lib/services/apple_music/apple_music_metadata_service.dart':
      'transient retry reasons, consumed by the retry loop and logged',
  'lib/services/database_error.dart': 'database assertion',
  'lib/data/database.dart': 'database init assertion',
  'lib/services/motion_art/animated_artwork_service.dart':
      'transient retry reasons',
  'lib/services/player_service.dart': 'engine assertions',
  'lib/services/remote_source_service.dart': 'lookup assertions',
  'lib/services/rust_audio_engine.dart': 'engine assertions',
  'lib/services/rust_audio_service.dart': 'engine assertions',
  'lib/services/wav_stream_audio_source.dart': 'session assertions',
  'lib/services/csv_export_service.dart':
      'the recap screen swallows the failure and shows l10n.couldNotSave…',
  'lib/features/recap/screens/replay_studio_screen.dart':
      'the Ko-fi failure is swallowed and replaced by l10n.couldNotOpenKoFi…',
  'lib/features/playlists/screens/playlist_detail_screen.dart':
      'StateError from firstWhere orElse -- an internal invariant, not copy',
  'lib/features/playlists/utils/playlist_cover_render.dart':
      'decode/render failures are caught by the editor and replaced by '
      'l10n.couldNotOpenThatPhotoTry / l10n.couldNotUpdatePlaylistCover',
  'lib/features/playlists/screens/playlist_cover_editor_screen.dart':
      'a null render result is caught by _save and replaced by '
      'l10n.couldNotUpdatePlaylistCover',
};

bool _isFalsePositive(String literal) {
  // Interpolated format strings and pure diagnostics are handled by ICU keys
  // or are not copy at all.
  return literal.trimLeft().startsWith('HTTP ')
      || literal.contains(r'${');
}

class _Finding {
  _Finding(this.path, this.line, this.literal);

  final String path;
  final int line;
  final String literal;

  String get snippet => literal.replaceAll('\n', r'\n');

  @override
  String toString() => '  $path:$line  "$snippet"';
}

List<_Finding> _scan() {
  final findings = <_Finding>[];
  final files = <String, String>{};

  for (final entity in Directory(_sourceDir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.contains('/generated/')) continue;
    // Code generators emit their own English ("Unexpected subclass"); nothing a
    // translator can act on lives there.
    if (path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart')) {
      continue;
    }
    files[path] = _stripComments(entity.readAsStringSync());
  }

  // Only scan exception messages when a widget in this app actually prints a
  // caught message somewhere. Without that evidence the whole class is skipped,
  // which is what keeps engine assertions out of the report.
  final anyWidgetPrintsMessage = files.entries
      .where((e) =>
          !_allowedPaths.containsKey(e.key) &&
          !_internalAssertionPaths.containsKey(e.key))
      .any((e) => _messageIsRendered(e.value));

  for (final entry in files.entries) {
    final path = entry.key;
    if (_allowedPaths.containsKey(path)) continue;
    final src = entry.value;

    for (final sink in _sink.allMatches(src)) {
      final literal = _literalAt(src, sink.end - 1);
      if (literal == null || !_isEnglishProse(literal)) continue;
      findings.add(_Finding(
        path,
        '\n'.allMatches(src.substring(0, sink.end)).length + 1,
        literal,
      ));
    }

    if (_internalAssertionPaths.containsKey(path)) continue;

    // Exception messages, only when a widget elsewhere prints one.
    if (anyWidgetPrintsMessage) {
      for (final m in _throwsProse.allMatches(src)) {
        final literal = _literalAt(src, m.end - 1);
        if (literal == null || !_isEnglishProse(literal)) continue;
        if (_isFalsePositive(literal)) continue;
        findings.add(_Finding(
          path,
          '\n'.allMatches(src.substring(0, m.end)).length + 1,
          literal,
        ));
      }
    }
  }
  return findings;
}

void main() {
  test('no user-visible English is left hardcoded in lib/', () {
    final findings = _scan();

    expect(
      findings,
      isEmpty,
      reason: 'These strings are shown to the user exactly as written, so every '
          'locale shows English:\n${findings.join('\n')}\n\n'
          'Move each one into lib/l10n/app_en.arb + app_zh.arb and read it through '
          '`context.l10n`. A `const` widget cannot call `l10n` -- drop the `const` '
          'and build the list/delegate at build time, the way '
          '`lib/providers/tutorial_provider.dart` resolves its titles.\n'
          'Only add a path to _allowedPaths when the file really is a document '
          'rather than UI copy, and say why.',
    );
  });
}
