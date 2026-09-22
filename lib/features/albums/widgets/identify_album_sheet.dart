import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/services/apple_music/album_identification_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

/// Batch-identifies an album against Apple Music and writes the result to the
/// library. The main entry point for files that carry no usable tags.
class IdentifyAlbumSheet extends ConsumerStatefulWidget {
  const IdentifyAlbumSheet({
    super.key,
    required this.songs,
    this.initialArtist,
    this.initialAlbum,
  });

  final List<Song> songs;
  final String? initialArtist;
  final String? initialAlbum;

  static Future<AlbumIdentificationApplyResult?> show(
    BuildContext context, {
    required List<Song> songs,
    String? initialArtist,
    String? initialAlbum,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await showModalBottomSheet<AlbumIdentificationApplyResult>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AppBottomSheetSurface(
          maxHeightRatio: 0.95,
          child: IdentifyAlbumSheet(
            songs: songs,
            initialArtist: initialArtist,
            initialAlbum: initialAlbum,
          ),
        ),
      ),
    );

    if (!context.mounted || messenger == null || result == null) {
      return result;
    }
    final artworkNote = result.artworkApplied ? ' and artwork' : '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Identified ${result.updatedSongs} '
            '${result.updatedSongs == 1 ? 'song' : 'songs'}$artworkNote.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return result;
  }

  @override
  ConsumerState<IdentifyAlbumSheet> createState() => _IdentifyAlbumSheetState();
}

class _IdentifyAlbumSheetState extends ConsumerState<IdentifyAlbumSheet> {
  final AlbumIdentificationService _service =
      AlbumIdentificationService.instance;

  late final TextEditingController _artistController;
  late final TextEditingController _albumController;

  List<AlbumIdentificationCandidate> _candidates = const [];
  AlbumIdentificationCandidate? _selected;
  bool _isSearching = false;
  bool _isApplying = false;
  String? _error;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    final seed = AlbumIdentificationService.deriveFolderSeeds(widget.songs);
    _artistController = TextEditingController(
      text: _seedValue(widget.initialArtist, seed.artist),
    );
    _albumController = TextEditingController(
      text: _seedValue(widget.initialAlbum, seed.album),
    );
    _search();
  }

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  String _seedValue(String? provided, String derived) {
    if (!AlbumIdentificationService.isUnknownName(provided)) {
      return provided!.trim();
    }
    return derived;
  }

  Future<void> _search() async {
    final token = ++_searchToken;
    setState(() {
      _isSearching = true;
      _error = null;
      _selected = null;
    });

    try {
      final candidates = await _service.findCandidates(
        songs: widget.songs,
        artist: _artistController.text,
        album: _albumController.text,
      );
      if (!mounted || token != _searchToken) return;
      setState(() {
        _candidates = candidates;
        _selected = candidates.isEmpty ? null : candidates.first;
      });
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _candidates = const [];
        _error = 'Apple Music lookup failed. Check your connection.';
      });
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _apply() async {
    final selected = _selected;
    if (selected == null || _isApplying) return;
    setState(() => _isApplying = true);

    final result = await _service.applyCandidate(selected);
    if (!mounted) return;
    ref.invalidate(songsProvider);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppConstants.spacingMd),
              _buildHeader(context),
              const SizedBox(height: AppConstants.spacingMd),
              _buildSeedFields(context),
              const SizedBox(height: AppConstants.spacingLg),
              _buildResults(context),
              const SizedBox(height: AppConstants.spacingLg),
              _buildApplyButton(context),
              const SizedBox(height: AppConstants.spacingLg),
            ],
          ),
        ),
        if (_isApplying)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorderStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Identify Album',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Match ${widget.songs.length} '
                '${widget.songs.length == 1 ? 'file' : 'files'} by artist, '
                'album and track length',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 14,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isSearching || _isApplying ? null : _search,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          color: context.adaptiveTextSecondary,
          tooltip: 'Search Again',
        ),
      ],
    );
  }

  Widget _buildSeedFields(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildField(
            context,
            controller: _artistController,
            label: 'Artist',
            icon: LucideIcons.user,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _buildField(
            context,
            controller: _albumController,
            label: 'Album',
            icon: LucideIcons.disc3,
            onSubmitted: (_) => _search(),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.search,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: 'ProductSans',
        fontSize: 14,
        color: context.adaptiveTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 13,
          color: context.adaptiveTextTertiary,
        ),
        prefixIcon: Icon(icon, size: 16, color: context.adaptiveTextTertiary),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingSm,
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_isSearching && _candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spacingLg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
        child: Text(
          _error!,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 14,
            color: context.adaptiveTextSecondary,
          ),
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
        child: Text(
          'No Apple Music release found. Try editing the artist or album '
          'name and searching again.',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 14,
            color: context.adaptiveTextSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matches',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.adaptiveTextPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        for (final candidate in _candidates) ...[
          _buildCandidateCard(context, candidate),
          const SizedBox(height: AppConstants.spacingSm),
        ],
      ],
    );
  }

  Widget _buildCandidateCard(
    BuildContext context,
    AlbumIdentificationCandidate candidate,
  ) {
    final selected = identical(candidate, _selected);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isApplying ? null : () => setState(() => _selected = candidate),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.glassBorder,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    child: CachedImageWidget(
                      imagePath: candidate.match.artworkUrl,
                      width: 52,
                      height: 52,
                      placeholder: CachedImageWidget.defaultPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.match.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _candidateSubtitle(candidate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 13,
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  _buildConfidenceBadge(context, candidate),
                ],
              ),
              if (selected && candidate.suggestions.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingSm),
                Divider(color: AppColors.glassBorder, height: 1),
                const SizedBox(height: AppConstants.spacingSm),
                for (final suggestion in candidate.suggestions)
                  _buildSuggestionRow(context, suggestion),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _candidateSubtitle(AlbumIdentificationCandidate candidate) {
    final year = candidate.year;
    final parts = [
      candidate.match.artistName,
      if (year != null) '$year',
      if (candidate.match.trackCount != null)
        '${candidate.match.trackCount} tracks',
    ];
    return parts.where((part) => part.isNotEmpty).join(' • ');
  }

  Widget _buildConfidenceBadge(
    BuildContext context,
    AlbumIdentificationCandidate candidate,
  ) {
    final high = candidate.confidence >= 0.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: high
            ? AppColors.accent.withValues(alpha: 0.15)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: high ? AppColors.accent : AppColors.glassBorder,
        ),
      ),
      child: Text(
        candidate.matchedLabel,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: high ? AppColors.accent : context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(
    BuildContext context,
    AlbumIdentificationSuggestion suggestion,
  ) {
    final track = suggestion.track;
    final trackLabel = track?.trackNumber == null
        ? null
        : '${track!.trackNumber}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXs),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              trackLabel ?? '–',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: track == null
                    ? context.adaptiveTextTertiary
                    : context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.trackName ?? 'No match found',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 13,
                    color: track == null
                        ? context.adaptiveTextTertiary
                        : context.adaptiveTextPrimary,
                  ),
                ),
                if (track != null && track.trackName != suggestion.song.title)
                  Text(
                    'was: ${suggestion.song.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 11,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (suggestion.durationDeltaMs != null) ...[
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              _deltaLabel(suggestion.durationDeltaMs!),
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 11,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _deltaLabel(int deltaMs) {
    final seconds = (deltaMs / 1000).toStringAsFixed(1);
    return '±${seconds}s';
  }

  Widget _buildApplyButton(BuildContext context) {
    final selected = _selected;
    final enabled = selected != null && !_isApplying && !_isSearching;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _apply : null,
        icon: const Icon(LucideIcons.check, size: 18),
        label: Text(
          selected == null
              ? 'Select a release'
              : 'Apply to ${selected.suggestions.length} '
                    '${selected.suggestions.length == 1 ? 'song' : 'songs'}',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
        ),
      ),
    );
  }
}
