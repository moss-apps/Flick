import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/features/songs/widgets/song_actions_bottom_sheet.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _songRepository = SongRepository();
  List<Song> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (value.trim().isEmpty) {
      _results = [];
      _isSearching = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = value.trim();
      final results = await _songRepository.searchSongs(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navigationIndexProvider, (prev, next) {
      if (next == NavBarButton.search.pageIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      } else if (prev == NavBarButton.search.pageIndex) {
        _focusNode.unfocus();
      }
    });

    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 16,
                  color: context.adaptiveTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: TextStyle(
                    color: context.adaptiveTextTertiary,
                    fontFamily: 'ProductSans',
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    color: context.adaptiveTextSecondary,
                    size: 20,
                  ),
                  suffixIcon: hasQuery
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            color: context.adaptiveTextSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _controller.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(
              child: !hasQuery
                  ? _buildEmptyState(context)
                  : _isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.textTertiary,
                            strokeWidth: 2,
                          ),
                        )
                      : _results.isEmpty
                          ? _buildNoResults(context)
                          : _buildResults(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 48,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Search your library',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: context.adaptiveTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find songs by title, artist, or album',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 13,
              color: context.adaptiveTextTertiary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 48,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final song = _results[index];
        final album = song.album;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: CachedImageWidget(
                  imagePath: song.albumArt,
                  audioSourcePath: song.filePath,
                  fit: BoxFit.cover,
                  useThumbnail: true,
                  thumbnailWidth: 96,
                  thumbnailHeight: 96,
                  placeholder: const ColoredBox(
                    color: AppColors.surface,
                    child: Icon(
                      LucideIcons.music,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
                  ),
                  errorWidget: const ColoredBox(
                    color: AppColors.surface,
                    child: Icon(
                      LucideIcons.music,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: context.adaptiveTextPrimary,
            ),
          ),
          subtitle: Text(
            '${song.artist}${album != null && album.isNotEmpty ? ' · $album' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: context.adaptiveTextTertiary,
            ),
          ),
          onTap: () {
            ref.read(playerProvider.notifier).play(song, playlist: _results);
          },
          onLongPress: () {
            SongActionsBottomSheet.show(context, song);
          },
        );
      },
    );
  }
}
