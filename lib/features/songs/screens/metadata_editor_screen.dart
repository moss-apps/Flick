import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/metadata_editor_service.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:flick/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MetadataEditorScreen extends ConsumerStatefulWidget {
  final Song song;

  const MetadataEditorScreen({super.key, required this.song});

  @override
  ConsumerState<MetadataEditorScreen> createState() =>
      _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends ConsumerState<MetadataEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _albumArtistController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackNumberController;
  late TextEditingController _discNumberController;

  bool _isSaving = false;
  bool _hasChanges = false;
  String? _error;

  bool get _isEditable =>
      widget.song.filePath != null &&
      widget.song.startOffsetMs == null &&
      !widget.song.isExternal;

  @override
  void initState() {
    super.initState();
    final s = widget.song;
    _titleController = TextEditingController(text: s.title);
    _artistController = TextEditingController(text: s.artist);
    _albumController = TextEditingController(text: s.album ?? '');
    _albumArtistController = TextEditingController(text: s.albumArtist ?? '');
    _genreController = TextEditingController(text: s.genre ?? '');
    _yearController =
        TextEditingController(text: s.year?.toString() ?? '');
    _trackNumberController =
        TextEditingController(text: s.trackNumber?.toString() ?? '');
    _discNumberController =
        TextEditingController(text: s.discNumber?.toString() ?? '');

    for (final c in [
      _titleController,
      _artistController,
      _albumController,
      _albumArtistController,
      _genreController,
      _yearController,
      _trackNumberController,
      _discNumberController,
    ]) {
      c.addListener(() {
        final changed = _titleController.text != s.title ||
            _artistController.text != s.artist ||
            _albumController.text != (s.album ?? '') ||
            _albumArtistController.text != (s.albumArtist ?? '') ||
            _genreController.text != (s.genre ?? '') ||
            _yearController.text != (s.year?.toString() ?? '') ||
            _trackNumberController.text !=
                (s.trackNumber?.toString() ?? '') ||
            _discNumberController.text != (s.discNumber?.toString() ?? '');
        if (changed != _hasChanges) {
          setState(() => _hasChanges = changed);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackNumberController.dispose();
    _discNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final fields = rust_metadata.TagEditFields(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      artist: _artistController.text.trim().isNotEmpty
          ? _artistController.text.trim()
          : null,
      album: _albumController.text.trim().isNotEmpty
          ? _albumController.text.trim()
          : null,
      albumArtist: _albumArtistController.text.trim().isNotEmpty
          ? _albumArtistController.text.trim()
          : null,
      genre: _genreController.text.trim().isNotEmpty
          ? _genreController.text.trim()
          : null,
      year: int.tryParse(_yearController.text.trim()),
      trackNumber: int.tryParse(_trackNumberController.text.trim()),
      discNumber: int.tryParse(_discNumberController.text.trim()),
    );

    final success =
        await MetadataEditorService.instance.writeTags(widget.song, fields);

    if (!mounted) return;

    if (success) {
      ref.invalidate(songsProvider);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _error = 'Failed to save metadata.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptiveTextPrimary;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasChanges && !_isSaving) {
          _showDiscardDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.x, color: accent),
            onPressed: () {
              if (_hasChanges && !_isSaving) {
                _showDiscardDialog(context);
              } else {
                Navigator.of(context).pop(false);
              }
            },
          ),
          title: Text(
            'Edit Metadata',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          actions: [
            if (_isEditable)
              Padding(
                padding: const EdgeInsets.only(right: AppConstants.spacingSm),
                child: TextButton(
                  onPressed: _hasChanges && !_isSaving ? _save : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                            color: _hasChanges
                                ? AppColors.accent
                                : AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingSm,
            AppConstants.spacingLg,
            MediaQuery.of(context).padding.bottom + AppConstants.spacingXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditable) ...[
                Container(
                  padding:
                      const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.lock, size: 16,
                          color: AppColors.textTertiary),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: Text(
                          widget.song.isExternal
                              ? 'External songs cannot be edited'
                              : 'CUE sheet tracks cannot be edited',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
              ],
              if (_error != null) ...[
                Container(
                  padding:
                      const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Row(
                    children: [
Icon(LucideIcons.circleAlert,
                           size: 16, color: Colors.redAccent),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 13,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
              ],
              _buildField(context, 'Title', _titleController,
                  enabled: _isEditable),
              _buildField(context, 'Artist', _artistController,
                  enabled: _isEditable),
              _buildField(context, 'Album', _albumController,
                  enabled: _isEditable),
              _buildField(context, 'Album Artist', _albumArtistController,
                  enabled: _isEditable),
              _buildField(context, 'Genre', _genreController,
                  enabled: _isEditable),
              _buildField(context, 'Year', _yearController,
                  enabled: _isEditable, keyboardType: TextInputType.number),
              _buildField(context, 'Track #', _trackNumberController,
                  enabled: _isEditable, keyboardType: TextInputType.number),
              _buildField(context, 'Disc #', _discNumberController,
                  enabled: _isEditable, keyboardType: TextInputType.number),
              const SizedBox(height: AppConstants.spacingXl),
              _buildReadOnlyInfo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 15,
              color: enabled
                  ? context.adaptiveTextPrimary
                  : AppColors.textTertiary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled
                  ? AppColors.surfaceLight
                  : AppColors.surfaceLight.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm + 2,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: AppColors.glassBorderStrong),
        const SizedBox(height: AppConstants.spacingLg),
        Text(
          'File Information',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextSecondary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _buildInfoRow(context, 'Duration', widget.song.formattedDuration),
        _buildInfoRow(
            context, 'Format', widget.song.fileType.toUpperCase()),
        if (widget.song.resolution != null)
          _buildInfoRow(context, 'Resolution', widget.song.resolution!),
        if (widget.song.filePath != null)
          _buildInfoRow(context, 'File Path', widget.song.filePath!),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  void _showDiscardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        title: Text('Discard Changes?',
            style: TextStyle(
                fontFamily: 'ProductSans', color: context.adaptiveTextPrimary)),
        content: Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(
              fontFamily: 'ProductSans',
              color: context.adaptiveTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pop(false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}