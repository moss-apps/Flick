import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

/// Language and script are independent. Autonyms always remain recognizable.
class LanguageSettingsCard extends StatelessWidget {
  const LanguageSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance,
      builder: (context, selectedLocale, _) {
        return SettingsCard(
          children: [
            SelectionSetting(
              icon: LucideIcons.smartphone,
              title: context.l10n.englishForFilipino.languageSystemDefault,
              subtitle: l10n.languageSectionDescription,
              selected: selectedLocale == null,
              onTap: () => LocaleController.instance.select(null),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.languages,
              title: '简体中文',
              subtitle: l10n.simplifiedChinese,
              selected: selectedLocale?.languageCode == 'zh',
              onTap: () =>
                  LocaleController.instance.select(const Locale('zh', 'CN')),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.globe,
              title: 'English',
              subtitle: l10n.english,
              selected: selectedLocale?.languageCode == 'en',
              onTap: () => LocaleController.instance.select(const Locale('en')),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.languages,
              title: 'Taglish',
              subtitle: l10n.baybayinPilotDescription,
              selected: selectedLocale == kFilipinoLocale,
              onTap: () => LocaleController.instance.select(kFilipinoLocale),
            ),
            if (Localizations.localeOf(context).languageCode == 'tl') ...[
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.type,
                title: l10n.baybayinHeadings,
                subtitle: l10n.baybayinHeadingsDescription,
                value: LocaleController.instance.baybayinHeadings,
                onChanged: LocaleController.instance.setBaybayinHeadings,
              ),
            ],
          ],
        );
      },
    );
  }
}
