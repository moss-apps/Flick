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
        maxHeightRatio: 0.88,
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

class _OnlineLyricsSearchSheetState extends State<OnlineLyricsSearchSheet> {
  final OnlineLyricsService _onlineService = OnlineLyricsService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isInitialLoading = true;
  bool _isSearching = false;
  bool _isSaving = false;
  OnlineLyricsResult? _exactMatch;
  List<OnlineLyricsResult> _searchResults = [];
  String? _errorMessage;
  bool _fuzzySearchDone = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = '${widget.song.artist} ${widget.song.title}';
    _doExactSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _doExactSearch() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _exactMatch = null;
      _fuzzySearchDone = false;
      _searchResults = [];
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
      _searchResults = results;
      _isSearching = false;
      _fuzzySearchDone = true;
      if (results.isEmpty) {
        _errorMessage = 'No lyrics found online for this song.';
      }
    });
  }

  Future<void> _doCustomSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final results = await _onlineService.search(query: query);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
      if (results.isEmpty) {
        _errorMessage = 'No results found for "$query".';
      }
    });
  }

  Future<void> _saveResult(OnlineLyricsResult result) async {
    setState(() => _isSaving = true);

    final isSynced = result.hasSyncedLyrics;
    final content = isSynced ? result.syncedLyrics! : result.plainLyrics!;
    final fileName =
        isSynced ? 'online.lrc' : 'online.txt';

    await widget.lyricsService.importLyricsForSong(
      song: widget.song,
      fileName: fileName,
      content: content,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
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
            if (_isInitialLoading) _buildLoadingSection(),
            if (!_isInitialLoading && _exactMatch != null)
              _buildExactMatchSection(_exactMatch!),
            _buildSearchBar(),
            const SizedBox(height: 12),
            Expanded(
              child: _buildResultsList(),
            ),
          ],
        ),
      ),
    );
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
          icon: Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildExactMatchSection(OnlineLyricsResult result) {
    final textColor = AppColors.textPrimary;
    final secondaryColor = AppColors.textSecondary;
    final subtitleColor = Colors.white.withValues(alpha: 0.56);

    return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveResult(result),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
                      'Use These Lyrics',
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
            ? IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  _searchController.clear();
                  _doCustomSearch(_searchController.text);
                },
                color: AppColors.textSecondary,
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
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_errorMessage != null && _searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty && _fuzzySearchDone) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(OnlineLyricsResult result) {
    final isExact = _exactMatch?.id == result.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : () => _saveResult(result),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        splashColor: AppColors.glassBackgroundStrong,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isExact ? AppColors.glassBackgroundStrong : null,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color:
                  isExact ? AppColors.accent.withValues(alpha: 0.18) : AppColors.glassBorder,
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
              if (result.albumName != null &&
                  result.albumName!.isNotEmpty)
                Text(
                  result.albumName!,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
