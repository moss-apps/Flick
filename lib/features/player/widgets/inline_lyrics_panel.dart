import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/features/player/widgets/lyrics_editor_bottom_sheet.dart';
import 'package:flick/features/player/widgets/online_lyrics_search_sheet.dart';
class InlineLyricsPanel extends StatefulWidget {
  final PlayerService playerService;
  final LyricsService lyricsService;
  final Song song;
  final Color? albumColor;

  const InlineLyricsPanel({super.key,
    required this.playerService,
    required this.lyricsService,
    required this.song,
    this.albumColor,
  });

  @override
  State<InlineLyricsPanel> createState() => _InlineLyricsPanelState();
}

class _InlineLyricsPanelState extends State<InlineLyricsPanel> {
  static const double _lineHeight = 116;
  static const double _centerFactor = 0.35;

  final ScrollController _scrollController = ScrollController();
  LyricsData? _lyricsData;
  bool _isLoading = true;
  bool _hasManualLyricsSelection = false;
  int _activeLineIndex = -1;
  bool _isMetaCollapsed = false;
  bool _isScrollAnimating = false;
  double? _pendingScrollTarget;
  Duration _lastTrackedPosition = Duration.zero;
  static const int _seekBackThresholdMs = 500;

  @override
  void initState() {
    super.initState();
    widget.playerService.positionNotifier.addListener(_onPositionChanged);
    _loadLyricsForSong(widget.song);
  }

  @override
  void didUpdateWidget(covariant InlineLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadLyricsForSong(widget.song);
    }
  }

  @override
  void dispose() {
    widget.playerService.positionNotifier.removeListener(_onPositionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    final data = _lyricsData;
    if (data == null || !data.isSynchronized || data.lines.isEmpty) return;

    final position = widget.playerService.positionNotifier.value;
    final newIndex = widget.lyricsService.findCurrentLineIndex(data, position);
    if (newIndex == _activeLineIndex) {
      _lastTrackedPosition = position;
      return;
    }

    // Forward playback only ever advances the active line. The audio engine
    // occasionally reports a transiently lower position (post-seek/buffer dip,
    // rounding), which would make the list scroll up then snap back. Treat a
    // backward change as jitter unless the position dropped by a real amount.
    final isSeekBack =
        position.inMilliseconds <
        _lastTrackedPosition.inMilliseconds - _seekBackThresholdMs;
    _lastTrackedPosition = position;

    if (newIndex < _activeLineIndex && !isSeekBack) return;

    _activeLineIndex = newIndex;
    _scrollToActiveLine(newIndex);
    setState(() {});
  }

  Future<void> _loadLyricsForSong(Song song) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lyricsData = null;
      _activeLineIndex = -1;
      _lastTrackedPosition = Duration.zero;
    });

    final loaded = await widget.lyricsService.loadLyricsForSong(
      song,
      forceRefresh: true,
    );
    final manualSource = await widget.lyricsService.getManualLyricsPathForSong(
      song,
    );
    if (!mounted) return;
    if (widget.song.id != song.id) return;

    setState(() {
      _lyricsData = loaded;
      _hasManualLyricsSelection =
          manualSource != null && manualSource.isNotEmpty;
      _isLoading = false;
    });

    _onPositionChanged();
  }

  void _scrollToActiveLine(int index) {
    if (!_scrollController.hasClients || index < 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (index * _lineHeight) + (_lineHeight / 2);
    final clampedTarget = target.clamp(0.0, maxScroll);

    _pendingScrollTarget = clampedTarget;

    if (!_isScrollAnimating) {
      _performScroll();
    }
  }

  void _performScroll() {
    if (!_scrollController.hasClients || _pendingScrollTarget == null) {
      _isScrollAnimating = false;
      return;
    }

    final target = _pendingScrollTarget!;
    _pendingScrollTarget = null;

    final delta = (_scrollController.offset - target).abs();
    if (delta < _lineHeight * 0.08) {
      _performScroll();
      return;
    }

    _isScrollAnimating = true;
    _scrollController
        .animateTo(
          target,
          duration: AppConstants.animationNormal,
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          _isScrollAnimating = false;
          _performScroll();
        });
  }

  Future<void> _seekToLyricLine(int index) async {
    final lyrics = _lyricsData;
    if (lyrics == null || !lyrics.isSynchronized || index < 0) return;

    final target = lyrics.lines[index].timestamp;
    widget.playerService.positionNotifier.value = target;

    if (mounted && _activeLineIndex != index) {
      setState(() {
        _activeLineIndex = index;
      });
    }

    _isScrollAnimating = false;
    _pendingScrollTarget = null;
    _scrollToActiveLine(index);
    await widget.playerService.seek(target);
  }

  String? _lyricsSourceLabel(String? source) {
    if (source == null || source.isEmpty) return null;
    final normalized = source.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _openLyricsEditor() async {
    final result = await LyricsEditorBottomSheet.show(
      context: context,
      song: widget.song,
      playerService: widget.playerService,
      lyricsService: widget.lyricsService,
      initialLyrics: _lyricsData,
    );
    if (!mounted || result == null) return;
    _showMessage(result.message);
    await _loadLyricsForSong(widget.song);
  }

  Future<void> _importLyricsFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['lrc', 'txt', 'xml'],
        withData: true,
      );
      final pickedFile = result?.files.single;
      if (pickedFile == null) return;

      final content = await readTextFromPickedLyricsFile(pickedFile);
      if (content == null || content.trim().isEmpty) {
        _showMessage('Could not read the selected lyrics file.');
        return;
      }

      await widget.lyricsService.importLyricsForSong(
        song: widget.song,
        fileName: pickedFile.name,
        content: content,
      );
      if (!mounted) return;
      await _loadLyricsForSong(widget.song);
      _showMessage('Linked "${pickedFile.name}" to this song.');
    } catch (_) {
      _showMessage('Could not use the selected lyrics file.');
    }
  }

  Future<void> _resetManualLyricsSource() async {
    await widget.lyricsService.clearManualLyricsPathForSong(widget.song);
    if (!mounted) return;
    await _loadLyricsForSong(widget.song);
    if (!mounted) return;
    _showMessage('Switched back to the automatic lyrics source.');
  }

  Future<void> _searchOnlineLyrics() async {
    final result = await OnlineLyricsSearchSheet.show(
      context: context,
      song: widget.song,
      lyricsService: widget.lyricsService,
    );
    if (result == true && mounted) {
      await _loadLyricsForSong(widget.song);
      _showMessage('Lyrics saved from LRCLib.');
    }
  }

  Widget _buildActionButtons() {
    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool emphasized = false,
    }) {
      final fillColor = emphasized
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.08);
      return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: fillColor,
          foregroundColor: Colors.white.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          action(
            icon: LucideIcons.pencilLine,
            label: _lyricsData == null ? 'Create Lyrics' : 'Edit & Sync',
            onPressed: () => unawaited(_openLyricsEditor()),
            emphasized: true,
          ),
          action(
            icon: LucideIcons.filePlus,
            label: 'Use Existing File',
            onPressed: () => unawaited(_importLyricsFile()),
          ),
          action(
            icon: LucideIcons.globe,
            label: 'Search Online',
            onPressed: () => unawaited(_searchOnlineLyrics()),
          ),
          if (_hasManualLyricsSelection)
            action(
              icon: LucideIcons.refreshCcw,
              label: 'Use Auto Source',
              onPressed: () => unawaited(_resetManualLyricsSource()),
            ),
        ],
      ),
    );
  }

  Widget _buildLyricsMeta(LyricsData lyrics) {
    final sourceLabel = _lyricsSourceLabel(lyrics.source);
    final textColor = Colors.white.withValues(alpha: 0.82);

    Widget chip(IconData icon, String label, {bool accent = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent
                ? AppColors.accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent ? AppColors.accent : textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent ? AppColors.accent : textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isMetaCollapsed = !_isMetaCollapsed),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chip(
                  lyrics.isSynchronized
                      ? LucideIcons.clock3
                      : LucideIcons.fileText,
                  lyrics.isSynchronized ? 'Synced' : 'Plain',
                  accent: lyrics.isSynchronized,
                ),
                const SizedBox(width: 8),
                if (sourceLabel != null) ...[
                  chip(LucideIcons.badgeInfo, sourceLabel),
                  const SizedBox(width: 8),
                ],
                AnimatedRotation(
                  turns: _isMetaCollapsed ? 0.0 : 0.5,
                  duration: AppConstants.animationFast,
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: AppConstants.animationFast,
          crossFadeState: _isMetaCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip(
                      lyrics.isSynchronized
                          ? LucideIcons.touchpad
                          : Icons.notes_rounded,
                      lyrics.isSynchronized
                          ? 'Tap any line to seek'
                          : 'Static lyrics — no timestamps',
                    ),
                    chip(LucideIcons.pencilLine, 'Edit & Sync Studio'),
                    if (lyrics.lines.isNotEmpty)
                      chip(
                        Icons.format_align_left,
                        '${lyrics.lines.length} lines',
                      ),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlainLyricsView(LyricsData lyrics) {
    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Text(
          lyrics.lines.map((line) => line.text).join('\n'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 18,
            height: 1.9,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }

  double _lyricOpacityForIndex(int index) {
    if (_activeLineIndex < 0) return 0.72;

    final distance = (index - _activeLineIndex).abs();
    switch (distance) {
      case 0:
        return 1;
      case 1:
        return 0.56;
      case 2:
        return 0.36;
      case 3:
        return 0.24;
      default:
        return 0.18;
    }
  }

  TextStyle _lyricTextStyle(bool isActive, double opacity) {
    return TextStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: Colors.white.withValues(alpha: opacity),
    );
  }

  StrutStyle _lyricStrutStyle(bool isActive) {
    return StrutStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      forceStrutHeight: true,
    );
  }

  Widget _buildSynchronizedLyricsView(LyricsData lyrics) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerPadding = constraints.maxHeight * _centerFactor;
          return ListView.builder(
            scrollCacheExtent: ScrollCacheExtent.pixels(_lineHeight * 8),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(10, centerPadding, 10, centerPadding),
            itemCount: lyrics.lines.length,
            itemExtent: _lineHeight,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == _activeLineIndex;
              final lineOpacity = _lyricOpacityForIndex(index);

              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => unawaited(_seekToLyricLine(index)),
                      child: Center(
                        child: isActive
                            ? AnimatedContainer(
                                duration: AppConstants.animationFast,
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: widget.albumColor != null
                                      ? albumAccent(
                                          widget.albumColor!,
                                          0.3,
                                        ).withValues(alpha: 0.16)
                                      : Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: widget.albumColor != null
                                        ? albumAccent(
                                            widget.albumColor!,
                                            0.3,
                                          ).withValues(alpha: 0.22)
                                        : Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  line.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.center,
                                  style: _lyricTextStyle(true, lineOpacity),
                                  strutStyle: _lyricStrutStyle(true),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Text(
                                  line.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.center,
                                  style: _lyricTextStyle(false, lineOpacity),
                                  strutStyle: _lyricStrutStyle(false),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final lyrics = _lyricsData;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  LucideIcons.fileText,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No lyrics yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search online, create your own synced lyrics, or import an existing file.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildLyricsMeta(lyrics),
        if (lyrics.isSynchronized)
          _buildSynchronizedLyricsView(lyrics)
        else
          Expanded(child: _buildPlainLyricsView(lyrics)),
      ],
    );
  }
}

/// Extracted waveform layer widget.
/// Owns a ValueListenableBuilder on [positionNotifier] so that 50ms position
/// ticks **never** cause the parent [_FullPlayerScreenState] to rebuild.
