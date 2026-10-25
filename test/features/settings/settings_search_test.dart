import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/settings/data/settings_search.dart';

SettingsSearchPage _page(
  String id,
  String title, {
  String keywords = '',
  List<SettingsSearchSection> sections = const [],
}) => SettingsSearchPage(
  id: id,
  title: title,
  category: 'Media',
  icon: const IconData(0),
  buildPage: (_) => const SizedBox(),
  keywords: keywords,
  sections: sections,
);

void main() {
  final pages = [
    _page(
      'audio',
      'Audio',
      keywords: 'dac',
      sections: const [
        SettingsSearchSection('replaygain', 'ReplayGain', [
          SettingsSearchItem('preamp', 'Pre-amp'),
          SettingsSearchItem('clipping', 'Prevent clipping'),
        ]),
      ],
    ),
    _page(
      'interface',
      'Interface',
      sections: const [
        SettingsSearchSection('interaction', 'Interaction', [
          SettingsSearchItem(
            'haptics',
            'Haptic feedback',
            keywords: 'vibrate vibration',
          ),
        ]),
      ],
    ),
  ];

  test(
    'empty, whitespace, punctuation and unknown queries have no matches',
    () {
      for (final query in ['', '  ', '---', 'nonexistent']) {
        expect(searchSettings(query, pages), isEmpty);
      }
    },
  );

  test('case and punctuation do not matter', () {
    for (final query in ['REPLAYGAIN', ' replay gain ', 'replay-gain']) {
      final result = searchSettings(query, pages).single;
      expect(result.page.id, 'audio');
      expect(result.matches.single.section.id, 'replaygain');
    }
    expect(
      searchSettings('pre amp', pages).single.matches.single.item?.id,
      'preamp',
    );
  });

  test('aliases match and multi-token queries require every token', () {
    expect(searchSettings('vibration', pages).single.page.id, 'interface');
    expect(
      searchSettings('audio clipping', pages).single.matches.single.item?.id,
      'clipping',
    );
    expect(
      searchSettings('clipping audio', pages).single.matches.single.item?.id,
      'clipping',
    );
    expect(
      searchSettings('dac clipping', pages).single.matches.single.item?.id,
      'clipping',
    );
    expect(searchSettings('audio vibration', pages), isEmpty);
  });

  test('page-only matches do not flood results with unrelated settings', () {
    final result = searchSettings('audio', pages).single;
    expect(result.matches, isEmpty);
    expect(searchSettings('dac', pages).single.matches, isEmpty);
  });

  test('exact titles rank above prefixes, substrings and aliases', () {
    final ranked = searchSettings('volume', [
      _page('alias', 'Sound', keywords: 'volume'),
      _page('contains', 'Extended volume'),
      _page('prefix', 'Volume controls'),
      _page('exact', 'Volume'),
    ]);
    expect(ranked.map((r) => r.page.id), [
      'exact',
      'prefix',
      'contains',
      'alias',
    ]);
  });

  test(
    'matches within a page rank by relevance; ties retain catalog order',
    () {
      final result = searchSettings('volume', [
        _page(
          'audio',
          'Audio',
          sections: const [
            SettingsSearchSection('volume', 'Volume', [
              SettingsSearchItem('extended', 'Extended volume'),
              SettingsSearchItem('volume', 'Volume'),
              SettingsSearchItem('boost', 'Volume boost'),
              SettingsSearchItem('limit', 'Volume limit'),
            ]),
          ],
        ),
      ]).single;
      expect(result.matches.map((m) => m.item?.id), [
        'volume',
        'boost',
        'limit',
        'extended',
      ]);
      expect(
        searchSettings('sound', [
          _page('a', 'Sound'),
          _page('b', 'Sound'),
        ]).map((r) => r.page.id),
        ['a', 'b'],
      );
    },
  );

  test('Unicode titles remain searchable', () {
    expect(
      searchSettings('音量', [
        _page(
          'audio',
          '音频',
          sections: const [SettingsSearchSection('volume', '音量', [])],
        ),
      ]).single.matches.single.section.id,
      'volume',
    );
  });
}
