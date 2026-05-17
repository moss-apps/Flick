import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/widget_sync_service.dart';

class WidgetSettingsScreen extends ConsumerWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: 'Widgets',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Background'),
          SettingsCard(
            children: [
              _OpacityOption(
                label: 'Transparent',
                value: 0,
                groupValue: prefs.widgetBgOpacity,
                onChanged: (v) => _updateOpacity(ref, v),
              ),
              const SettingsDivider(),
              _OpacityOption(
                label: 'Light',
                value: 1,
                groupValue: prefs.widgetBgOpacity,
                onChanged: (v) => _updateOpacity(ref, v),
              ),
              const SettingsDivider(),
              _OpacityOption(
                label: 'Medium',
                value: 2,
                groupValue: prefs.widgetBgOpacity,
                onChanged: (v) => _updateOpacity(ref, v),
              ),
              const SettingsDivider(),
              _OpacityOption(
                label: 'Dark',
                value: 3,
                groupValue: prefs.widgetBgOpacity,
                onChanged: (v) => _updateOpacity(ref, v),
              ),
              const SettingsDivider(),
              _OpacityOption(
                label: 'Solid',
                value: 4,
                groupValue: prefs.widgetBgOpacity,
                onChanged: (v) => _updateOpacity(ref, v),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Content'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.image,
                title: 'Album Art',
                subtitle: 'Show album artwork on the mini player',
                value: prefs.widgetShowAlbumArt,
                onChanged: (v) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setWidgetShowAlbumArt(v);
                  WidgetSyncService.instance.pushCustomization(prefs.copyWith(
                    widgetShowAlbumArt: v,
                  ));
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.mic,
                title: 'Artist Name',
                subtitle: 'Show artist below song title',
                value: prefs.widgetShowArtist,
                onChanged: (v) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setWidgetShowArtist(v);
                  WidgetSyncService.instance.pushCustomization(prefs.copyWith(
                    widgetShowArtist: v,
                  ));
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Accent Color'),
          SettingsCard(
            children: [
              _AccentOption(
                label: 'White',
                color: Colors.white,
                value: 'white',
                groupValue: prefs.widgetAccentColor,
                onChanged: (v) => _updateAccent(ref, v),
              ),
              const SettingsDivider(),
              _AccentOption(
                label: 'Amber',
                color: const Color(0xFFFFB300),
                value: 'amber',
                groupValue: prefs.widgetAccentColor,
                onChanged: (v) => _updateAccent(ref, v),
              ),
              const SettingsDivider(),
              _AccentOption(
                label: 'Blue',
                color: const Color(0xFF64B5F6),
                value: 'blue',
                groupValue: prefs.widgetAccentColor,
                onChanged: (v) => _updateAccent(ref, v),
              ),
              const SettingsDivider(),
              _AccentOption(
                label: 'Green',
                color: const Color(0xFF81C784),
                value: 'green',
                groupValue: prefs.widgetAccentColor,
                onChanged: (v) => _updateAccent(ref, v),
              ),
              const SettingsDivider(),
              _AccentOption(
                label: 'Purple',
                color: const Color(0xFFCE93D8),
                value: 'purple',
                groupValue: prefs.widgetAccentColor,
                onChanged: (v) => _updateAccent(ref, v),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }

  void _updateOpacity(WidgetRef ref, int value) {
    ref.read(appPreferencesProvider.notifier).setWidgetBgOpacity(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetBgOpacity: value),
    );
  }

  void _updateAccent(WidgetRef ref, String value) {
    ref.read(appPreferencesProvider.notifier).setWidgetAccentColor(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetAccentColor: value),
    );
  }
}

class _OpacityOption extends StatelessWidget {
  const _OpacityOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int groupValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Row(
            children: [
              Container(
                width: AppConstants.containerSizeMd,
                height: AppConstants.containerSizeMd,
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundStrong,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  LucideIcons.paintBucket,
                  color: selected
                      ? context.adaptiveTextPrimary
                      : context.adaptiveTextTertiary,
                  size: AppConstants.iconSizeLg,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected
                    ? context.adaptiveTextPrimary
                    : context.adaptiveTextTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentOption extends StatelessWidget {
  const _AccentOption({
    required this.label,
    required this.color,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Row(
            children: [
              Container(
                width: AppConstants.containerSizeMd,
                height: AppConstants.containerSizeMd,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  LucideIcons.palette,
                  color: color,
                  size: AppConstants.iconSizeLg,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected
                    ? context.adaptiveTextPrimary
                    : context.adaptiveTextTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
