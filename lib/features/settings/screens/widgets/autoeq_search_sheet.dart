import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/autoeq_catalog_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

/// Opens the AutoEQ headphone picker. Returns the chosen entry, or null if
/// dismissed. The caller applies the result to the equalizer.
Future<AutoEqEntry?> showAutoEqSearchSheet(BuildContext context) {
  return showModalBottomSheet<AutoEqEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => AppBottomSheetSurface(
      maxHeightRatio: 0.9,
      padding: EdgeInsets.zero,
      child: const _AutoEqSearchSheet(),
    ),
  );
}

class _AutoEqSearchSheet extends StatefulWidget {
  const _AutoEqSearchSheet();

  @override
  State<_AutoEqSearchSheet> createState() => _AutoEqSearchSheetState();
}

class _AutoEqSearchSheetState extends State<_AutoEqSearchSheet> {
  final _service = AutoEqCatalogService.instance;
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  List<AutoEqEntry> _all = const [];
  List<String> _brands = const [];
  List<AutoEqSearchResult> _results = const [];
  String? _brand;
  AutoEqEntry? _selected;
  bool _loading = true;
  bool _searchingOnline = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _load();
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _service.loadBundled();
    final brands = await _service.loadBrands();
    if (!mounted) return;
    setState(() {
      _all = entries;
      _brands = brands;
      _loading = false;
      _recompute();
    });
  }

  void _onQueryChanged() {
    if (mounted) setState(_recompute);
  }

  void _recompute() {
    _results = _service.search(_queryController.text, brand: _brand, limit: 80);
  }

  void _select(AutoEqEntry entry) {
    setState(() => _selected = entry);
  }

  void _apply() {
    final entry = _selected;
    if (entry == null) return;
    Navigator.of(context).pop(entry);
  }

  Future<void> _searchOnline() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      _toast('Type a brand and model to search online.');
      return;
    }
    // ponytail: crude split — assume first token (or two) is the brand if no
    // chip selected. Good enough for a fallback lookup.
    String brand = _brand ?? '';
    String model = query;
    if (brand.isEmpty) {
      final known = _brands.firstWhere(
        (b) => query.toLowerCase().startsWith(b.toLowerCase()),
        orElse: () => '',
      );
      if (known.isNotEmpty) {
        brand = known;
        model = query.substring(known.length).trim();
      }
    } else {
      model = query;
    }

    setState(() => _searchingOnline = true);
    try {
      final entry = await _service.fetchOnline(brand, model);
      if (!mounted) return;
      if (entry != null) {
        setState(() {
          _selected = entry;
          _results = [AutoEqSearchResult(entry, 999), ..._results];
        });
        _toast('Found "${entry.displayName}" online.');
      } else {
        _toast('Not found online. Try a different spelling.');
      }
    } finally {
      if (mounted) setState(() => _searchingOnline = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        _buildSearchField(context),
        const SizedBox(height: AppConstants.spacingSm),
        SizedBox(
          height: 38,
          child: _brands.isEmpty
              ? const SizedBox.shrink()
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLg,
                  ),
                  children: [
                    _brandChip(context, null, 'All'),
                    for (final b in _brands)
                      _brandChip(context, b, b),
                  ],
                ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Expanded(child: _buildBody(context)),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        AppConstants.spacingXs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.headphones_rounded,
            color: context.adaptiveTextPrimary,
            size: 22,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              'AutoEQ Headphones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacingXs),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(
                Icons.close_rounded,
                color: context.adaptiveTextSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: TextField(
          controller: _queryController,
          style: TextStyle(color: context.adaptiveTextPrimary),
          decoration: InputDecoration(
            hintText: 'Search ${_all.isEmpty ? 'headphones' : '${_all.length} models'}…',
            hintStyle: TextStyle(color: context.adaptiveTextTertiary),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.adaptiveTextSecondary,
              size: 20,
            ),
            suffixIcon: _queryController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: context.adaptiveTextSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      _queryController.clear();
                      _onQueryChanged();
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _brandChip(BuildContext context, String? brand, String label) {
    final selected = _brand == brand;
    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.spacingXs),
      child: GestureDetector(
        onTap: () => setState(() {
          _brand = selected ? null : brand;
          _recompute();
        }),
        child: Container(
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
              color: selected
                  ? AppColors.accent
                  : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppColors.accent
                  : context.adaptiveTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.adaptiveTextPrimary,
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Text(
            'No matches. Try fewer words or search online.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.adaptiveTextSecondary),
          ),
        ),
      );
    }
    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
          vertical: AppConstants.spacingXs,
        ),
        itemCount: _results.length,
        itemBuilder: (context, i) => _resultTile(context, _results[i].entry),
      ),
    );
  }

  Widget _resultTile(BuildContext context, AutoEqEntry entry) {
    final selected = _selected?.id == entry.id;
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.glassBorder,
        ),
      ),
      child: ListTile(
        onTap: () => _select(entry),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingXs,
        ),
        title: Text(
          entry.displayName,
          style: TextStyle(
            color: context.adaptiveTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${entry.bands.length} bands · preamp ${entry.preampDb.toStringAsFixed(1)} dB · ${entry.source}',
          style: TextStyle(
            color: context.adaptiveTextTertiary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: selected
              ? AppColors.accent
              : context.adaptiveTextTertiary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canApply = _selected != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_searchingOnline)
            const Padding(
              padding: EdgeInsets.only(bottom: AppConstants.spacingXs),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.glassBorder,
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _searchingOnline ? null : _searchOnline,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Search online'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: canApply ? _apply : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor:
                      AppColors.surfaceLight.withValues(alpha: 0.6),
                  foregroundColor: AppColors.background,
                  disabledForegroundColor: AppColors.textTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
                child: Text(
                  _selected == null
                      ? 'Apply'
                      : 'Apply ${_selected!.model}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
