import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/manual/data/manual_data.dart';

class ManualScreen extends StatefulWidget {
  final String? initialSection;

  const ManualScreen({super.key, this.initialSection});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final s in kManualSections) {
      _sectionKeys[s.id] = GlobalKey();
    }
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToSection() {
    final key = _sectionKeys[widget.initialSection];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppConstants.animationNormal,
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  List<_SearchHit> _searchHits() {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    final hits = <_SearchHit>[];
    for (final section in kManualSections) {
      for (final entry in section.entries) {
        final inTitle = entry.title.toLowerCase().contains(q);
        final inBody = entry.body.toLowerCase().contains(q);
        final inSection = section.title.toLowerCase().contains(q);
        if (inTitle || inBody || inSection) {
          hits.add(_SearchHit(section: section, entry: entry));
        }
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: _searching
            ? _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClose: () => setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                }),
              )
            : const Text(
                'Manual',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(LucideIcons.search, size: 20),
              onPressed: () => setState(() => _searching = true),
            ),
        ],
      ),
      body: SafeArea(
        child: _query.isNotEmpty
            ? _buildSearchResults()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingMd,
                ),
                itemCount: kManualSections.length,
                itemBuilder: (context, i) {
                  final section = kManualSections[i];
                  final initiallyExpanded = widget.initialSection == section.id;
                  return _ManualSectionCard(
                    key: _sectionKeys[section.id],
                    section: section,
                    initiallyExpanded: initiallyExpanded,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final hits = _searchHits();
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.searchX,
                size: 40,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'No matches for "$_query"',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingMd,
      ),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final hit = hits[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ManualEntryContent(
              sectionLabel: hit.section.title,
              entry: hit.entry,
            ),
            if (i < hits.length - 1) ...[
              const SizedBox(height: AppConstants.spacingMd),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: AppConstants.spacingMd),
            ],
          ],
        );
      },
    );
  }
}

class _SearchHit {
  final ManualSection section;
  final ManualEntry entry;
  const _SearchHit({required this.section, required this.entry});
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'ProductSans',
        color: AppColors.textPrimary,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: 'Search the manual...',
        hintStyle: const TextStyle(
          fontFamily: 'ProductSans',
          color: AppColors.textTertiary,
        ),
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onClose,
        ),
      ),
    );
  }
}

class _ManualSectionCard extends StatefulWidget {
  final ManualSection section;
  final bool initiallyExpanded;

  const _ManualSectionCard({
    super.key,
    required this.section,
    required this.initiallyExpanded,
  });

  @override
  State<_ManualSectionCard> createState() => _ManualSectionCardState();
}

class _ManualSectionCardState extends State<_ManualSectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacingMd,
              ),
              child: Row(
                children: [
                  Icon(widget.section.icon, size: 20, color: AppColors.accent),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Text(
                      widget.section.title,
                      style: const TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.section.entries.length}',
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: AppConstants.animationNormal,
                    child: const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppConstants.animationNormal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: AppConstants.animationNormal,
              opacity: _expanded ? 1.0 : 0.0,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: AppConstants.spacingLg,
                        right: AppConstants.spacingLg,
                        bottom: AppConstants.spacingMd,
                      ),
                      child: Column(
                        children: [
                          for (final entry in widget.section.entries) ...[
                            _ManualEntryCard(entry: entry),
                            const SizedBox(height: AppConstants.spacingSm),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntryCard extends StatelessWidget {
  final ManualEntry entry;

  const _ManualEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: _ManualEntryContent(entry: entry),
    );
  }
}

class _ManualEntryContent extends StatelessWidget {
  final ManualEntry entry;
  final String? sectionLabel;

  const _ManualEntryContent({required this.entry, this.sectionLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionLabel != null) ...[
          Text(
            sectionLabel!.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          entry.title,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.body,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (entry.tips != null && entry.tips!.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingSm),
          for (final tip in entry.tips!) ...[
            Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      LucideIcons.lightbulb,
                      size: 13,
                      color: AppColors.milestoneAmethyst,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: tip,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ],
    );
  }
}
