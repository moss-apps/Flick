import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/online_lyrics_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OnlineLyricsSearchSheet extends StatefulWidget {
  final Song song;
  final LyricsService lyricsService;

  const OnlineLyricsSearchSheet({
    required this.song,
    required this.lyricsService,
    super.key,
  });

  static Future<bool?> show({
    required BuildContext context,
    required Song song,
    required LyricsService lyricsService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        maxHeightRatio: 0.92,
        child: OnlineLyricsSearchSheet(
          song: song,
          lyricsService: lyricsService,
        ),
      ),
    );
  }

  @override
  State<OnlineLyricsSearchSheet> createState() =>
      _OnlineLyricsSearchSheetState();
}

class _OnlineLyricsSearchSheetState extends State<OnlineLyricsSearchSheet>
    with TickerProviderStateMixin {
  final OnlineLyricsService _onlineService = OnlineLyricsService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _previewScrollController = ScrollController();

  bool _isInitialLoading = true;
  bool _isSearching = false;
  bool _isSaving = false;
  OnlineLyricsResult? _exactMatch;
  List<OnlineLyricsResult> _rawResults = [];
  List<OnlineLyricsResult> _filteredResults = [];
  String? _errorMessage;
  bool _fuzzySearchDone = false;

  // Preview state
  OnlineLyricsResult? _previewResult;

  // Filters
  bool _filterSynced = false;
  bool _filterPlain = false;
  bool _filterInstrumental = false;

  // Stagger animation
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _searchController.text = '${widget.song.artist} ${widget.song.title}';
    _doExactSearch();
    _searchController.addListener(() => setState(() {}));

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _previewScrollController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _triggerStagger() {
    _staggerController.forward(from: 0);
  }

  void _applyFilters() {
    var results = List<OnlineLyricsResult>.from(_rawResults);
    if (_filterSynced) {
      results = results.where((r) => r.hasSyncedLyrics).toList();
    }
    if (_filterPlain) {
      results =
          results.where((r) => r.hasPlainLyrics && !r.hasSyncedLyrics).toList();
    }
    if (_filterInstrumental) {
      results = results.where((r) => r.instrumental).toList();
    }
    setState(() => _filteredResults = results);
    _triggerStagger();
  }

  Future<void> _doExactSearch() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _exactMatch = null;
      _fuzzySearchDone = false;
      _rawResults = [];
      _filteredResults = [];
      _previewResult = null;
    });

    final result = await _onlineService.fetchExact(
      artist: widget.song.artist,
      title: widget.song.title,
      album: widget.song.album,
      duration: widget.song.duration,
    );

    if (!mounted) return;

    if (result != null && (result.hasSyncedLyrics || result.hasPlainLyrics)) {
      setState(() {
        _exactMatch = result;
        _isInitialLoading = false;
      });
      _doFuzzySearch();
      return;
    }

    setState(() {
      _exactMatch = null;
      _isInitialLoading = false;
    });
    _doFuzzySearch();
  }

  Future<void> _doFuzzySearch() async {
    setState(() {
      _isSearching = true;
    });

    final results = await _onlineService.search(
      query: _searchController.text,
      artist: widget.song.artist,
      title: widget.song.title,
    );

    if (!mounted) return;

    setState(() {
      _rawResults = results;
      _isSearching = false;
      _fuzzySearchDone = true;
    });
    _applyFilters();
    if (_rawResults.isEmpty) {
      setState(() {
        _errorMessage = 'No lyrics found online for this song.';
      });
    }
  }

  Future<void> _doCustomSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _previewResult = null;
    });

    final results = await _onlineService.search(query: query);

    if (!mounted) return;

    setState(() {
      _rawResults = results;
      _isSearching = false;
      _fuzzySearchDone = true;
    });
    _applyFilters();
    if (_rawResults.isEmpty) {
      setState(() {
        _errorMessage = 'No results found for "$query".';
      });
    }
  }

  String _injectLengthTag(String lrcContent, Duration length) {
    final lengthTag = widget.lyricsService.formatLengthTag(length);
    final metadataPattern = RegExp(r'^\s*\[[a-zA-Z]+:.*\]\s*$');
    final lines = lrcContent.split('\n');
    var lastMetadataIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (metadataPattern.hasMatch(lines[i])) {
        lastMetadataIndex = i;
      } else if (lastMetadataIndex != -1) {
        break;
      }
    }
    if (lastMetadataIndex >= 0) {
      lines.insert(lastMetadataIndex + 1, lengthTag);
      return lines.join('\n');
    }
    return '$lengthTag\n$lrcContent';
  }

  Future<void> _saveResult(OnlineLyricsResult result) async {
    setState(() => _isSaving = true);

    final isSynced = result.hasSyncedLyrics;
    String content = isSynced ? result.syncedLyrics! : result.plainLyrics!;
    final fileName = isSynced ? 'online.lrc' : 'online.txt';

    if (isSynced && widget.song.duration.inSeconds > 0) {
      content = _injectLengthTag(content, widget.song.duration);
    }

    await widget.lyricsService.importLyricsForSong(
      song: widget.song,
      fileName: fileName,
      content: content,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _openPreview(OnlineLyricsResult result) {
    setState(() => _previewResult = result);
  }

  void _closePreview() {
    setState(() => _previewResult = null);
  }

  bool _isDurationMatch(OnlineLyricsResult result) {
    if (result.duration == null || widget.song.duration.inSeconds <= 0) {
      return false;
    }
    final diff = (result.duration! - widget.song.duration.inSeconds).abs();
    return diff <= 5;
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.accentDim.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(LucideIcons.globe, size: 20, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Search Online Lyrics',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon:
              Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.glassBackgroundStrong,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return AnimatedSwitcher(
      duration: AppConstants.animationFast,
      child: const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildExactMatchSection(OnlineLyricsResult result) {
    final textColor = AppColors.textPrimary;
    final secondaryColor = AppColors.textSecondary;
    final subtitleColor = Colors.white.withValues(alpha: 0.56);

    return AnimatedSwitcher(
      duration: AppConstants.animationNormal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey('exact-match-${result.id}'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Exact Match',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                if (result.instrumental)
                  _buildTypeChip('Instrumental', LucideIcons.music2),
                if (!result.instrumental && result.hasSyncedLyrics)
                  _buildTypeChip('Synced LRC', LucideIcons.clock3),
                if (!result.instrumental && !result.hasSyncedLyrics)
                  _buildTypeChip('Plain Text', LucideIcons.fileText),
                const SizedBox(width: 4),
                _buildTypeChip('LRCLib', LucideIcons.globe),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.trackName ?? widget.song.title,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              result.artistName ?? widget.song.artist,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryColor,
              ),
            ),
            if (result.albumName != null && result.albumName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                result.albumName!,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
            ],
            if (result.snippet != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  result.snippet!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _openPreview(result),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.4),
                ),
                child: Text(
                  'Preview & Use',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.background,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    Widget filterChip({
      required String label,
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) {
                  return ScaleTransition(
                    scale: anim,
                    child: FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  icon,
                  key: ValueKey('icon-$active'),
                  size: 12,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      active ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            filterChip(
              label: 'Synced',
              icon: LucideIcons.clock3,
              active: _filterSynced,
              onTap: () {
                setState(() {
                  _filterSynced = !_filterSynced;
                  if (_filterSynced) _filterPlain = false;
                });
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            filterChip(
              label: 'Plain',
              icon: LucideIcons.fileText,
              active: _filterPlain,
              onTap: () {
                setState(() {
                  _filterPlain = !_filterPlain;
                  if (_filterPlain) _filterSynced = false;
                });
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            filterChip(
              label: 'Instrumental',
              icon: LucideIcons.music2,
              active: _filterInstrumental,
              onTap: () {
                setState(() => _filterInstrumental = !_filterInstrumental);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onSubmitted: _doCustomSearch,
      style: TextStyle(
        fontFamily: 'ProductSans',
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Search artist + title...',
        hintStyle: TextStyle(
          fontFamily: 'ProductSans',
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        prefixIconColor: AppColors.textSecondary,
        suffixIcon: _searchController.text.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text !=
                      '${widget.song.artist} ${widget.song.title}')
                    IconButton(
                      icon: const Icon(LucideIcons.rotateCcw, size: 16),
                      onPressed: () {
                        _searchController.text =
                            '${widget.song.artist} ${widget.song.title}';
                        _doCustomSearch(_searchController.text);
                      },
                      color: AppColors.textSecondary,
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _doCustomSearch(_searchController.text);
                    },
                    color: AppColors.textSecondary,
                  ),
                ],
              )
            : null,
        filled: true,
        fillColor: AppColors.glassBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide:
              BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return AnimatedSwitcher(
        duration: AppConstants.animationFast,
        child: const Padding(
          key: ValueKey('results-loading'),
          padding: EdgeInsets.only(top: 32),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null && _filteredResults.isEmpty) {
      return AnimatedSwitcher(
        duration: AppConstants.animationFast,
        child: _buildEmptyState(_errorMessage!, key: const ValueKey('empty-error')),
      );
    }

    if (_filteredResults.isEmpty && _fuzzySearchDone) {
      if (_rawResults.isNotEmpty) {
        return AnimatedSwitcher(
          duration: AppConstants.animationFast,
          child: _buildEmptyState(
            'All results are hidden by active filters.',
            key: const ValueKey('empty-filters'),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: AppConstants.animationFast,
      child: ListView.separated(
        key: ValueKey('results-list-${_filteredResults.length}'),
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _filteredResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final result = _filteredResults[index];
          final delay = index * 0.05;
          final animation = CurvedAnimation(
            parent: _staggerController,
            curve: Interval(
              math.min(delay, 0.6),
              math.min(delay + 0.3, 1.0),
              curve: Curves.easeOutCubic,
            ),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: _buildResultCard(result),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, {required Key key}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 36,
              color: AppColors.textTertiary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                height: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            if (_searchController.text !=
                '${widget.song.artist} ${widget.song.title}')
              TextButton.icon(
                onPressed: () {
                  _searchController.text =
                      '${widget.song.artist} ${widget.song.title}';
                  _doCustomSearch(_searchController.text);
                },
                icon: Icon(
                  LucideIcons.rotateCcw,
                  size: 14,
                  color: AppColors.accent,
                ),
                label: Text(
                  'Try original search',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_filterSynced || _filterPlain || _filterInstrumental)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _filterSynced = false;
                    _filterPlain = false;
                    _filterInstrumental = false;
                  });
                  _applyFilters();
                },
                icon: Icon(
                  Icons.filter_list_off,
                  size: 14,
                  color: AppColors.accent,
                ),
                label: Text(
                  'Clear filters',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(OnlineLyricsResult result) {
    final isExact = _exactMatch?.id == result.id;
    final durationMatch = _isDurationMatch(result);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : () => _openPreview(result),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        splashColor: AppColors.glassBackgroundStrong,
        child: AnimatedContainer(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isExact ? AppColors.glassBackgroundStrong : null,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: isExact
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.glassBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.trackName ?? '',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (durationMatch)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Duration Match',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade300,
                          ),
                        ),
                      ),
                    ),
                  if (result.instrumental)
                    _buildTypeChip('Inst', LucideIcons.music2),
                  if (!result.instrumental && result.hasSyncedLyrics)
                    _buildTypeChip('LRC', LucideIcons.clock3),
                  if (!result.instrumental && !result.hasSyncedLyrics)
                    _buildTypeChip('TXT', LucideIcons.fileText),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                result.artistName ?? '',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (result.albumName != null && result.albumName!.isNotEmpty)
                Text(
                  result.albumName!,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              if (result.duration != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDuration(
                      Duration(seconds: result.duration!.round())),
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 10,
                    color: AppColors.textTertiary.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (result.snippet != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    result.snippet!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (result.lineCount > 0)
                    _buildMetaChip('${result.lineCount} lines'),
                  const Spacer(),
                  Text(
                    'Tap to preview',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 10,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final result = _previewResult!;
    final lyrics = result.bestLyrics;
    final isSynced = result.hasSyncedLyrics;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isPreview = child.key == const ValueKey('preview-panel');
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: isPreview ? -1.0 : 1.0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: isPreview ? const Offset(0, 0.08) : const Offset(0, -0.04),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        key: const ValueKey('preview-panel'),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMarqueeText(
                          result.trackName ?? 'Unknown Track',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildMarqueeText(
                          '${result.artistName ?? ''}${result.albumName != null && result.albumName!.isNotEmpty ? ' · ${result.albumName}' : ''}',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _closePreview,
                    icon: Icon(LucideIcons.x,
                        size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.glassBackground,
                    ),
                  ),
                ],
              ),
            ),
            // Format info chips
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTypeChip(result.formatLabel,
                      isSynced ? LucideIcons.clock3 : LucideIcons.fileText),
                  if (result.lineCount > 0)
                    _buildTypeChip(
                        '${result.lineCount} lines', Icons.format_align_left),
                  if (result.duration != null)
                    _buildTypeChip(
                      _formatDuration(
                          Duration(seconds: result.duration!.round())),
                      LucideIcons.timer,
                    ),
                  if (_isDurationMatch(result))
                    _buildTypeChip(
                        'Duration Match', Icons.check_circle_outline),
                ],
              ),
            ),
            // Lyrics preview
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                    child: Scrollbar(
                      controller: _previewScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _previewScrollController,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          lyrics,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 13,
                            height: 1.7,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closePreview,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.glassBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : () => _saveResult(result),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        disabledBackgroundColor:
                            AppColors.accent.withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              'Save Lyrics',
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.background,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  // Marquee text widget that scrolls horizontally if text overflows
  Widget _buildMarqueeText(String text, {required TextStyle style}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);

        final overflows = textPainter.width > constraints.maxWidth;

        if (!overflows) {
          return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        return _MarqueeText(
          text: text,
          style: style,
          gap: 40,
          velocity: 28,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppConstants.animationFast,
              child: _isInitialLoading
                  ? _buildLoadingSection()
                  : _exactMatch != null
                      ? _buildExactMatchSection(_exactMatch!)
                      : const SizedBox.shrink(key: ValueKey('no-exact')),
            ),
            _buildFilterChips(),
            _buildSearchBar(),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1.0,
                      child: child,
                    ),
                  );
                },
                child: _previewResult != null
                    ? _buildPreviewPanel()
                    : _buildResultsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple marquee widget that scrolls text horizontally
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double gap;
  final double velocity;

  const _MarqueeText({
    required this.text,
    required this.style,
    this.gap = 40,
    this.velocity = 28,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  final _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startAfterLayout();
  }

  void _startAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      _textWidth = renderBox.size.width;
      final containerWidth = context.size?.width ?? _textWidth;
      if (_textWidth <= containerWidth) return;

      final distance = _textWidth + widget.gap;
      final duration = distance / widget.velocity;

      _controller.duration = Duration(milliseconds: (duration * 1000).round());

      _controller
        ..reset()
        ..repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: widget.style.fontSize != null
            ? widget.style.fontSize! * 1.4
            : 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = -_controller.value * (_textWidth + widget.gap);
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.text, key: _textKey, style: widget.style),
              SizedBox(width: widget.gap),
              Text(widget.text, style: widget.style),
            ],
          ),
        ),
      ),
    );
  }
}
