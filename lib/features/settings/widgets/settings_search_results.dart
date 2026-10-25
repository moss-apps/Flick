import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/l10n/settings_l10n.dart';
import '../data/settings_search.dart';
import 'settings_widgets.dart';

class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({
    super.key,
    required this.query,
    required this.results,
    required this.onOpen,
  });

  final String query;
  final List<SettingsSearchResult> results;
  final void Function(SettingsSearchPage page, String? sectionId) onOpen;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.searchX,
                size: 32,
                color: context.adaptiveTextTertiary,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                l10n.noMatchesFor(query),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: ValueKey(query),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        0,
        AppConstants.spacingMd,
        AppConstants.navBarHeight +
            MediaQuery.paddingOf(context).bottom +
            AppConstants.spacingLg * 4,
      ),
      itemCount: results.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppConstants.spacingMd),
      itemBuilder: (context, index) {
        final result = results[index];
        return SettingsCard(
          children: [
            NavigationSetting(
              icon: result.page.icon,
              title: result.page.title,
              subtitle: result.page.category,
              onTap: () => onOpen(result.page, null),
            ),
            for (final match in result.matches) ...[
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.cornerDownRight,
                title: match.title,
                subtitle: match.item == null
                    ? result.page.title
                    : match.section.title,
                onTap: () => onOpen(result.page, match.section.id),
              ),
            ],
          ],
        );
      },
    );
  }
}
