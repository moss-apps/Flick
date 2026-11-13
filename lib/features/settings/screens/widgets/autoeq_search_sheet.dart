import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/autoeq_catalog_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/settings_l10n.dart';

/// Opens the AutoEQ headphone picker. Returns the chosen entry, or null if
/// dismissed. The caller applies the result to the equalizer.
Future<AutoEqEntry?> showAutoEqSearchSheet(
  BuildContext context, {
  AutoEqCatalogService? service,
}) {
  return showModalBottomSheet<AutoEqEntry>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppBottomSheetSurface(
        maxHeightRatio: 0.9,
        padding: EdgeInsets.zero,
        child: _AutoEqSearchSheet(
          service: service ?? AutoEqCatalogService.instance,
        ),
      ),
    ),
  );
}

enum _OnlineStatusKind { searching, found, failed }

class _AutoEqSearchSheet extends StatefulWidget {
  const _AutoEqSearchSheet({required this.service});

  final AutoEqCatalogService service;

  @override
  State<_AutoEqSearchSheet> createState() => _AutoEqSearchSheetState();
}

class _AutoEqSearchSheetState extends State<_AutoEqSearchSheet> {
  AutoEqCatalogService get _service => widget.service;
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  List<AutoEqEntry> _all = const [];
  List<String> _brands = const [];
  List<AutoEqSearchResult> _results = const [];
  String? _brand;
  AutoEqEntry? _selected;
  bool _loading = true;
  bool _searchingOnline = false;
  String? _onlineStatus;
  _OnlineStatusKind? _onlineStatusKind;
  String _lastQuery = '';
  int _onlineRequest = 0;

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
    final query = _queryController.text;
    // Focus/IME changes also notify the controller. Only a text edit invalidates
    // an in-flight lookup, not moving the caret or dismissing the keyboard.
    if (!mounted || query == _lastQuery) return;
    _lastQuery = query;
    setState(() {
      _resetOnlineSearch();
      _selected = null;
      _recompute();
    });
  }

  void _resetOnlineSearch() {
    _onlineRequest++;
    _searchingOnline = false;
    _onlineStatus = null;
    _onlineStatusKind = null;
  }

  void _recompute() {
    _results = _service.search(_queryController.text, brand: _brand, limit: 80);
    final selected = _selected;
    if (_results.length == 1) {
      _selected = _results.single.entry;
    } else if (selected != null &&
        !_results.any((result) => result.entry.id == selected.id)) {
      _selected = null;
    }
  }

  void _select(AutoEqEntry entry) {
    setState(() {
      _resetOnlineSearch();
      _selected = entry;
    });
  }

  void _apply() {
    final entry = _selected;
    if (entry == null) return;
    Navigator.of(context).pop(entry);
  }

  Future<void> _searchOnline() async {
    if (_searchingOnline) return;
    FocusScope.of(context).unfocus();
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
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

    final request = ++_onlineRequest;
    setState(() {
      _searchingOnline = true;
      _onlineStatus = l10n.searchingOnline;
      _onlineStatusKind = _OnlineStatusKind.searching;
    });
    try {
      final entry = await _service.fetchOnline(brand, model);
      if (!mounted || request != _onlineRequest) return;
      if (entry != null) {
        setState(() {
          _selected = entry;
          _results = [
            AutoEqSearchResult(entry, 999),
            ..._results.where((result) => result.entry.id != entry.id),
          ];
          _onlineStatus = l10n.foundOnline(entry.displayName);
          _onlineStatusKind = _OnlineStatusKind.found;
        });
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      } else {
        setState(() {
          _onlineStatus = l10n.autoeqOnlineSearchFailed;
          _onlineStatusKind = _OnlineStatusKind.failed;
        });
      }
    } catch (_) {
      if (!mounted || request != _onlineRequest) return;
      setState(() {
        _onlineStatus = l10n.autoeqOnlineSearchFailed;
        _onlineStatusKind = _OnlineStatusKind.failed;
      });
    } finally {
      if (mounted && request == _onlineRequest) {
        setState(() => _searchingOnline = false);
      }
    }
  }

  void _dismissOnlineStatus() {
    setState(_resetOnlineSearch);
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
                    _brandChip(context, null, l10n.all),
                    for (final b in _brands) _brandChip(context, b, b),
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
              l10n.englishForFilipino.autoeqHeadphones2,
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
    final canSearchOnline =
        _queryController.text.trim().isNotEmpty && !_searchingOnline;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundStrong,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchOnline(),
                style: TextStyle(color: context.adaptiveTextPrimary),
                decoration: InputDecoration(
                  hintText: _all.isEmpty
                      ? l10n.searchHeadphones
                      : l10n.searchModelCount(_all.length),
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
          ),
          const SizedBox(width: AppConstants.spacingXs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              key: const Key('autoeq-online-search'),
              tooltip: l10n.searchOnline2,
              onPressed: canSearchOnline ? _searchOnline : null,
              icon: Icon(
                Icons.cloud_download_outlined,
                color: canSearchOnline
                    ? context.adaptiveTextPrimary
                    : context.adaptiveTextTertiary,
                size: 20,
              ),
            ),
          ),
        ],
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
          _resetOnlineSearch();
          _selected = null;
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
              color: selected ? AppColors.accent : AppColors.glassBorder,
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
    return Column(
      children: [
        if (_onlineStatus != null) _buildOnlineBanner(context),
        Expanded(
          child: _results.isEmpty
              ? _buildEmptyResults(context)
              : Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingLg,
                      vertical: AppConstants.spacingXs,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, i) =>
                        _resultTile(context, _results[i].entry),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyResults(BuildContext context) {
    final canSearchOnline =
        _queryController.text.trim().isNotEmpty && !_searchingOnline;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: context.adaptiveTextTertiary,
                    size: 30,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Text(
                    l10n.noMatchesTryFewerWordsOr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.adaptiveTextSecondary),
                  ),
                  if (_queryController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingSm),
                    TextButton.icon(
                      onPressed: canSearchOnline ? _searchOnline : null,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: Text(l10n.searchOnline2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineBanner(BuildContext context) {
    final kind = _onlineStatusKind;
    final failed = kind == _OnlineStatusKind.failed;
    final found = kind == _OnlineStatusKind.found;
    final color = failed
        ? AppColors.error
        : found
        ? AppColors.success
        : AppColors.accent;
    return Container(
      key: const Key('autoeq-online-status'),
      margin: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.spacingXs,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
        AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: failed ? AppColors.errorDim : AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: failed ? AppColors.errorBorder : AppColors.glassBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                failed
                    ? Icons.cloud_off_outlined
                    : found
                    ? Icons.check_circle_outline_rounded
                    : Icons.cloud_sync_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _onlineStatus!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _dismissOnlineStatus,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Icon(
                  Icons.close_rounded,
                  color: context.adaptiveTextTertiary,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_searchingOnline)
            const Padding(
              padding: EdgeInsets.only(
                top: AppConstants.spacingXs,
                bottom: AppConstants.spacingXs,
              ),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.glassBorder,
              ),
            ),
        ],
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
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
            l10n.bandsPreampDb(
              entry.bands.length,
              entry.preampDb.toStringAsFixed(1),
              entry.source,
            ),
            style: TextStyle(color: context.adaptiveTextTertiary, fontSize: 12),
          ),
          trailing: Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? AppColors.accent : context.adaptiveTextTertiary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _selected == null ? null : _apply,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            disabledBackgroundColor: AppColors.surfaceLight.withValues(
              alpha: 0.6,
            ),
            foregroundColor: AppColors.background,
            disabledForegroundColor: AppColors.textTertiary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
          ),
          child: Text(
            _selected == null ? l10n.apply : l10n.apply2(_selected!.model),
          ),
        ),
      ),
    );
  }
}
