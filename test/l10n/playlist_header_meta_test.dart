import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/features/playlists/playlist_header_meta.dart';
import 'package:flick/l10n/l10n.dart';

void main() {
  final english = lookupFlickLocalizations(kFallbackLocale);
  final taglish = lookupFlickLocalizations(kFilipinoLocale);
  final chinese = lookupFlickLocalizations(const Locale('zh', 'CN'));
  final created = DateTime(2026, 10, 30);
  final updated = DateTime(2026, 11, 2);

  test('Taglish playlist header uses the English copy role', () {
    final meta = buildPlaylistHeaderMeta(
      l10n: taglish.englishForFilipino,
      songCount: 3,
      totalDuration: '12m',
      createdAt: created,
      updatedAt: updated,
    );

    expect(meta, '3 songs · 12m · Created Oct 30, 2026 · Updated Nov 2, 2026');
    expect(meta, isNot(contains('kanta')));
    expect(meta, isNot(contains('Nagawa')));
  });

  test('the active Taglish catalog stays Taglish', () {
    expect(
      buildPlaylistHeaderMeta(
        l10n: taglish,
        songCount: 3,
        totalDuration: '12m',
        createdAt: created,
        updatedAt: updated,
      ),
      '3 kanta · 12m · Nagawa ang Okt 30, 2026 · '
      'Na-update ang Nob 2, 2026',
    );
  });

  test('Chinese keeps its localized units and date format', () {
    expect(
      buildPlaylistHeaderMeta(
        l10n: chinese,
        songCount: 3,
        totalDuration: '12m',
        createdAt: created,
        updatedAt: updated,
      ),
      '3 首歌曲 · 12m · 创建于 10 月 30, 2026 · 更新于 11 月 2, 2026',
    );
  });

  test('an empty playlist omits count and duration', () {
    expect(
      buildPlaylistHeaderMeta(
        l10n: english,
        songCount: 0,
        totalDuration: '0m',
        createdAt: created,
      ),
      'Created Oct 30, 2026',
    );
  });

  test('an unchanged updated timestamp is omitted', () {
    final meta = buildPlaylistHeaderMeta(
      l10n: english,
      songCount: 2,
      totalDuration: '4m',
      createdAt: created,
      updatedAt: created,
    );

    expect(meta, '2 songs · 4m · Created Oct 30, 2026');
    expect(meta, isNot(contains('Updated')));
  });
}
