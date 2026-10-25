// Guards for the localization files themselves.
//
// These catch the failures that `flutter analyze` cannot see, because they are
// not type or syntax errors -- a missing translation, a placeholder that was
// dropped while translating, or a key nobody reads any more.
//
// The allowlist next to this file is deliberate: every entry means "yes, this
// one is meant to read the same in both locales" (a brand name, a unit suffix).
// A new key that needs an entry fails the test until somebody writes the reason.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _enPath = 'lib/l10n/app_en.arb';
const String _zhPath = 'lib/l10n/app_zh.arb';
const String _allowlistPath = 'test/l10n/l10n_allowlist.json';
const String _sourceDir = 'lib';

/// Loads one ARB, dropping the `@key` metadata entries.
Map<String, String> _loadArb(String path) {
  final decoded = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Map<String, dynamic> _loadAllowlist() =>
    json.decode(File(_allowlistPath).readAsStringSync()) as Map<String, dynamic>;

Set<String> _allowlisted(String group) => (_loadAllowlist()[group] as Map<String, dynamic>)
    .keys
    .cast<String>()
    .toSet();

/// Placeholders used by an ICU message.
///
/// A hand-rolled regex is not enough here: in
/// `{count, plural, =1{day} other{days}}` a naive `{...}` scan reports `day`
/// and `days` as placeholders instead of `count`. This walks the message and
/// records the *selector* of every `{name, type, ...}` block, recursing into
/// the branches so a nested `{count}` is still found.
///
/// Returns the placeholder names, and whether the message is typed (plural or
/// select) at all -- translations of a plural legitimately drop `{count}`,
/// because Chinese has no plural form.
({Set<String> names, bool typed}) _placeholders(String message) {
  final names = <String>{};
  var typed = false;
  var i = 0;
  while (i < message.length) {
    if (message[i] != '{') {
      i++;
      continue;
    }
    final close = message.indexOf('}', i);
    final head = close > 0 ? message.substring(i + 1, close) : '';
    final name = head.split(',').first.trim();
    if (name.isNotEmpty) names.add(name);

    if (head.contains(',') && close > 0) {
      typed = true;
      var depth = 1;
      var k = i + 1;
      while (k < message.length && depth > 0) {
        if (message[k] == '{') depth++;
        if (message[k] == '}') depth--;
        k++;
      }
      i = k;
    } else {
      i = close + 1;
    }
  }
  return (names: names, typed: typed);
}

/// Keys read directly or through the explicit English-for-Filipino copy role.
Set<String> _referencedKeys() {
  final pattern = RegExp(
    r'(?:\bl10n\.|AppLocalizations\.of\([^)]*\)\.)(?:englishForFilipino\.)?([A-Za-z_]\w*)',
  );
  final used = <String>{};
  for (final entity in Directory(_sourceDir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.replaceAll(r'\', '/').contains('/generated/')) continue;
    used.addAll(pattern.allMatches(entity.readAsStringSync()).map((m) => m.group(1)!));
  }
  return used;
}

void main() {
  final en = _loadArb(_enPath);
  final zh = _loadArb(_zhPath);

  test('both locales declare the same keys', () {
    final missingInZh = en.keys.toSet().difference(zh.keys.toSet()).toList()..sort();
    final orphanedInZh = zh.keys.toSet().difference(en.keys.toSet()).toList()..sort();

    expect(
      missingInZh,
      isEmpty,
      reason: '$_zhPath is missing these keys: $missingInZh\n'
          'Run `flutter gen-l10n` and add the translations.',
    );
    expect(
      orphanedInZh,
      isEmpty,
      reason: '$_zhPath has keys $_enPath does not: $orphanedInZh',
    );
    expect(en.keys.length, greaterThan(0));
  });

  test('every key is translated, or allowlisted with a reason', () {
    final allowed = _allowlisted('untranslated');
    final untranslated = <String, String>{
      for (final key in en.keys)
        if (zh[key] == en[key] && !allowed.contains(key)) key: en[key]!,
    };

    expect(
      untranslated,
      isEmpty,
      reason: 'These keys still show the English text in a Chinese UI:\n'
          '${untranslated.entries.map((e) => '  ${e.key}: "${e.value}"').join('\n')}\n'
          'Translate them, or add them to $_allowlistPath under "untranslated" '
          'with a reason (a brand name or a unit suffix is a valid one).',
    );
  });

  test('translations keep the source placeholders', () {
    final problems = <String>[];
    for (final key in en.keys) {
      final source = _placeholders(en[key]!);
      final translation = _placeholders(zh[key] ?? '');
      if (source.typed) {
        // A plural/select translation may ignore the count it selects on, but it
        // must not invent a placeholder the English message does not declare.
        final extra = translation.names.difference(source.names);
        if (extra.isNotEmpty) {
          problems.add('$key: zh uses $extra, which "$_enPath" never declares');
        }
      } else if (source.names.difference(translation.names).isNotEmpty ||
          translation.names.difference(source.names).isNotEmpty) {
        problems.add(
          '$key: en uses ${source.names.toList()..sort()}, '
          'zh uses ${translation.names.toList()..sort()}',
        );
      }
    }

    expect(
      problems,
      isEmpty,
      reason: 'A dropped placeholder silently loses the value it stood for; an '
          'extra one breaks `flutter gen-l10n`:\n${problems.join('\n')}',
    );
  });

  test('every key is read by the code, or allowlisted', () {
    final allowed = _allowlisted('unreferenced');
    final used = _referencedKeys();
    final unreferenced = en.keys.where((k) => !used.contains(k) && !allowed.contains(k)).toList()
      ..sort();

    expect(
      unreferenced,
      isEmpty,
      reason: 'Nothing in $_sourceDir/ reads these keys: $unreferenced\n'
          'Either the call site was removed (delete the key, in both locales) or '
          'the key is never used -- add it to $_allowlistPath under '
          '"unreferenced" only if it must stay.',
    );
  });
}
