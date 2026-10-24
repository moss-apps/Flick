// Regression guard for the bug this file was written after: every manual entry
// used to render its *body sentence* where its heading belongs, because the
// titles were looked up in the same table as the bodies.
//
// The check is structural rather than cosmetic: within one entry, the title and
// the body must be different strings in both locales, and a title must be short
// enough to read as a heading.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/features/manual/data/manual_data.dart';
import 'package:flick/l10n/l10n.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh', 'CN'));

  test('no entry renders its body where its title belongs', () {
    final problems = <String>[];

    for (final section in kManualSections) {
      for (final entry in section.entries) {
        final enTitle = entry.title(en);
        final enBody = entry.body(en);
        final zhTitle = entry.title(zh);
        final zhBody = entry.body(zh);

        if (enTitle == enBody) {
          problems.add('[en] "$enTitle" is both the title and the body');
        }
        if (zhTitle == zhBody) {
          problems.add('[zh] "$zhTitle" is both the title and the body');
        }
        // A heading that carries a full stop is a sentence, not a label.
        for (final (locale, title) in [('en', enTitle), ('zh', zhTitle)]) {
          if (title.endsWith('.') || title.endsWith('。')) {
            problems.add('[$locale] title looks like a sentence: "$title"');
          }
        }
        // The Chinese title must not be the English body either -- that was the
        // exact shape of the original mix-up.
        if (zhTitle == enBody) {
          problems.add('[zh] title "$zhTitle" equals the English body');
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every title is short and every body is longer than its title', () {
    final problems = <String>[];

    for (final section in kManualSections) {
      for (final entry in section.entries) {
        final title = entry.title(zh);
        final body = entry.body(zh);
        if (title.length > 24) {
          problems.add('title too long (${title.length}): "$title"');
        }
        if (body.length <= title.length) {
          problems.add('body is not longer than its title: "$title" / "$body"');
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('section names match what the manual screen has always shown', () {
    // These are the ids the screen keys its scroll positions by; the labels are
    // what the user reads. Both must stay stable.
    const expected = {
      'songs': '歌曲',
      'albums': '专辑',
      'artists': '艺术家',
      'playlists': '播放列表',
      'folders': '文件夹',
      'favorites': '收藏',
      'search': '搜索',
      'mini_player': '迷你播放器',
      'full_player': '完整播放器',
      'queue': '播放队列',
      'equalizer': '均衡器',
      'visualizer': '可视化',
      'settings': '设置',
      'gestures': '手势',
      'home_widget': '主屏幕小组件',
    };

    final actual = {for (final s in kManualSections) s.id: s.title(zh)};
    for (final e in expected.entries) {
      expect(actual[e.key], e.value, reason: 'section "${e.key}" label changed');
    }
    expect(kManualSections.length, 16);
  });
}
