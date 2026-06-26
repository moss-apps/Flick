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

  late FocusNode _titleFocus;
  bool _isSaving = false;
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

    _titleFocus = FocusNode();

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
        if (mounted) setState(() {});
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
    _titleFocus.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final s = widget.song;
    return _titleController.text != s.title ||
        _artistController.text != s.artist ||
        _albumController.text != (s.album ?? '') ||
        _albumArtistController.text != (s.albumArtist ?? '') ||
        _genreController.text != (s.genre ?? '') ||
        _yearController.text != (s.year?.toString() ?? '') ||
        _trackNumberController.text != (s.trackNumber?.toString() ?? '') ||
        _discNumberController.text != (s.discNumber?.toString() ?? '');
  }

  String? _yearError() {
    final t = _yearController.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 1 || n > 9999) return 'Enter a year (1–9999)';
    return null;
  }

  String? _trackError() => _positiveIntError(_trackNumberController, 'track');
  String? _discError() => _positiveIntError(_discNumberController, 'disc');

  String? _positiveIntError(TextEditingController c, String label) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0) return 'Enter a valid $label number';
    return null;
  }

  bool get _hasInvalidFields =>
      _yearError() != null || _trackError() != null || _discError() != null;

  Future<void> _save() async {
    if (!_hasChanges || _isSaving || _hasInvalidFields) return;
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

    final result =
        await MetadataEditorService.instance.writeTags(widget.song, fields);

    if (!mounted) return;

    if (result.saved) {
      final messenger = ScaffoldMessenger.of(context);
      ref.invalidate(songsProvider);
      Navigator.of(context).pop(true);
      if (result.verified) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Saved and verified'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Saved (verification pending)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      setState(() {
        _isSaving = false;
        _error = result.message ?? 'Failed to save metadata.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptiveTextPrimary;
    final canSave =
        _isEditable && _hasChanges && !_isSaving && !_hasInvalidFields;

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
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingSm,
              AppConstants.spacingLg,
              AppConstants.spacingXl + AppConstants.spacingXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditable) ...[
                  _buildLockBanner(context),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (_error != null) ...[
                  _buildErrorBanner(context),
                  const SizedBox(height: AppConstants.spacingMd),
                ],
                _buildField(context, 'Title', _titleController,
                    focusNode: _titleFocus,
                    enabled: _isEditable && !_isSaving),
                _buildField(context, 'Artist', _artistController,
                    enabled: _isEditable && !_isSaving),
                _buildField(context, 'Album', _albumController,
                    enabled: _isEditable && !_isSaving),
                _buildField(context, 'Album Artist', _albumArtistController,
                    enabled: _isEditable && !_isSaving),
                _buildField(context, 'Genre', _genreController,
                    enabled: _isEditable && !_isSaving),
                _buildField(context, 'Year', _yearController,
                    enabled: _isEditable && !_isSaving,
                    keyboardType: TextInputType.number,
                    errorText: _yearError()),
                _buildField(context, 'Track #', _trackNumberController,
                    enabled: _isEditable && !_isSaving,
                    keyboardType: TextInputType.number,
                    errorText: _trackError()),
                _buildField(context, 'Disc #', _discNumberController,
                    enabled: _isEditable && !_isSaving,
                    keyboardType: TextInputType.number,
                    errorText: _discError()),
                const SizedBox(height: AppConstants.spacingXl),
                _buildReadOnlyInfo(context),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _isEditable ? _buildSaveBar(context, canSave) : null,
      ),
    );
  }

  Widget _buildLockBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 16, color: AppColors.textTertiary),
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
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 16, color: Colors.redAccent),
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
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
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
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: label == 'Title' ? TextInputAction.next : null,
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
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              errorText: errorText,
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              errorStyle: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 11,
                color: Colors.redAccent,
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

  Widget _buildSaveBar(BuildContext context, bool canSave) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingSm,
          AppConstants.spacingLg,
          AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 1),
          ),
        ),
        child: AnimatedSize(
          duration: AppConstants.animationFast,
          alignment: Alignment.center,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: canSave ? _save : null,
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
                padding: EdgeInsets.zero,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.background),
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
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
