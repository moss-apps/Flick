import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/shuffle_mode.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/features/player/widgets/shuffle_mode_sheet.dart';
import 'package:flick/features/player/widgets/loop_mode_sheet.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class CompactPlayerInfoLayout extends StatefulWidget {
  final Song song;
  final Object heroTag;
  final PlayerService playerService;
  final FavoritesService favoritesService;

  const CompactPlayerInfoLayout({
    super.key,
    required this.song,
    required this.heroTag,
    required this.playerService,
    required this.favoritesService,
  });

  @override
  State<CompactPlayerInfoLayout> createState() =>
      _CompactPlayerInfoLayoutState();
}

class _CompactPlayerInfoLayoutState extends State<CompactPlayerInfoLayout> {
  @override
  Widget build(BuildContext context) {
    final isVeryCompact = context.isCompact || context.screenHeight < 600;
    final albumArtSize = isVeryCompact
        ? (MediaQuery.sizeOf(context).height * 0.20).clamp(120.0, 160.0)
        : (MediaQuery.sizeOf(context).height * 0.25).clamp(140.0, 200.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(12.0, 16.0, 20.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: widget.heroTag,
                child: Container(
                  width: albumArtSize,
                  height: albumArtSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      context.responsive(14.0, 18.0, 22.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: context.responsive(12.0, 16.0, 20.0),
                        offset: Offset(0, context.responsive(6.0, 8.0, 10.0)),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      context.responsive(14.0, 18.0, 22.0),
                    ),
                    child: CachedImageWidget(
                      imagePath: widget.song.albumArt,
                      audioSourcePath: widget.song.filePath,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: AppColors.glassBackgroundStrong,
                        child: Icon(
                          LucideIcons.music,
                          size: context.responsive(28.0, 32.0, 36.0),
                          color: AppColors.textTertiary,
                        ),
                      ),
                      errorWidget: Container(
                        color: AppColors.glassBackgroundStrong,
                        child: Icon(
                          LucideIcons.music,
                          size: context.responsive(28.0, 32.0, 36.0),
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.responsive(12.0, 16.0, 20.0)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: isVeryCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: context.responsiveText(
                          context.responsive(15.0, 16.0, 17.0),
                        ),
                        fontWeight: FontWeight.bold,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
                    Text(
                      widget.song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: context.responsiveText(
                          context.responsive(12.0, 13.0, 13.5),
                        ),
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                    SizedBox(height: context.responsive(6.0, 8.0, 10.0)),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.responsive(4.0, 5.0, 6.0),
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.adaptiveTextTertiary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            widget.song.fileType,
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: context.responsive(8.0, 9.0, 9.5),
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextSecondary,
                            ),
                          ),
                        ),
                        if (widget.song.resolution != null) ...[
                          SizedBox(width: context.responsive(4.0, 5.0, 6.0)),
                          Flexible(
                            child: Text(
                              widget.song.resolution!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: context.responsive(8.0, 9.0, 9.5),
                                color: context.adaptiveTextTertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.responsive(12.0, 16.0, 20.0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<ShuffleMode>(
                valueListenable: widget.playerService.shuffleModeNotifier,
                builder: (context, shuffleMode, _) {
                  final isActive = shuffleMode.isActive;
                  final icon = switch (shuffleMode) {
                    ShuffleMode.categories => LucideIcons.layers,
                    ShuffleMode.random => LucideIcons.dices,
                    _ => LucideIcons.shuffle,
                  };
                  return GestureDetector(
                    onTap: () {
                      widget.playerService.toggleShuffle();
                      final next = widget.playerService.shuffleModeNotifier.value;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text('Shuffle: ${next.label}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ));
                    },
                    onLongPress: () {
                      ShuffleModeSheet.show(context, widget.playerService);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(context.responsive(6.0, 8.0, 10.0)),
                      child: Icon(
                        icon,
                        color: isActive
                            ? context.adaptiveAccent
                            : context.adaptiveTextTertiary,
                        size: context.responsive(18.0, 20.0, 22.0),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: context.responsive(20.0, 24.0, 28.0)),
              ValueListenableBuilder<LoopMode>(
                valueListenable: widget.playerService.loopModeNotifier,
                builder: (context, loopMode, _) {
                  final icon = LoopModeSheet.iconFor(loopMode);
                  final isActive = loopMode != LoopMode.off;
                  final color = isActive
                      ? context.adaptiveAccent
                      : context.adaptiveTextTertiary;
                  return GestureDetector(
                    onTap: () {
                      widget.playerService.toggleLoopMode();
                      final next = widget.playerService.loopModeNotifier.value;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text('Repeat: ${next.label}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ));
                    },
                    onLongPress: () {
                      LoopModeSheet.show(context, widget.playerService);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(context.responsive(6.0, 8.0, 10.0)),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            icon,
                            color: color,
                            size: context.responsive(18.0, 20.0, 22.0),
                          ),
                          if (loopMode == LoopMode.all)
                            Positioned(
                              bottom: -4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: context.adaptiveAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: context.responsive(20.0, 24.0, 28.0)),
              FutureBuilder<bool>(
                future: widget.favoritesService.isFavorite(widget.song.id),
                builder: (context, snapshot) {
                  final isFavorite = snapshot.data ?? false;
                  return IconButton(
                    onPressed: () async {
                      final newState = await widget.favoritesService
                          .toggleFavorite(widget.song.id);
                      setState(() {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              newState
                                  ? 'Added to favorites'
                                  : 'Removed from favorites',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    padding: EdgeInsets.all(context.responsive(6.0, 8.0, 10.0)),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite
                          ? Colors.red
                          : context.adaptiveTextTertiary,
                      size: context.responsive(18.0, 20.0, 22.0),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
