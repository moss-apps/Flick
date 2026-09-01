import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/app_haptics.dart';
import '../models/search_category.dart';

class SearchFilterChips extends StatelessWidget {
  final Set<SearchCategory> enabled;
  final ValueChanged<SearchCategory> onToggle;
  final VoidCallback onToggleAll;
  final bool isAllEnabled;
  final Map<SearchCategory, int>? counts;
  final String query;

  const SearchFilterChips({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.onToggleAll,
    required this.isAllEnabled,
    this.counts,
    this.query = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        children: [
          _Chip(
            label: _labelForAll(hasQuery),
            selected: isAllEnabled,
            onTap: () {
              AppHaptics.tap();
              onToggleAll();
            },
            showCount: false,
          ),
          for (final cat in SearchCategory.values)
            _Chip(
              label: cat.label,
              count: hasQuery && counts != null ? counts![cat] : null,
              selected: enabled.contains(cat),
              onTap: () {
                AppHaptics.tap();
                onToggle(cat);
              },
            ),
        ],
      ),
    );
  }

  String _labelForAll(bool hasQuery) => 'All';
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final bool showCount;

  const _Chip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasCount = showCount && count != null && count! > 0;
    final displayLabel = hasCount ? '$label · $count' : label;

    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.spacingXs),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingXs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.glassBorder,
            ),
          ),
          child: Center(
            child: Text(
              displayLabel,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.accent
                    : context.adaptiveTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
