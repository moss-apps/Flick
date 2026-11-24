import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/features/playlists/screens/playlist_cover_editor_screen.dart';
import 'package:flick/features/playlists/utils/artwork_edit_result.dart';
import 'package:flick/features/playlists/utils/playlist_cover_edit.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flick/features/player/widgets/share/share_template.dart';
import 'package:flick/features/player/widgets/share/share_cards/lyric_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/solid_color_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/minimal_share_card.dart';
import 'package:flick/features/player/widgets/share/share_cards/album_art_share_card.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/album_color_provider.dart';
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/gallery_save_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/english_l10n.dart';

class ShareBottomSheet extends ConsumerStatefulWidget {
  final Song song;

  const ShareBottomSheet({super.key, required this.song});

  @override
  ConsumerState<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<ShareBottomSheet> {
  static const double _cardWidth = 240;
  static const double _minTextScale = 0.8;
  static const double _maxTextScale = 1.4;
  static const double _textScaleStep = 0.1;

  int _selectedTemplate = 0;
  bool _isSharing = false;
  bool _isSaving = false;
  bool _editingArtwork = false;
  final GlobalKey _cardKey = GlobalKey();
  String? _resolvedAlbumArt;
  String? _currentLyric;
  bool _lyricAutoFit = true;
  double _lyricFontSize = 34;

  /// Per-layout text size for the title and artist. The lyric layout keeps its
  /// own fit controls for the lyric line.
  final List<double> _textScales = List<double>.filled(
    ShareTemplate.values.length,
    1,
  );

  /// Rendered artwork overrides, keyed by [ShareTemplate.index].
  final Map<int, ArtworkEditResult> _artworkEdits = <int, ArtworkEditResult>{};

  @override
  void initState() {
    super.initState();
    _resolveAlbumArt();
    _loadCurrentLyric();
  }

  @override
  void dispose() {
    for (final result in _artworkEdits.values) {
      unawaited(_deleteQuietly(result.path));
    }
    super.dispose();
  }

  Future<void> _resolveAlbumArt() async {
    final song = widget.song;
    if (song.albumArt != null &&
        song.albumArt!.isNotEmpty &&
        await File(song.albumArt!).exists()) {
      if (mounted) setState(() => _resolvedAlbumArt = song.albumArt);
      return;
    }
    if (song.filePath != null && song.filePath!.isNotEmpty) {
      final path = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: song.albumArt,
        audioSourcePath: song.filePath!,
      );
      if (mounted && path != null) setState(() => _resolvedAlbumArt = path);
    }
  }

  Future<void> _loadCurrentLyric() async {
    final song = widget.song;
    final lyricsService = LyricsService();
    final data = await lyricsService.loadLyricsForSong(song);
    if (data == null || !mounted) return;

    if (data.isSynchronized && data.lines.isNotEmpty) {
      final playerService = PlayerService();
      final pos = playerService.positionNotifier.value;
      final idx = lyricsService.findCurrentLineIndex(data, pos);
      final line = idx >= 0 && idx < data.lines.length ? data.lines[idx] : null;
      if (mounted && line != null) {
        setState(() => _currentLyric = line.text.trim());
      }
    } else if (data.lines.isNotEmpty) {
      final line = data.lines.firstWhere(
        (l) => l.text.trim().isNotEmpty,
        orElse: () => data.lines.first,
      );
      if (mounted) setState(() => _currentLyric = line.text.trim());
    }
  }

  ShareTemplate get _template => ShareTemplate.values[_selectedTemplate];

  String? get _editedArtworkPath => _artworkEdits[_selectedTemplate]?.path;

  double _artworkAspect(ShareTemplate template) => switch (template) {
    ShareTemplate.solidColor || ShareTemplate.minimal => 1,
    ShareTemplate.lyric || ShareTemplate.albumArt => 4 / 5,
  };

  Widget _buildCard(int index) {
    final song = widget.song;
    final dominantColor = ref.watch(albumDominantColorSyncProvider);
    final template = ShareTemplate.values[index];
    final edited = _artworkEdits[index]?.path;
    final textScale = _textScales[index];

    switch (template) {
      case ShareTemplate.lyric:
        return LyricShareCard(
          song: song,
          lyricLine: _currentLyric,
          albumArtPath: edited ?? _resolvedAlbumArt,
          fontSizeOverride: _lyricAutoFit ? null : _lyricFontSize,
          textScale: textScale,
        );
      case ShareTemplate.solidColor:
        return SolidColorShareCard(
          song: song,
          dominantColor: dominantColor,
          albumArtPath: _resolvedAlbumArt,
          coverArtPath: edited,
          textScale: textScale,
        );
      case ShareTemplate.minimal:
        return MinimalShareCard(
          song: song,
          albumArtPath: _resolvedAlbumArt,
          coverArtPath: edited,
          textScale: textScale,
        );
      case ShareTemplate.albumArt:
        return AlbumArtShareCard(
          song: song,
          albumArtPath: edited ?? _resolvedAlbumArt,
          textScale: textScale,
        );
    }
  }

  Future<void> _editArtwork() async {
    final sourcePath = _resolvedAlbumArt;
    if (sourcePath == null || _editingArtwork) return;

    final index = _selectedTemplate;
    final existing = _artworkEdits[index];
    final aspect = _artworkAspect(_template);
    final strings = l10n;
    setState(() => _editingArtwork = true);

    try {
      final result = await NavigationHelper.pushFade<ArtworkEditResult>(
        context,
        (_) => PlaylistCoverEditorScreen(
          sourcePath: sourcePath,
          aspectRatio: aspect,
          initialEdit: existing?.edit ?? const PlaylistCoverEdit(),
          initialCrop: existing?.crop,
          maxOutput: 1440,
          title: strings.editArtwork,
          saveLabel: strings.apply,
        ),
      );
      if (!mounted || result == null) return;

      final previousPath = existing?.path;
      setState(() => _artworkEdits[index] = result);
      if (previousPath != null && previousPath != result.path) {
        await _deleteQuietly(previousPath);
      }
    } finally {
      if (mounted) setState(() => _editingArtwork = false);
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary editor output; the OS will eventually clean it up.
    }
  }

  Future<Uint8List?> _captureCard() async {
    // Decode the artwork before painting so a quick tap never exports a blank
    // or stale cover while Android is still reading the file.
    final artworkPaths = <String>{?_resolvedAlbumArt, ?_editedArtworkPath};
    for (final path in artworkPaths) {
      if (!mounted) return null;
      if (!await File(path).exists()) continue;
      await precacheImage(FileImage(File(path)), context, onError: (_, _) {});
    }
    if (!mounted) return null;
    await WidgetsBinding.instance.endOfFrame;

    final cardContext = _cardKey.currentContext;
    if (cardContext == null) return null;
    final renderObject = cardContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    if (renderObject.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final bytes = await _captureCard();
      if (!mounted || bytes == null) return;

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/flick_share_${widget.song.id}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: l10n.listeningToByOnFlick(widget.song.title, widget.song.artist),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlickSnackBar(
          SnackBar(content: Text(l10n.englishForFilipino.shareFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final bytes = await _captureCard();
      if (!mounted || bytes == null) return;

      final galleryService = GallerySaveService();
      await galleryService.saveImage(
        bytes: bytes,
        fileName:
            'flick_share_${widget.song.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showFlickSnackBar(
          SnackBar(content: Text(l10n.englishForFilipino.savedToGallery)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlickSnackBar(
          SnackBar(
            content: Text(
              e is GallerySaveException
                  ? e.message
                  : l10n.englishForFilipino.failedToSave,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _stepTextScale(int direction) {
    final current = _textScales[_selectedTemplate];
    final next = (current + direction * _textScaleStep).clamp(
      _minTextScale,
      _maxTextScale,
    );
    setState(() {
      _textScales[_selectedTemplate] = double.parse(next.toStringAsFixed(1));
    });
  }

  Widget _buildTextSizeControls() {
    if (_template == ShareTemplate.lyric) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SizePill(
            icon: LucideIcons.minus,
            dimmed: _lyricAutoFit,
            onTap: () => setState(() {
              _lyricAutoFit = false;
              _lyricFontSize = (_lyricFontSize - 2)
                  .clamp(14.0, 34.0)
                  .toDouble();
            }),
          ),
          const SizedBox(width: 6),
          _SizePill(
            label: l10n.auto,
            active: _lyricAutoFit,
            onTap: () => setState(() => _lyricAutoFit = true),
          ),
          const SizedBox(width: 6),
          _SizePill(
            icon: LucideIcons.plus,
            dimmed: _lyricAutoFit,
            onTap: () => setState(() {
              _lyricAutoFit = false;
              _lyricFontSize = (_lyricFontSize + 2)
                  .clamp(14.0, 34.0)
                  .toDouble();
            }),
          ),
        ],
      );
    }

    final scale = _textScales[_selectedTemplate];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SizePill(
          icon: LucideIcons.minus,
          dimmed: scale <= _minTextScale,
          onTap: () => _stepTextScale(-1),
        ),
        const SizedBox(width: 6),
        _SizePill(
          label: l10n.auto,
          active: scale == 1,
          onTap: () => setState(() => _textScales[_selectedTemplate] = 1),
        ),
        const SizedBox(width: 6),
        _SizePill(
          icon: LucideIcons.plus,
          dimmed: scale >= _maxTextScale,
          onTap: () => _stepTextScale(1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ShareTemplate.values;
    final canEditArtwork = _resolvedAlbumArt != null;

    return AppBottomSheetSurface(
      scrollable: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.share2, color: AppColors.accent, size: 22),
              const SizedBox(width: 12),
              Text(
                l10n.share,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final isSelected = index == _selectedTemplate;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTemplate = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _cardWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : AppColors.glassBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      key: index == _selectedTemplate ? _cardKey : null,
                      child: _buildCard(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                templates[_selectedTemplate].label(l10n),
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.textSize,
                    style: const TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTextSizeControls(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEditArtwork)
                _ActionButton(
                  icon: LucideIcons.crop,
                  label: l10n.editArtwork,
                  isLoading: _editingArtwork,
                  onTap: _editArtwork,
                ),
              _ActionButton(
                icon: LucideIcons.download,
                label: l10n.save,
                isLoading: _isSaving,
                onTap: _saveToGallery,
              ),
              _ActionButton(
                icon: LucideIcons.share2,
                label: l10n.share,
                isLoading: _isSharing,
                onTap: _share,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.textPrimary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SizePill extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool active;
  final bool dimmed;
  final VoidCallback onTap;

  const _SizePill({
    this.icon,
    this.label,
    this.active = false,
    this.dimmed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.accent
        : (dimmed ? AppColors.textTertiary : AppColors.textPrimary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.glassBorder,
          ),
        ),
        child: icon != null
            ? Icon(icon, color: color, size: 16)
            : Text(
                label!,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
      ),
    );
  }
}
