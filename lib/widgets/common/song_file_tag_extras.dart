import 'package:flutter/material.dart';

import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/metadata_editor_service.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:flick/l10n/english_l10n.dart';

typedef SongTagReader =
    Future<rust_metadata.TagReadResult?> Function(String path);

/// Read-only metadata rows for tags that live in the file but not in the
/// library database: comment, full recording date, copyright, and
/// label/organization. Reads once per sheet opening and hides itself when the
/// file is unavailable or has none of these tags.
class SongFileTagExtras extends StatefulWidget {
  final Song song;

  /// Test seam; defaults to [MetadataEditorService.readTags].
  final SongTagReader? readTags;

  const SongFileTagExtras({super.key, required this.song, this.readTags});

  @override
  State<SongFileTagExtras> createState() => _SongFileTagExtrasState();
}

class _SongFileTagExtrasState extends State<SongFileTagExtras> {
  Future<rust_metadata.TagReadResult?>? _tags;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SongFileTagExtras oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_readablePath(oldWidget.song) != _readablePath(widget.song)) {
      _load();
    }
  }

  String? _readablePath(Song song) {
    final path = song.filePath;
    if (path == null ||
        path.isEmpty ||
        song.startOffsetMs != null ||
        song.isExternal ||
        song.isNetworkSource) {
      return null;
    }
    return path;
  }

  void _load() {
    final path = _readablePath(widget.song);
    if (path == null) {
      _tags = null;
      return;
    }
    _tags = (widget.readTags ?? MetadataEditorService.instance.readTags)(path);
  }

  @override
  Widget build(BuildContext context) {
    final future = _tags;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<rust_metadata.TagReadResult?>(
      future: future,
      builder: (context, snapshot) {
        // FutureBuilder retains the previous data while a new future waits.
        // Never show one file's tags under another song's metadata.
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final tags = snapshot.data;
        if (tags == null) return const SizedBox.shrink();

        final comment = tags.comment?.trim();
        final date = tags.date?.trim();
        final copyright = tags.copyright?.trim();
        final label = tags.label?.trim();
        final hasComment = comment != null && comment.isNotEmpty;
        // A bare "2024" recording date duplicates the Year row above.
        final hasFullDate = date != null && date.isNotEmpty && date.length > 4;
        final hasCopyright = copyright != null && copyright.isNotEmpty;
        final hasLabel = label != null && label.isNotEmpty;
        if (!hasComment && !hasFullDate && !hasCopyright && !hasLabel) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasComment) _buildRow(context, l10n.comment, comment),
            if (hasFullDate) _buildRow(context, l10n.date, date),
            if (hasCopyright) _buildRow(context, l10n.copyright, copyright),
            if (hasLabel) _buildRow(context, l10n.labelOrganization, label),
          ],
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
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
                fontFamily: 'GoogleSansFlex',
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
                fontFamily: 'GoogleSansFlex',
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
