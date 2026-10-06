import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/player/widgets/karaoke_lyric_line.dart';
import 'package:flick/features/player/widgets/lyrics_editor_model.dart';
import 'package:flick/features/player/widgets/lyrics_word_timeline.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/l10n/l10n.dart';

enum LyricsEditorViewMode { simple, wordSync, advanced }

enum _StudioTab { lines, tools }

class LyricsEditorResult {
  final String message;
  final LyricsData lyricsData;

  const LyricsEditorResult({required this.message, required this.lyricsData});
}

/// Full-screen Lyrics Sync Studio. Replaces the old cramped bottom sheet:
/// pinned playback bar, mode switcher, and a Lines/Tools split so the
/// tap-along workspace gets real estate.
class LyricsSyncScreen extends StatefulWidget {
  final Song song;
  final PlayerService playerService;
  final LyricsService lyricsService;
  final LyricsData? initialLyrics;

  const LyricsSyncScreen({
    super.key,
    required this.song,
    required this.playerService,
    required this.lyricsService,
    this.initialLyrics,
  });

  static Future<LyricsEditorResult?> open({
    required BuildContext context,
    required Song song,
    required PlayerService playerService,
    required LyricsService lyricsService,
    LyricsData? initialLyrics,
  }) {
    return Navigator.of(context, rootNavigator: true).push<LyricsEditorResult>(
      MaterialPageRoute(
        builder: (_) => LyricsSyncScreen(
          song: song,
          playerService: playerService,
          lyricsService: lyricsService,
          initialLyrics: initialLyrics,
        ),
      ),
    );
  }

  @override
  State<LyricsSyncScreen> createState() => _LyricsSyncScreenState();
}

class _LyricsSyncScreenState extends State<LyricsSyncScreen> {
  final TextEditingController _lyricsTextController = TextEditingController();
  final TextEditingController _currentTimeController = TextEditingController();
  final TextEditingController _boundaryTimeController = TextEditingController();
  final FocusNode _boundaryFocus = FocusNode();

  LyricsEditorViewMode _viewMode = LyricsEditorViewMode.simple;
  _StudioTab _tab = _StudioTab.lines;
  LyricsEditorModel _model = const LyricsEditorModel([
    EditableLyricLine(text: '', timestamp: null),
  ]);
  int _selectedLineIndex = 0;
  int? _selectedWordIndex;
  bool _autoAdvance = true;
  bool _isSaving = false;
  Duration _currentPosition = Duration.zero;
  late final String _initialSignature;

  List<EditableLyricLine> get _lines => _model.lines;

  int get _stampedLineCount => _model.stampedLineCount;

  int get _usableLineCount => _model.usableLineCount;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.playerService.positionNotifier.value;
    _model = LyricsEditorModel.fromLyrics(widget.initialLyrics);
    _initialSignature = _modelSignature();
    _syncEditorFromLines();
    _updateCurrentTimeField();
    _lyricsTextController.addListener(_handleLyricsTextChanged);
    widget.playerService.positionNotifier.addListener(_handlePositionChanged);
  }

  @override
  void dispose() {
    _lyricsTextController.removeListener(_handleLyricsTextChanged);
    widget.playerService.positionNotifier.removeListener(
      _handlePositionChanged,
    );
    _lyricsTextController.dispose();
    _currentTimeController.dispose();
    _boundaryTimeController.dispose();
    _boundaryFocus.dispose();
    super.dispose();
  }

  void _handlePositionChanged() {
    final nextPosition = widget.playerService.positionNotifier.value;
    if (_currentPosition == nextPosition) return;
    setState(() {
      _currentPosition = nextPosition;
    });
    _updateCurrentTimeField();
  }

  void _updateCurrentTimeField() {
    final value = widget.lyricsService.formatTimestamp(_currentPosition);
    if (_currentTimeController.text == value) return;
    _currentTimeController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncEditorFromLines() {
    final text = _lines.map((line) => line.text).join('\n');
    _lyricsTextController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleLyricsTextChanged() {
    setState(() {
      _model = _model.reflowText(_lyricsTextController.text);
      if (_selectedLineIndex >= _lines.length) {
        _selectedLineIndex = _lines.length - 1;
      }
      if (_selectedLineIndex < 0) {
        _selectedLineIndex = 0;
      }
      _selectedWordIndex = null;
    });
  }

  bool get _isDirty => _modelSignature() != _initialSignature;

  String _modelSignature() {
    return _lines
        .map(
          (line) => [
            line.text,
            line.timestamp?.inMilliseconds.toString() ?? '-',
            line.wordStarts
                    ?.map((start) => start?.inMilliseconds.toString() ?? '-')
                    .join(',') ??
                '-',
            line.segmentBreaks
                    ?.map((token) => token.join(','))
                    .join(';') ??
                '-',
          ].join('\x1F'),
        )
        .join('\x1E');
  }

  Future<void> _seekBy(Duration delta) async {
    final duration =
        widget.playerService.durationNotifier.value.inMilliseconds > 0
        ? widget.playerService.durationNotifier.value
        : widget.song.duration;
    final next = _currentPosition + delta;
    final clampedMs = next.inMilliseconds.clamp(
      0,
      duration.inMilliseconds > 0
          ? duration.inMilliseconds
          : next.inMilliseconds,
    );
    final target = Duration(milliseconds: clampedMs);
    await widget.playerService.seek(target);
  }

  Future<void> _togglePlayPause() async {
    if (widget.playerService.isPlayingNotifier.value) {
      await widget.playerService.pause();
    } else {
      await widget.playerService.resume();
    }
  }

  void _selectLine(int index) {
    if (index < 0 || index >= _lines.length) return;
    setState(() {
      _selectedLineIndex = index;
      _selectedWordIndex = null;
      if (_viewMode != LyricsEditorViewMode.simple) {
        _tab = _StudioTab.tools;
      }
    });
  }

  void _stampSelectedLine({required bool advance}) {
    if (_selectedLineIndex < 0 || _selectedLineIndex >= _lines.length) return;
    final current = _lines[_selectedLineIndex];
    if (current.text.trim().isEmpty) return;

    setState(() {
      _model = _model.setLineTimestamp(
        _selectedLineIndex,
        _currentPosition,
      );
      if (advance && _selectedLineIndex < _lines.length - 1) {
        _selectedLineIndex += 1;
        _selectedWordIndex = null;
      }
    });
  }

  void _clearSelectedTimestamp() {
    if (_selectedLineIndex < 0 || _selectedLineIndex >= _lines.length) return;
    setState(() {
      _model = _model.setLineTimestamp(_selectedLineIndex, null);
      _selectedWordIndex = null;
    });
  }

  void _shiftAll(Duration delta) {
    setState(() {
      _model = _model.shiftAll(delta);
    });
  }

  void _applyTimestampText(int index, String value) {
    final normalized = value.replaceAll('[', '').replaceAll(']', '').trim();
    if (normalized.isEmpty) {
      setState(() {
        _model = _model.setLineTimestamp(index, null);
      });
      return;
    }

    final parsed = widget.lyricsService.parseTimestamp(normalized);
    if (parsed == null) return;

    setState(() {
      _model = _model.setLineTimestamp(index, parsed);
    });
  }

  EditableLyricLine? get _selectedLine =>
      _selectedLineIndex >= 0 && _selectedLineIndex < _lines.length
      ? _lines[_selectedLineIndex]
      : null;

  void _stampNextWord() {
    final line = _selectedLine;
    if (line == null || line.tokens.isEmpty) return;

    setState(() {
      final (model, stamped) = _model.stampNextWord(
        _selectedLineIndex,
        _currentPosition,
      );
      _model = model;
      if (stamped != null &&
          _autoAdvance &&
          stamped == line.segmentCount - 1 &&
          _selectedLineIndex < _lines.length - 1) {
        _selectedLineIndex += 1;
        _selectedWordIndex = null;
      } else if (stamped != null) {
        _selectedWordIndex = stamped;
      }
    });
  }

  void _undoLastWordStamp() {
    setState(() {
      _model = _model.undoLastWordStamp(_selectedLineIndex);
      _selectedWordIndex = null;
    });
  }

  void _clearWords() {
    setState(() {
      _model = _model.clearWords(_selectedLineIndex);
      _selectedWordIndex = null;
    });
  }

  void _nudgeSelectedWord(Duration delta) {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return;
    setState(() {
      _model = _model.nudgeWord(_selectedLineIndex, wordIndex, delta);
    });
  }

  void _setSelectedWordToNow() {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return;
    setState(() {
      _model = _model.setWord(
        _selectedLineIndex,
        wordIndex,
        _currentPosition,
      );
    });
  }

  void _clearSelectedWord() {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return;
    final starts = _selectedLine?.wordStarts;
    if (starts == null ||
        wordIndex >= starts.length ||
        starts[wordIndex] == null) {
      return;
    }
    setState(() {
      _model = _model.clearWord(_selectedLineIndex, wordIndex);
      _selectedWordIndex = null;
    });
  }

  void _setWordBoundary(int wordIndex, Duration proposed) {
    setState(() {
      _model = _model.setWordBoundary(_selectedLineIndex, wordIndex, proposed);
    });
  }

  void _setLineEndBoundary(Duration proposed) {
    setState(() {
      _model = _model.setLineEndBoundary(_selectedLineIndex, proposed);
    });
  }

  void _autoFillWords() {
    setState(() {
      _model = _model.autoFillWords(_selectedLineIndex);
    });
  }

  void _toggleSegmentBreak(int tokenIndex, int charOffset) {
    setState(() {
      _model = _model.toggleSegmentBreak(
        _selectedLineIndex,
        tokenIndex,
        charOffset,
      );
      _selectSegmentAt(tokenIndex, charOffset);
    });
  }

  // Points selection at the segment containing charOffset of tokenIndex —
  // the newly created or merged one after a toggle.
  void _selectSegmentAt(int tokenIndex, int charOffset) {
    final layout = _selectedLine?.segmentLayout ?? const [];
    for (var i = 0; i < layout.length; i++) {
      final entry = layout[i];
      if (entry.tokenIndex == tokenIndex &&
          charOffset >= entry.charStart &&
          charOffset < entry.charEnd) {
        _selectedWordIndex = i;
        return;
      }
    }
    _selectedWordIndex = null;
  }

  // Nudges the selected word's right edge (next word's start, or line end
  // for the final word), stretching or shrinking the word.
  void _nudgeSelectedWordLength(Duration delta) {
    final line = _selectedLine;
    final wordIndex = _selectedWordIndex;
    final starts = line?.wordStarts;
    if (line == null ||
        wordIndex == null ||
        starts == null ||
        wordIndex >= starts.length ||
        starts[wordIndex] == null) {
      return;
    }
    final windows = _model.wordWindows(_selectedLineIndex);
    if (windows == null || wordIndex >= windows.length) return;
    final end = windows[wordIndex].end;
    if (wordIndex + 1 < starts.length) {
      _setWordBoundary(wordIndex + 1, end + delta);
    } else {
      _setLineEndBoundary(end + delta);
    }
  }

  void _setSelectedBoundaryToNow() {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return;
    _setWordBoundary(wordIndex, _currentPosition);
  }

  void _applyBoundaryText(String value) {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return;
    final normalized = value.replaceAll('[', '').replaceAll(']', '').trim();
    final parsed = widget.lyricsService.parseTimestamp(normalized);
    if (parsed == null) {
      _showMessage(l10n.useMmSsCcEG);
      return;
    }
    setState(() {
      _model = _model.setWordBoundary(_selectedLineIndex, wordIndex, parsed);
    });
    _boundaryFocus.unfocus();
  }

  // Mirrors the boundary text field to the selected word unless the user
  // is typing in it.
  void _syncBoundaryTimeField() {
    final line = _selectedLine;
    final wordIndex = _selectedWordIndex;
    final starts = line?.wordStarts;
    if (line == null ||
        wordIndex == null ||
        starts == null ||
        wordIndex >= starts.length ||
        starts[wordIndex] == null) {
      return;
    }
    if (_boundaryFocus.hasFocus) return;
    final text = widget.lyricsService
        .formatTimestamp(starts[wordIndex]!)
        .replaceAll('[', '')
        .replaceAll(']', '');
    if (_boundaryTimeController.text == text) return;
    _boundaryTimeController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  LyricsData? _previewCache;
  LyricsEditorModel? _previewCacheSource;

  // Memoized — playback position ticks must not rebuild LyricsData, a fresh
  // instance every frame made the karaoke preview blink.
  LyricsData? _buildPreviewLyricsData() {
    if (!identical(_previewCacheSource, _model)) {
      _previewCacheSource = _model;
      final normalized = _model.normalizeForSave();
      _previewCache = normalized.isEmpty
          ? null
          : LyricsData(
              lines: normalized,
              isSynchronized: true,
              rawContent: '',
            );
    }
    return _previewCache;
  }

  Future<void> _save() async {
    final normalizedLines = _model.normalizeForSave();
    if (normalizedLines.isEmpty) {
      _showMessage(l10n.addAtLeastOneLyricLine);
      return;
    }

    final lrcContent = widget.lyricsService.buildLrcContent(
      lines: normalizedLines,
      song: widget.song,
      length: widget.song.duration,
    );
    final sidecarPath = widget.lyricsService.suggestSidecarLrcPath(widget.song);

    final choice = await showFlickDialog<String>(
      context: context,
      barrierLabel: l10n.saveLrcFile,
      builder: (ctx) => FlickDialog(
        title: l10n.saveLrcFile,
        content: Text(l10n.whereShouldTheLrcFileBe),
        actions: [
          FlickDialogButton(
            label: l10n.chooseLocationU2026,
            onPressed: () => Navigator.pop(ctx, 'custom'),
          ),
          if (sidecarPath != null)
            FlickDialogButton(
              label: l10n.besideTheSong,
              onPressed: () => Navigator.pop(ctx, 'beside'),
            ),
          FlickDialogButton(
            label: l10n.saveInFlick,
            style: FlickDialogButtonStyle.primary,
            onPressed: () => Navigator.pop(ctx, 'managed'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      late final LyricsSaveResult result;

      if (choice == 'custom') {
        final safeStem = widget.song.title.isNotEmpty
            ? widget.song.title
            : 'lyrics';
        final savePath = await FilePicker.saveFile(
          dialogTitle: l10n.saveLrcFile2,
          fileName: '$safeStem.lrc',
          type: FileType.custom,
          allowedExtensions: const ['lrc'],
          bytes: Uint8List.fromList(utf8.encode(lrcContent)),
        );
        if (savePath == null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
        result = await widget.lyricsService.saveLyricsToPath(
          song: widget.song,
          content: lrcContent,
          path: savePath,
        );
      } else if (choice == 'managed') {
        result = await widget.lyricsService.saveLyricsToManaged(
          song: widget.song,
          content: lrcContent,
        );
      } else {
        result = await widget.lyricsService.saveLyricsForSong(
          song: widget.song,
          content: lrcContent,
        );
      }

      if (!mounted) return;
      final message = choice == 'custom'
          ? l10n.savedLyricsToTheChosenLocation
          : result.savedBesideSong
              ? l10n.savedLyricsBesideTheSongAs
              : l10n.savedLyricsAndLinkedThemTo;
      Navigator.of(context).pop(
        LyricsEditorResult(
          message: message,
          lyricsData: result.data,
        ),
      );
    } catch (_) {
      _showMessage(l10n.couldNotSaveTheLyricsFile);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showFlickDialog<bool>(
      context: context,
      barrierLabel: l10n.unsavedChanges,
      builder: (ctx) => FlickDialog(
        title: l10n.discardChanges,
        content: Text(
          l10n.youHaveUnsavedLyricEditsLeave,
        ),
        actions: [
          FlickDialogButton(
            label: l10n.discard,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          FlickDialogButton(
            label: l10n.keepEditing,
            style: FlickDialogButtonStyle.primary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showTextEditor() async {
    await showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.lyricsText,
      builder: (ctx) => FlickDialog(
        title: l10n.lyricsText,
        content: SizedBox(
          width: double.infinity,
          child: TextField(
            controller: _lyricsTextController,
            minLines: 10,
            maxLines: 14,
            decoration: InputDecoration(
              hintText: l10n.pasteOrTypeTheSongLyrics,
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
            ),
          ),
        ),
        actions: [
          FlickDialogButton(
            label: l10n.done,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstructions() async {
    await showFlickDialog<void>(
      context: context,
      barrierLabel: l10n.lyricsSyncHelp,
      builder: (dialogContext) => FlickDialog(
        title: l10n.lyricsSyncHelp,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.simpleMode,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tapEditTextTopRight,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.wordSyncModeKaraoke,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pickALyricLineIn,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.advancedMode,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.selectALineAndEdit,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tips,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.useExistingFileInTheLyrics,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          FlickDialogButton(
            label: l10n.gotIt,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncBoundaryTimeField();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.lyricsSyncStudio,
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _isSaving ? null : _showTextEditor,
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: l10n.editText,
            ),
            IconButton(
              onPressed: _isSaving ? null : _showInstructions,
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: l10n.instructions,
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppConstants.spacingMd),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_isSaving ? l10n.saving : l10n.save),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: _buildModePicker(context),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: _buildStatusStrip(context),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: _buildPlaybackBar(context),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Divider(height: 1, color: AppColors.glassBorder),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 340,
                            child: _buildLinesPane(context),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.glassBorder,
                          ),
                          Expanded(child: _buildToolsPane(context)),
                        ],
                      )
                    : _buildPhoneBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingXs,
          ),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_StudioTab>(
                  segments: [
                    ButtonSegment(
                      value: _StudioTab.lines,
                      icon: Icon(Icons.format_list_bulleted_rounded, size: 16),
                      label: Text(l10n.lines),
                    ),
                    ButtonSegment(
                      value: _StudioTab.tools,
                      icon: Icon(LucideIcons.slidersHorizontal, size: 16),
                      label: Text(l10n.tools),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _tab = selection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab == _StudioTab.lines ? 0 : 1,
            children: [
              _buildLinesPane(context),
              _buildToolsPane(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModePicker(BuildContext context) {
    String labelFor(LyricsEditorViewMode mode) {
      switch (mode) {
        case LyricsEditorViewMode.simple:
          return l10n.simple;
        case LyricsEditorViewMode.wordSync:
          return l10n.wordSync;
        case LyricsEditorViewMode.advanced:
          return l10n.advanced;
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: LyricsEditorViewMode.values.map((mode) {
        final selected = mode == _viewMode;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            setState(() {
              _viewMode = mode;
            });
          },
          label: Text(labelFor(mode)),
        );
      }).toList(),
    );
  }

  Widget _buildStatusStrip(BuildContext context) {
    Widget chip(IconData icon, String value, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.adaptiveTextSecondary),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.adaptiveTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip(Icons.format_list_bulleted_rounded, '$_usableLineCount', 'lines'),
        chip(LucideIcons.clock3, '$_stampedLineCount', 'stamped'),
        chip(
          LucideIcons.mic,
          '${_model.capturedWordCount}/${_model.totalWordCount}',
          'words',
        ),
      ],
    );
  }

  Widget _buildPlaybackBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _seekBy(const Duration(seconds: -2)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('-2s'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: widget.playerService.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return FilledButton.icon(
                    onPressed: _togglePlayPause,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      isPlaying ? LucideIcons.pause : LucideIcons.play,
                      size: 16,
                    ),
                    label: Text(isPlaying ? l10n.pause : l10n.play),
                  );
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _seekBy(const Duration(seconds: 2)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('+2s'),
              ),
              const Spacer(),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: _currentTimeController,
                  readOnly: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: l10n.now,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          ValueListenableBuilder<Duration>(
            valueListenable: widget.playerService.positionNotifier,
            builder: (context, position, _) {
              return ValueListenableBuilder<Duration>(
                valueListenable: widget.playerService.durationNotifier,
                builder: (context, duration, _) {
                  final totalMs = duration.inMilliseconds > 0
                      ? duration.inMilliseconds
                      : widget.song.duration.inMilliseconds;
                  final progress = totalMs > 0
                      ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                    backgroundColor: AppColors.surfaceDark,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.adaptiveAccent,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinesPane(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            itemCount: _lines.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.glassBorder),
            itemBuilder: (context, index) {
              final line = _lines[index];
              final selected = index == _selectedLineIndex;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  onTap: () => _selectLine(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.surfaceLight.withValues(alpha: 0.95)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      border: Border.all(
                        color: selected
                            ? AppColors.accentDim
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent
                                : AppColors.surfaceDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.surface
                                  : context.adaptiveTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.text.isEmpty ? l10n.emptyLine : line.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                line.timestamp == null
                                    ? l10n.notStampedYet
                                    : widget.lyricsService.formatTimestamp(
                                        line.timestamp!,
                                      ),
                                style: TextStyle(
                                  color: context.adaptiveTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (line.hasAnyWords)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              LucideIcons.mic,
                              size: 14,
                              color: line.hasCompleteWords
                                  ? AppColors.accentDim
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_viewMode == LyricsEditorViewMode.simple)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selectedLine?.text.trim().isNotEmpty == true
                        ? () => _stampSelectedLine(advance: _autoAdvance)
                        : null,
                    icon: const Icon(LucideIcons.clock3, size: 16),
                    label: Text(_autoAdvance ? l10n.stampNext : l10n.stampNow),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                OutlinedButton.icon(
                  onPressed: _selectedLine?.timestamp != null
                      ? _clearSelectedTimestamp
                      : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.eraser, size: 14),
                  label: Text(l10n.clear),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                FilterChip(
                  selected: _autoAdvance,
                  onSelected: (value) {
                    setState(() {
                      _autoAdvance = value;
                    });
                  },
                  label: Text(l10n.auto),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolsPane(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectedLineCard(context),
          const SizedBox(height: AppConstants.spacingMd),
          if (_viewMode == LyricsEditorViewMode.wordSync) ...[
            _buildTapSection(context),
            const SizedBox(height: AppConstants.spacingMd),
            _buildWordChips(context),
            const SizedBox(height: AppConstants.spacingSm),
            _buildWordNudgeTools(context),
            const SizedBox(height: AppConstants.spacingSm),
          ],
          if (_viewMode == LyricsEditorViewMode.advanced) ...[
            _buildWordTimelineSection(context),
            const SizedBox(height: AppConstants.spacingSm),
          ],
          if (_viewMode != LyricsEditorViewMode.wordSync) ...[
            _buildShiftTools(context),
            const SizedBox(height: AppConstants.spacingSm),
          ],
          if (_viewMode != LyricsEditorViewMode.simple) ...[
            _buildKaraokePreview(context),
            const SizedBox(height: AppConstants.spacingSm),
          ],
          _buildSaveNotice(context),
        ],
      ),
    );
  }

  Widget _buildSelectedLineCard(BuildContext context) {
    final line = _selectedLine;
    if (line == null) return const SizedBox.shrink();
    final timestampText = line.timestamp == null
        ? ''
        : widget.lyricsService
              .formatTimestamp(line.timestamp!)
              .replaceAll('[', '')
              .replaceAll(']', '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.accentDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lineOf(_selectedLineIndex + 1, _lines.length),
            style: TextStyle(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line.text.isEmpty ? l10n.emptyLine : line.text,
            style: TextStyle(
              color: context.adaptiveTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('timestamp-$_selectedLineIndex'),
                  initialValue: timestampText,
                  onChanged: (value) =>
                      _applyTimestampText(_selectedLineIndex, value),
                  decoration: InputDecoration(
                    labelText: l10n.timestamp,
                    hintText: '00:12.34',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              OutlinedButton.icon(
                onPressed: () => _stampSelectedLine(advance: false),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.clock3, size: 14),
                label: Text(l10n.useCurrentTime),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTapSection(BuildContext context) {
    final line = _selectedLine;
    final tokens = line?.tokens ?? const <String>[];
    final segmentCount = line?.segmentCount ?? tokens.length;
    final starts = line?.wordStarts;
    final nextWordIndex = starts == null || starts.length != segmentCount
        ? 0
        : starts.indexWhere((start) => start == null);
    final captured = line?.capturedWordCount ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lineOfWords(_selectedLineIndex + 1, _lines.length, captured, segmentCount),
            style: TextStyle(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: tokens.isNotEmpty && nextWordIndex >= 0
                  ? _stampNextWord
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(LucideIcons.mic),
              label: Text(
                tokens.isEmpty
                    ? l10n.pickALineWithLyrics
                    : nextWordIndex < 0
                    ? l10n.allWordsStamped
                    : l10n.tap(line?.segmentLabel(nextWordIndex) ?? tokens[nextWordIndex].trim()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: captured > 0 ? _undoLastWordStamp : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.undo2, size: 16),
                label: Text(l10n.undo),
              ),
              OutlinedButton.icon(
                onPressed: (line?.hasAnyWords ?? false) ? _clearWords : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.eraser, size: 16),
                label: Text(l10n.clearWords),
              ),
              FilterChip(
                selected: _autoAdvance,
                onSelected: (value) {
                  setState(() {
                    _autoAdvance = value;
                  });
                },
                label: Text(l10n.autoAdvance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordChips(BuildContext context) {
    final line = _selectedLine;
    if (line == null || line.tokens.isEmpty) {
      return const SizedBox.shrink();
    }
    final segmentCount = line.segmentCount;
    var starts = line.wordStarts;
    if (starts == null || starts.length != segmentCount) {
      starts = List<Duration?>.filled(segmentCount, null);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < segmentCount; i++)
            _buildWordChip(context, i, line.segmentLabel(i), starts[i]),
        ],
      ),
    );
  }

  Widget _buildWordChip(
    BuildContext context,
    int wordIndex,
    String token,
    Duration? start,
  ) {
    final selected = _selectedWordIndex == wordIndex;
    final captured = start != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        onTap: () {
          setState(() {
            _selectedWordIndex = selected ? null : wordIndex;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surfaceLight.withValues(alpha: 0.95)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            border: Border.all(
              color: selected
                  ? AppColors.accentDim
                  : captured
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
          ),
          child: Column(
            children: [
              Text(
                token.trim(),
                style: TextStyle(
                  color: captured
                      ? context.adaptiveTextPrimary
                      : context.adaptiveTextSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                start == null
                    ? '—'
                    : widget.lyricsService
                          .formatTimestamp(start)
                          .replaceAll('[', '')
                          .replaceAll(']', ''),
                style: TextStyle(
                  color: captured
                      ? context.adaptiveTextSecondary
                      : AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordNudgeTools(BuildContext context) {
    final wordIndex = _selectedWordIndex;
    if (wordIndex == null) return const SizedBox.shrink();
    final line = _selectedLine;
    final segmentCount = line?.segmentCount ?? 0;
    if (line == null || wordIndex >= segmentCount) {
      return const SizedBox.shrink();
    }

    final starts = _selectedLine?.wordStarts;
    final captured = starts != null &&
        wordIndex < starts.length &&
        starts[wordIndex] != null;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.accentDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.word(wordIndex + 1, line.segmentLabel(wordIndex)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: captured
                    ? () => _nudgeSelectedWord(
                        const Duration(milliseconds: -100),
                      )
                    : null,
                child: const Text('-100ms'),
              ),
              OutlinedButton(
                onPressed: captured
                    ? () => _nudgeSelectedWord(const Duration(milliseconds: 100))
                    : null,
                child: const Text('+100ms'),
              ),
              OutlinedButton.icon(
                onPressed: _setSelectedWordToNow,
                icon: const Icon(LucideIcons.clock3, size: 14),
                label: Text(l10n.setToNow),
              ),
              OutlinedButton.icon(
                onPressed: captured ? _clearSelectedWord : null,
                icon: const Icon(LucideIcons.eraser, size: 14),
                label: Text(l10n.clearWord),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKaraokePreview(BuildContext context) {
    final previewData = _buildPreviewLyricsData();
    final previewIndex = _model.indexOfNormalizedLine(_selectedLineIndex);
    if (previewData == null ||
        previewIndex < 0 ||
        previewIndex >= previewData.lines.length) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            l10n.karaokePreview,
            style: TextStyle(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          KaraokeLyricLine(
            key: ValueKey('word-sync-preview-$previewIndex'),
            playerService: widget.playerService,
            lyricsService: widget.lyricsService,
            lyrics: previewData,
            lineIndex: previewIndex,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
            sungColor: AppColors.textPrimary,
            unsungColor: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildWordTimelineSection(BuildContext context) {
    final line = _selectedLine;
    if (line == null || line.tokens.isEmpty) return const SizedBox.shrink();

    Widget hint(String message) => Text(
      message,
      style: TextStyle(color: context.adaptiveTextSecondary, fontSize: 12),
    );

    final windows = _model.wordWindows(_selectedLineIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.wordTimelineLine(_selectedLineIndex + 1),
                  style: TextStyle(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (line.timestamp != null && !line.hasAnyWords)
                TextButton.icon(
                  onPressed: _autoFillWords,
                  icon: const Icon(LucideIcons.wand2, size: 14),
                  label: Text(l10n.autoFill),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (line.timestamp == null)
            hint(l10n.stampThisLineFirstToEdit)
          else if (!line.hasAnyWords)
            hint(
              l10n.noWordTimingYetAutoFill,
            )
          else if (!line.hasCompleteWords)
            hint(l10n.someWordsAreStillUntimedFinish)
          else if (windows != null) ...[
            Text(
              l10n.dragABoundaryToStretchOr,
              style: TextStyle(
                color: context.adaptiveTextSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            WordTimeline(
              segmentTexts: [
                for (var i = 0; i < line.segmentLayout.length; i++)
                  line.segmentLabel(i),
              ],
              tokenIndexPerSegment: [
                for (final entry in line.segmentLayout) entry.tokenIndex,
              ],
              windows: windows,
              selectedWordIndex: _selectedWordIndex,
              playhead: _currentPosition,
              lineEndDraggable: _model.isLineEndDraggable(
                _selectedLineIndex,
              ),
              onSelectWord: (index) {
                setState(() {
                  _selectedWordIndex = _selectedWordIndex == index
                      ? null
                      : index;
                });
              },
              onBoundaryChanged: _setWordBoundary,
              onLineEndChanged: _setLineEndBoundary,
              formatTime: (time) => widget.lyricsService
                  .formatTimestamp(time)
                  .replaceAll('[', '')
                  .replaceAll(']', ''),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildTimelineInspector(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineInspector(BuildContext context) {
    final line = _selectedLine;
    final wordIndex = _selectedWordIndex;
    final starts = line?.wordStarts;
    if (line == null ||
        wordIndex == null ||
        starts == null ||
        wordIndex >= starts.length ||
        starts[wordIndex] == null) {
      return const SizedBox.shrink();
    }
    final layout = line.segmentLayout;
    if (wordIndex >= layout.length) return const SizedBox.shrink();

    final token = line.segmentLabel(wordIndex);
    final windows = _model.wordWindows(_selectedLineIndex);
    final start = starts[wordIndex]!;
    final end = windows != null && wordIndex < windows.length
        ? windows[wordIndex].end
        : start;
    final lengthMs = (end - start).inMilliseconds;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.accentDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.word2(wordIndex + 1, token),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.lengthS((lengthMs / 1000).toStringAsFixed(2)),
                      style: TextStyle(
                        color: context.adaptiveTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _boundaryTimeController,
                  focusNode: _boundaryFocus,
                  onSubmitted: _applyBoundaryText,
                  decoration: InputDecoration(
                    labelText: l10n.start,
                    hintText: '00:12.34',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.length,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontSize: 12,
                ),
              ),
              OutlinedButton(
                onPressed: () => _nudgeSelectedWordLength(
                  const Duration(milliseconds: -100),
                ),
                child: const Text('-100ms'),
              ),
              OutlinedButton(
                onPressed: () => _nudgeSelectedWordLength(
                  const Duration(milliseconds: -10),
                ),
                child: const Text('-10ms'),
              ),
              OutlinedButton(
                onPressed: () => _nudgeSelectedWordLength(
                  const Duration(milliseconds: 10),
                ),
                child: const Text('+10ms'),
              ),
              OutlinedButton(
                onPressed: () => _nudgeSelectedWordLength(
                  const Duration(milliseconds: 100),
                ),
                child: const Text('+100ms'),
              ),
              OutlinedButton.icon(
                onPressed: _setSelectedBoundaryToNow,
                icon: const Icon(LucideIcons.clock3, size: 14),
                label: Text(l10n.startAtNow),
              ),
            ],
          ),
          _buildSplitRow(context, line, wordIndex),
        ],
      ),
    );
  }

  // Tap-a-letter syllable splitter for the selected segment's token:
  // tapping a letter toggles the segment boundary before it, so a word
  // can sweep slow-then-fast across its syllables.
  Widget _buildSplitRow(
    BuildContext context,
    EditableLyricLine line,
    int segmentIndex,
  ) {
    final layout = line.segmentLayout;
    if (segmentIndex < 0 || segmentIndex >= layout.length) {
      return const SizedBox.shrink();
    }
    final tokenIndex = layout[segmentIndex].tokenIndex;
    final core = line.tokens[tokenIndex].trim();
    if (core.length < 2) return const SizedBox.shrink();

    final breaks = line.segmentBreaks;
    final tokenBreaks = breaks != null && tokenIndex < breaks.length
        ? breaks[tokenIndex]
        : const <int>[];
    final selected = layout[segmentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text(
          l10n.syllablesTapALetterToSplit,
          style: TextStyle(color: context.adaptiveTextSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 0,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var c = 0; c < core.length; c++) ...[
              if (tokenBreaks.contains(c))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 2,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: c == 0
                    ? null
                    : () => _toggleSegmentBreak(tokenIndex, c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: c >= selected.charStart && c < selected.charEnd
                          ? AppColors.accentDim
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    core[c],
                    style: TextStyle(
                      color: context.adaptiveTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildShiftTools(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.timeShift,
            style: TextStyle(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.moveEveryStampedLyricForwardOr,
            style: TextStyle(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _shiftAll(const Duration(milliseconds: -500)),
                child: const Text('-500ms'),
              ),
              OutlinedButton(
                onPressed: () => _shiftAll(const Duration(milliseconds: -100)),
                child: const Text('-100ms'),
              ),
              OutlinedButton(
                onPressed: () => _shiftAll(const Duration(milliseconds: 100)),
                child: const Text('+100ms'),
              ),
              OutlinedButton(
                onPressed: () => _shiftAll(const Duration(milliseconds: 500)),
                child: const Text('+500ms'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.badgeInfo,
            size: 16,
            color: context.adaptiveTextSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.saveCreatesAnLrcFileIf,
              style: TextStyle(
                color: context.adaptiveTextSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> readTextFromPickedLyricsFile(PlatformFile file) async {
  if (file.bytes != null) {
    return _decodeLyricsBytes(file.bytes!);
  }

  final path = file.path;
  if (path == null || path.isEmpty) return null;
  final diskFile = File(path);
  if (!await diskFile.exists()) return null;
  final bytes = await diskFile.readAsBytes();
  return _decodeLyricsBytes(bytes);
}

String? _decodeLyricsBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    try {
      return latin1.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
