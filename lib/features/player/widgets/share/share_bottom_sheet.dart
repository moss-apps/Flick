import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flick/core/theme/app_colors.dart';
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

class ShareBottomSheet extends ConsumerStatefulWidget {
  final Song song;

  const ShareBottomSheet({super.key, required this.song});

  @override
  ConsumerState<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<ShareBottomSheet> {
  int _selectedTemplate = 0;
  bool _isSharing = false;
  bool _isSaving = false;
  final GlobalKey _cardKey = GlobalKey();
  String? _resolvedAlbumArt;
  String? _currentLyric;
  bool _lyricAutoFit = true;
  double _lyricFontSize = 34;
  static const double _cardWidth = 240;

  @override
  void initState() {
    super.initState();
    _resolveAlbumArt();
    _loadCurrentLyric();
  }

  Future<void> _resolveAlbumArt() async {
    final song = widget.song;
    if (song.albumArt != null && song.albumArt!.isNotEmpty && await File(song.albumArt!).exists()) {
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
      if (mounted && line != null) setState(() => _currentLyric = line.text.trim());
    } else if (data.lines.isNotEmpty) {
      final line = data.lines.firstWhere(
        (l) => l.text.trim().isNotEmpty,
        orElse: () => data.lines.first,
      );
      if (mounted) setState(() => _currentLyric = line.text.trim());
    }
  }

  Widget _buildCard(int index) {
    final song = widget.song;
    final dominantColor = ref.watch(albumDominantColorSyncProvider);

    switch (ShareTemplate.values[index]) {
      case ShareTemplate.lyric:
        return LyricShareCard(
          song: song,
          lyricLine: _currentLyric,
          albumArtPath: _resolvedAlbumArt,
          fontSizeOverride: _lyricAutoFit ? null : _lyricFontSize,
        );
      case ShareTemplate.solidColor:
        return SolidColorShareCard(song: song, dominantColor: dominantColor, albumArtPath: _resolvedAlbumArt);
      case ShareTemplate.minimal:
        return MinimalShareCard(song: song, albumArtPath: _resolvedAlbumArt);
      case ShareTemplate.albumArt:
        return AlbumArtShareCard(song: song, albumArtPath: _resolvedAlbumArt);
    }
  }

  Future<Uint8List?> _captureCard() async {
    await Future.delayed(const Duration(milliseconds: 64));
    final context = _cardKey.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
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
        text: 'Listening to ${widget.song.title} by ${widget.song.artist} on Flick',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
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
        fileName: 'flick_share_${widget.song.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is GallerySaveException ? e.message : 'Failed to save')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildLyricSizeControls() {
    if (ShareTemplate.values[_selectedTemplate] != ShareTemplate.lyric) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SizePill(
          icon: LucideIcons.minus,
          dimmed: _lyricAutoFit,
          onTap: () => setState(() {
            _lyricAutoFit = false;
            _lyricFontSize =
                (_lyricFontSize - 2).clamp(14.0, 34.0).toDouble();
          }),
        ),
        const SizedBox(width: 6),
        _SizePill(
          label: 'Auto',
          active: _lyricAutoFit,
          onTap: () => setState(() => _lyricAutoFit = true),
        ),
        const SizedBox(width: 6),
        _SizePill(
          icon: LucideIcons.plus,
          dimmed: _lyricAutoFit,
          onTap: () => setState(() {
            _lyricAutoFit = false;
            _lyricFontSize =
                (_lyricFontSize + 2).clamp(14.0, 34.0).toDouble();
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ShareTemplate.values;

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
                'Share',
                style: TextStyle(
                  fontFamily: 'ProductSans',
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
                        color: isSelected ? Colors.white : AppColors.glassBorder,
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
          Row(
            children: [
              Text(
                templates[_selectedTemplate].label,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _buildLyricSizeControls(),
              const Spacer(),
              _ActionButton(
                icon: LucideIcons.download,
                label: 'Save',
                isLoading: _isSaving,
                onTap: _saveToGallery,
              ),
              const SizedBox(width: 12),
              _ActionButton(
                icon: LucideIcons.share2,
                label: 'Share',
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
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.textPrimary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
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
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
      ),
    );
  }
}