import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';

class SongMetadataSheet extends StatelessWidget {
  final Song song;
  const SongMetadataSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongMetadataSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 20,
                color: context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                'Song Metadata',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetadataRow(context, 'Title', song.title),
          _buildMetadataRow(context, 'Artist', song.artist),
          if (song.album != null)
            _buildMetadataRow(context, 'Album', song.album!),
          _buildMetadataRow(context, 'Duration', song.formattedDuration),
          _buildMetadataRow(
            context,
            'Format',
            song.isDsd
                ? '${song.fileType.toUpperCase()} (${song.dsdRateLabel})'
                : song.fileType.toUpperCase(),
          ),
          if (song.resolution != null && !song.isDsd)
            _buildMetadataRow(context, 'Resolution', song.resolution!),
          if (song.albumArtist != null)
            _buildMetadataRow(context, 'Album Artist', song.albumArtist!),
          if (song.genre != null)
            _buildMetadataRow(context, 'Genre', song.genre!),
          if (song.year != null)
            _buildMetadataRow(context, 'Year', song.year!.toString()),
          if (song.trackNumber != null)
            _buildMetadataRow(
              context,
              'Track',
              song.trackNumber!.toString(),
            ),
          if (song.discNumber != null)
            _buildMetadataRow(context, 'Disc', song.discNumber!.toString()),
          if (song.filePath != null)
            _buildMetadataRow(context, 'File Path', song.filePath!),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
