import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/widget_sync_service.dart';

class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  static const _tabCount = 3;
  int _tab = 0;
  int _dir = 1;

  void _switchTo(int i) {
    if (i < 0 || i >= _tabCount || i == _tab) return;
    setState(() {
      _dir = i > _tab ? 1 : -1;
      _tab = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Widgets',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabBar(
            selectedIndex: _tab,
            onSelected: _switchTo,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -250) {
                _switchTo(_tab + 1);
              } else if (v > 250) {
                _switchTo(_tab - 1);
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              transitionBuilder: (child, animation) {
                final incoming = (child.key as ValueKey).value == _tab;
                final beginX = (incoming ? _dir : -_dir).toDouble();
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(beginX, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: _tab == 0
                    ? const _MiniPlayerTab()
                    : _tab == 1
                    ? const _FlagshipTab()
                    : const _CompactTab(),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
        const tabs = ['Mini Player', '4×3 Flagship', '2×2'];
    return Row(
      children: List.generate(tabs.length * 2 - 1, (i) {
        if (i.isOdd) {
          return SizedBox(width: AppConstants.spacingXs);
        }
        final index = i ~/ 2;
        final selected = index == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingSm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.surface.withValues(alpha: 0.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: selected
                    ? Border.all(color: AppColors.glassBorder)
                    : null,
              ),
              child: Text(
                tabs[index],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected
                          ? context.adaptiveTextPrimary
                          : context.adaptiveTextTertiary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MiniPlayerTab extends ConsumerWidget {
  const _MiniPlayerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    return Column(
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
        const SettingsSectionHeader('Text Size'),
        SettingsCard(
          children: [
            SliderSetting(
              icon: LucideIcons.type,
              title: 'Font Scale',
              subtitle: 'Scales with widget size automatically',
              value: prefs.widgetTextScale,
              displayValue: '${(prefs.widgetTextScale * 100).round()}%',
              min: 0.8,
              max: 1.5,
              divisions: 14,
              onChanged: (v) => _updateTextScale(ref, v),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _WidgetTextPreview(
          titleBaseSp: 13,
          artistBaseSp: 11,
          baselineDp: 360,
          manualScale: prefs.widgetTextScale,
          accentColor: _resolveAccentColor(prefs.widgetAccentColor),
          centered: false,
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
      ],
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

  void _updateTextScale(WidgetRef ref, double value) {
    ref.read(appPreferencesProvider.notifier).setWidgetTextScale(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetTextScale: value),
    );
  }
}

class _FlagshipTab extends ConsumerWidget {
  const _FlagshipTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Content'),
        SettingsCard(
          children: [
            ToggleSetting(
              icon: LucideIcons.mic,
              title: 'Artist Name',
              subtitle: 'Show artist below song title',
              value: prefs.widgetFlagshipShowArtist,
              onChanged: (v) {
                ref
                    .read(appPreferencesProvider.notifier)
                    .setWidgetFlagshipShowArtist(v);
                WidgetSyncService.instance.pushCustomization(prefs.copyWith(
                  widgetFlagshipShowArtist: v,
                ));
              },
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingLg),
        const SettingsSectionHeader('Text Size'),
        SettingsCard(
          children: [
            SliderSetting(
              icon: LucideIcons.type,
              title: 'Font Scale',
              subtitle: 'Scales with widget size automatically',
              value: prefs.widgetFlagshipTextScale,
              displayValue:
                  '${(prefs.widgetFlagshipTextScale * 100).round()}%',
              min: 0.8,
              max: 1.5,
              divisions: 14,
              onChanged: (v) => _updateFlagshipTextScale(ref, v),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _WidgetTextPreview(
          titleBaseSp: 15,
          artistBaseSp: 12,
          baselineDp: 400,
          manualScale: prefs.widgetFlagshipTextScale,
          accentColor: _resolveAccentColor(prefs.widgetFlagshipAccent),
          centered: true,
        ),
        const SizedBox(height: AppConstants.spacingLg),
        const SettingsSectionHeader('Accent Color'),
        SettingsCard(
          children: [
            _AccentOption(
              label: 'White',
              color: Colors.white,
              value: 'white',
              groupValue: prefs.widgetFlagshipAccent,
              onChanged: (v) => _updateFlagshipAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Amber',
              color: const Color(0xFFFFB300),
              value: 'amber',
              groupValue: prefs.widgetFlagshipAccent,
              onChanged: (v) => _updateFlagshipAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Blue',
              color: const Color(0xFF64B5F6),
              value: 'blue',
              groupValue: prefs.widgetFlagshipAccent,
              onChanged: (v) => _updateFlagshipAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Green',
              color: const Color(0xFF81C784),
              value: 'green',
              groupValue: prefs.widgetFlagshipAccent,
              onChanged: (v) => _updateFlagshipAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Purple',
              color: const Color(0xFFCE93D8),
              value: 'purple',
              groupValue: prefs.widgetFlagshipAccent,
              onChanged: (v) => _updateFlagshipAccent(ref, v),
            ),
          ],
        ),
      ],
    );
  }

  void _updateFlagshipAccent(WidgetRef ref, String value) {
    ref.read(appPreferencesProvider.notifier).setWidgetFlagshipAccent(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetFlagshipAccent: value),
    );
  }

  void _updateFlagshipTextScale(WidgetRef ref, double value) {
    ref.read(appPreferencesProvider.notifier).setWidgetFlagshipTextScale(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetFlagshipTextScale: value),
    );
  }
}

class _CompactTab extends ConsumerWidget {
  const _CompactTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Background'),
        SettingsCard(
          children: [
            _OpacityOption(
              label: 'Transparent',
              value: 0,
              groupValue: prefs.widgetCompactBgOpacity,
              onChanged: (v) => _updateCompactOpacity(ref, v),
            ),
            const SettingsDivider(),
            _OpacityOption(
              label: 'Light',
              value: 1,
              groupValue: prefs.widgetCompactBgOpacity,
              onChanged: (v) => _updateCompactOpacity(ref, v),
            ),
            const SettingsDivider(),
            _OpacityOption(
              label: 'Medium',
              value: 2,
              groupValue: prefs.widgetCompactBgOpacity,
              onChanged: (v) => _updateCompactOpacity(ref, v),
            ),
            const SettingsDivider(),
            _OpacityOption(
              label: 'Dark',
              value: 3,
              groupValue: prefs.widgetCompactBgOpacity,
              onChanged: (v) => _updateCompactOpacity(ref, v),
            ),
            const SettingsDivider(),
            _OpacityOption(
              label: 'Solid',
              value: 4,
              groupValue: prefs.widgetCompactBgOpacity,
              onChanged: (v) => _updateCompactOpacity(ref, v),
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
              subtitle: 'Use album art as background',
              value: prefs.widgetCompactShowAlbumArt,
              onChanged: (v) {
                ref
                    .read(appPreferencesProvider.notifier)
                    .setWidgetCompactShowAlbumArt(v);
                WidgetSyncService.instance.pushCustomization(prefs.copyWith(
                  widgetCompactShowAlbumArt: v,
                ));
              },
            ),
            const SettingsDivider(),
            ToggleSetting(
              icon: LucideIcons.mic,
              title: 'Artist Name',
              subtitle: 'Show artist below song title',
              value: prefs.widgetCompactShowArtist,
              onChanged: (v) {
                ref
                    .read(appPreferencesProvider.notifier)
                    .setWidgetCompactShowArtist(v);
                WidgetSyncService.instance.pushCustomization(prefs.copyWith(
                  widgetCompactShowArtist: v,
                ));
              },
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingLg),
        const SettingsSectionHeader('Text Size'),
        SettingsCard(
          children: [
            SliderSetting(
              icon: LucideIcons.type,
              title: 'Font Scale',
              subtitle: 'Scales with widget size automatically',
              value: prefs.widgetCompactTextScale,
              displayValue:
                  '${(prefs.widgetCompactTextScale * 100).round()}%',
              min: 0.8,
              max: 1.5,
              divisions: 14,
              onChanged: (v) => _updateCompactTextScale(ref, v),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _WidgetTextPreview(
          titleBaseSp: 15,
          artistBaseSp: 12,
          baselineDp: 200,
          manualScale: prefs.widgetCompactTextScale,
          accentColor: _resolveAccentColor(prefs.widgetCompactAccent),
          centered: true,
        ),
        const SizedBox(height: AppConstants.spacingLg),
        const SettingsSectionHeader('Accent Color'),
        SettingsCard(
          children: [
            _AccentOption(
              label: 'White',
              color: Colors.white,
              value: 'white',
              groupValue: prefs.widgetCompactAccent,
              onChanged: (v) => _updateCompactAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Amber',
              color: const Color(0xFFFFB300),
              value: 'amber',
              groupValue: prefs.widgetCompactAccent,
              onChanged: (v) => _updateCompactAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Blue',
              color: const Color(0xFF64B5F6),
              value: 'blue',
              groupValue: prefs.widgetCompactAccent,
              onChanged: (v) => _updateCompactAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Green',
              color: const Color(0xFF81C784),
              value: 'green',
              groupValue: prefs.widgetCompactAccent,
              onChanged: (v) => _updateCompactAccent(ref, v),
            ),
            const SettingsDivider(),
            _AccentOption(
              label: 'Purple',
              color: const Color(0xFFCE93D8),
              value: 'purple',
              groupValue: prefs.widgetCompactAccent,
              onChanged: (v) => _updateCompactAccent(ref, v),
            ),
          ],
        ),
      ],
    );
  }

  void _updateCompactOpacity(WidgetRef ref, int value) {
    ref
        .read(appPreferencesProvider.notifier)
        .setWidgetCompactBgOpacity(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetCompactBgOpacity: value),
    );
  }

  void _updateCompactAccent(WidgetRef ref, String value) {
    ref.read(appPreferencesProvider.notifier).setWidgetCompactAccent(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetCompactAccent: value),
    );
  }

  void _updateCompactTextScale(WidgetRef ref, double value) {
    ref.read(appPreferencesProvider.notifier).setWidgetCompactTextScale(value);
    final prefs = ref.read(appPreferencesProvider);
    WidgetSyncService.instance.pushCustomization(
      prefs.copyWith(widgetCompactTextScale: value),
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

Color _resolveAccentColor(String name) {
  return switch (name) {
    'amber' => const Color(0xFFFFB300),
    'blue' => const Color(0xFF64B5F6),
    'green' => const Color(0xFF81C784),
    'purple' => const Color(0xFFCE93D8),
    _ => Colors.white,
  };
}

class _WidgetTextPreview extends StatefulWidget {
  const _WidgetTextPreview({
    required this.titleBaseSp,
    required this.artistBaseSp,
    required this.baselineDp,
    required this.manualScale,
    required this.accentColor,
    required this.centered,
  });

  final int titleBaseSp;
  final int artistBaseSp;
  final double baselineDp;
  final double manualScale;
  final Color accentColor;
  final bool centered;

  @override
  State<_WidgetTextPreview> createState() => _WidgetTextPreviewState();
}

class _WidgetTextPreviewState extends State<_WidgetTextPreview> {
  int _sizeIndex = 1;

  static const _autoFactors = [0.85, 1.0, 1.3];
  static const _sizeLabels = ['S', 'M', 'L'];

  @override
  Widget build(BuildContext context) {
    final auto = _autoFactors[_sizeIndex];
    double clampSp(int base) =>
        (base * auto * widget.manualScale).round().clamp(9, 22).toDouble();
    final titleSp = clampSp(widget.titleBaseSp);
    final artistSp = clampSp(widget.artistBaseSp);
    final cross = widget.centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
            AppConstants.spacingSm,
          ),
          child: Row(
            children: [
              Text(
                'Preview',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
              ),
              const Spacer(),
              ...List.generate(3, (i) {
                final selected = i == _sizeIndex;
                return Padding(
                  padding: const EdgeInsets.only(left: AppConstants.spacingXs),
                  child: GestureDetector(
                    onTap: () => setState(() => _sizeIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.surface.withValues(alpha: 0.8)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                        border: selected
                            ? Border.all(color: AppColors.glassBorder)
                            : null,
                      ),
                      child: Text(
                        _sizeLabels[i],
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? context.adaptiveTextPrimary
                              : context.adaptiveTextTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            0,
            AppConstants.spacingLg,
            AppConstants.spacingLg,
          ),
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: cross,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Midnight City Dreams',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w700,
                  fontSize: titleSp,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Neon Skyline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: artistSp,
                  color: widget.accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
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