import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SortFilterBottomSheet extends StatelessWidget {
  final SongSortOption currentSort;
  final SongFileTypeFilter currentFilter;
  final ValueChanged<SongSortOption> onSortChanged;
  final ValueChanged<SongFileTypeFilter> onFilterChanged;

  const SortFilterBottomSheet({
    super.key,
    required this.currentSort,
    required this.currentFilter,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  static void show(BuildContext context, {
    required SongSortOption currentSort,
    required SongFileTypeFilter currentFilter,
    required ValueChanged<SongSortOption> onSortChanged,
    required ValueChanged<SongFileTypeFilter> onFilterChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SortFilterBottomSheet(
        currentSort: currentSort,
        currentFilter: currentFilter,
        onSortChanged: onSortChanged,
        onFilterChanged: onFilterChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'SORT BY'),
              const SizedBox(height: 8),
              ...SongSortOption.values.map((option) => _buildSortTile(context, option)),
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: 12),
              _buildSectionHeader(context, 'FILTER BY FORMAT'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SongFileTypeFilter.values.map((filter) => _buildFilterChip(context, filter)).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSortTile(BuildContext context, SongSortOption option) {
    final isSelected = currentSort == option;
    final icon = _sortIcon(option);
    final label = _sortLabel(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onSortChanged(option);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.accent
                    : context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AppColors.accent
                        : context.adaptiveTextPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, SongFileTypeFilter filter) {
    final isSelected = currentFilter == filter;
    return GestureDetector(
      onTap: () {
        onFilterChanged(filter);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.glassBorder,
            width: 1,
          ),
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Text(
          filter.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppColors.accent
                : context.adaptiveTextPrimary,
          ),
        ),
      ),
    );
  }

  IconData _sortIcon(SongSortOption option) {
    switch (option) {
      case SongSortOption.albumArtist:
        return LucideIcons.user;
      case SongSortOption.title:
        return LucideIcons.type;
      case SongSortOption.artist:
        return LucideIcons.mic;
      case SongSortOption.dateAdded:
        return LucideIcons.calendar;
      case SongSortOption.fileType:
        return LucideIcons.file;
      case SongSortOption.folder:
        return LucideIcons.folder;
      case SongSortOption.year:
        return LucideIcons.calendarDays;
      case SongSortOption.genre:
        return LucideIcons.music;
    }
  }

  String _sortLabel(SongSortOption option) {
    switch (option) {
      case SongSortOption.albumArtist:
        return 'Album Artist';
      case SongSortOption.title:
        return 'Title';
      case SongSortOption.artist:
        return 'Artist';
      case SongSortOption.dateAdded:
        return 'Date Added';
      case SongSortOption.fileType:
        return 'Format';
      case SongSortOption.folder:
        return 'Folder';
      case SongSortOption.year:
        return 'Year';
      case SongSortOption.genre:
        return 'Genre';
    }
  }
}
