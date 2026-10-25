import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/settings/data/settings_search.dart';
import 'package:flick/features/settings/data/settings_search_catalog.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/features/settings/screens/widget_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';

const _screens = 'lib/features/settings/screens';

void main() {
  tearDown(() => LocaleController.instance.bindLocale(const Locale('en')));

  test(
    'catalog IDs are unique and every section has a real destination anchor',
    () {
      final pages = buildSettingsSearchCatalog();
      expect(pages.map((p) => p.id).toSet().length, pages.length);
      final pageStems = pages
          .map((p) => p.id.replaceFirst(RegExp(r'_\d$'), ''))
          .toSet();
      for (final file in Directory(_screens).listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (!name.endsWith('_settings_screen.dart')) continue;
        expect(
          pageStems,
          contains(name.replaceFirst('_screen.dart', '')),
          reason: '$name needs a settings search entry',
        );
      }
      for (final page in pages.where((p) => p.sections.isNotEmpty)) {
        final stem = page.id.replaceFirst(RegExp(r'_\d$'), '');
        var source = File('$_screens/${stem}_screen.dart').readAsStringSync();
        if (stem == 'bottom_bar_settings') {
          source += File(
            'lib/features/settings/widgets/mini_player_customization.dart',
          ).readAsStringSync();
        }
        final anchors = RegExp(
          r"(?:sectionId:|id:)\s*'([\w]+)'",
        ).allMatches(source).map((m) => m.group(1)!).toSet();
        // The custom USB preferences page passes IDs to its header helper.
        if (stem == 'uac2_preferences') {
          anchors.addAll(
            RegExp(
              r"_buildSectionHeader\([\s\S]*?'(\w+)'\s*,?\s*\)",
            ).allMatches(source).map((m) => m.group(1)!),
          );
        }
        expect(
          page.sections.map((s) => s.id).toSet().length,
          page.sections.length,
          reason: 'Duplicate section in ${page.id}',
        );
        for (final section in page.sections) {
          expect(
            anchors,
            contains(section.id),
            reason: '${page.id}/${section.id} has no anchor',
          );
          expect(
            section.items.map((i) => i.id).toSet().length,
            section.items.length,
            reason: 'Duplicate item in ${page.id}/${section.id}',
          );
        }
      }
    },
  );

  test('standard section headers and setting rows cannot silently leave the index', () {
    final pages = buildSettingsSearchCatalog();
    // Navigation rows are indexed by their destination instead of duplicated
    // in the parent. Every other row must be covered by its own page's index.
    const destinationKeys = {
      'usbAudioUac2',
      'equalizer',
      'bottomBar',
      'visualizer',
      'customizeOrbital',
      'removeDuplicates',
      'fixMissingMetadata',
      'privacyPolicy',
      'supportFlick',
      'logs',
    };
    // Transient update states are information, not independently addressable settings.
    const statusKeys = {
      'checkingForUpdates',
      'updateAvailable',
      'couldNotCheckForUpdates',
      'offline',
      'noUpdateAvailable',
    };
    for (final stem
        in pages
            .where((p) => p.sections.isNotEmpty)
            .map((p) => p.id.replaceFirst(RegExp(r'_\d$'), ''))
            .toSet()) {
      var source = File('$_screens/${stem}_screen.dart').readAsStringSync();
      if (stem == 'bottom_bar_settings') {
        source += File(
          'lib/features/settings/widgets/mini_player_customization.dart',
        ).readAsStringSync();
      }
      final headers = RegExp(
        r'SettingsSectionHeader\(\s*(?:context\.)?l10n\.(?:englishForFilipino\.)?(\w+)',
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      // The action picker is an internal modal destination, reached via Quick Actions.
      headers.remove('chooseAction');
      final sections = pages
          .where((p) => p.id.startsWith(stem))
          .expand((p) => p.sections)
          .toList();
      final sectionIds = sections.map((s) => s.id).toSet();
      final titleKeys = {
        ...sectionIds,
        ...sections.expand((s) => s.items).map((i) => i.id),
        ...destinationKeys,
      };
      expect(
        headers.difference(sectionIds),
        isEmpty,
        reason: '$stem has unindexed sections',
      );
      final rows = RegExp(
        r'(?:ToggleSetting|NavigationSetting|SelectionSetting|SliderSetting|ActionButton|InfoSetting)\('
        r'\s*icon:\s*[^,]+,\s*title:\s*(?:context\.)?l10n\.(?:englishForFilipino\.)?(\w+)',
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(
        rows.difference(titleKeys).difference(statusKeys),
        isEmpty,
        reason:
            '$stem has unindexed setting titles; index it or document why it is not a setting',
      );
    }
  });

  test(
    'tab destinations select the requested tab without mounting or applying settings',
    () {
      final pages = buildSettingsSearchCatalog();
      for (var tab = 0; tab < 4; tab++) {
        final screen =
            pages
                    .singleWhere((p) => p.id == 'widget_settings_$tab')
                    .buildPage('background')
                as WidgetSettingsScreen;
        expect(screen.initialTab, tab);
        expect(screen.initialSection, 'background');
      }
      expect(
        (pages.singleWhere((p) => p.id == 'equalizer_dynamics').buildPage(null)
                as EqualizerScreen)
            .initialPage,
        1,
      );
      expect(
        (pages.singleWhere((p) => p.id == 'equalizer_fx').buildPage(null)
                as EqualizerScreen)
            .initialPage,
        2,
      );
    },
  );

  test(
    'localized titles are rebuilt while navigation IDs remain unchanged',
    () {
      final english = buildSettingsSearchCatalog();
      LocaleController.instance.bindLocale(const Locale('zh', 'CN'));
      final chinese = buildSettingsSearchCatalog();
      expect(chinese.map((p) => p.id), english.map((p) => p.id));
      expect(chinese.first.title, isNot(english.first.title));
      final audio = chinese.singleWhere((p) => p.id == 'audio_settings');
      expect(
        searchSettings(audio.sections[1].title, chinese).map((r) => r.page.id),
        contains(audio.id),
      );
      for (var i = 0; i < english.length; i++) {
        expect(
          chinese[i].sections.map((s) => s.id),
          english[i].sections.map((s) => s.id),
        );
      }
      LocaleController.instance.bindLocale(kFilipinoLocale);
      expect(buildSettingsSearchCatalog().first.title, english.first.title);
    },
  );
}
