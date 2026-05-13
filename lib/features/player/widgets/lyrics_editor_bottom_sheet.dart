import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum LyricsEditorViewMode { simple, advanced }

class LyricsEditorResult {
  final String message;
  final LyricsData lyricsData;

  const LyricsEditorResult({required this.message, required this.lyricsData});
}

class LyricsEditorBottomSheet extends StatefulWidget {
  final Song song;
  final PlayerService playerService;
  final LyricsService lyricsService;
  final LyricsData? initialLyrics;

  const LyricsEditorBottomSheet({
    super.key,
    required this.song,
    required this.playerService,
    required this.lyricsService,
    this.initialLyrics,
  });

  static Future<LyricsEditorResult?> show({
    required BuildContext context,
    required Song song,
    required PlayerService playerService,
    required LyricsService lyricsService,
    LyricsData? initialLyrics,
  }) {
    return showModalBottomSheet<LyricsEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        maxHeightRatio: 0.94,
        child: LyricsEditorBottomSheet(
          song: song,
          playerService: playerService,
          lyricsService: lyricsService,
          initialLyrics: initialLyrics,
        ),
      ),
    );
  }

  @override
  State<LyricsEditorBottomSheet> createState() =>
      _LyricsEditorBottomSheetState();
}

class _LyricsEditorBottomSheetState extends State<LyricsEditorBottomSheet> {
  final TextEditingController _lyricsTextController = TextEditingController();
  final TextEditingController _currentTimeController = TextEditingController();

  LyricsEditorViewMode _viewMode = LyricsEditorViewMode.simple;
  List<_EditableLyricLine> _lines = const [];
  int _selectedLineIndex = 0;
  bool _autoAdvance = true;
  bool _isSaving = false;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.playerService.positionNotifier.value;
    _lines = _seedLines(widget.initialLyrics);
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
    super.dispose();
  }

  List<_EditableLyricLine> _seedLines(LyricsData? lyrics) {
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const [_EditableLyricLine(text: '', timestamp: null)];
    }

    return lyrics.lines
        .map(
          (line) => _EditableLyricLine(
            text: line.text,
            timestamp: lyrics.isSynchronized ? line.timestamp : null,
          ),
        )
        .toList();
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
    final rows = _lyricsTextController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final nextLines = <_EditableLyricLine>[];

    for (var index = 0; index < rows.length; index++) {
      nextLines.add(
        _EditableLyricLine(
          text: rows[index],
          timestamp: index < _lines.length ? _lines[index].timestamp : null,
        ),
      );
    }

    while (nextLines.isNotEmpty && nextLines.last.text.isEmpty) {
      nextLines.removeLast();
    }

    if (nextLines.isEmpty) {
      nextLines.add(const _EditableLyricLine(text: '', timestamp: null));
    }

    setState(() {
      _lines = nextLines;
      if (_selectedLineIndex >= _lines.length) {
        _selectedLineIndex = _lines.length - 1;
      }
      if (_selectedLineIndex < 0) {
        _selectedLineIndex = 0;
      }
    });
  }

  int get _stampedLineCount => _lines
      .where((line) => line.text.trim().isNotEmpty && line.timestamp != null)
      .length;

  int get _usableLineCount =>
      _lines.where((line) => line.text.trim().isNotEmpty).length;

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
    });
  }

  void _stampSelectedLine({required bool advance}) {
    if (_selectedLineIndex < 0 || _selectedLineIndex >= _lines.length) return;
    final current = _lines[_selectedLineIndex];
    if (current.text.trim().isEmpty) return;

    setState(() {
      _lines = [
        for (var index = 0; index < _lines.length; index++)
          if (index == _selectedLineIndex)
            _lines[index].copyWith(timestamp: _currentPosition)
          else
            _lines[index],
      ];
      if (advance && _selectedLineIndex < _lines.length - 1) {
        _selectedLineIndex += 1;
      }
    });
  }

  void _clearSelectedTimestamp() {
    if (_selectedLineIndex < 0 || _selectedLineIndex >= _lines.length) return;
    setState(() {
      _lines = [
        for (var index = 0; index < _lines.length; index++)
          if (index == _selectedLineIndex)
            _lines[index].copyWith(timestamp: null)
          else
            _lines[index],
      ];
    });
  }

  void _shiftAll(Duration delta) {
    setState(() {
      _lines = _lines
          .map(
            (line) => line.timestamp == null
                ? line
                : line.copyWith(
                    timestamp: Duration(
                      milliseconds:
                          (line.timestamp!.inMilliseconds +
                                  delta.inMilliseconds)
                              .clamp(0, 1 << 31),
                    ),
                  ),
          )
          .toList();
    });
  }

  void _applyTimestampText(int index, String value) {
    final normalized = value.replaceAll('[', '').replaceAll(']', '').trim();
    if (normalized.isEmpty) {
      setState(() {
        _lines = [
          for (var lineIndex = 0; lineIndex < _lines.length; lineIndex++)
            if (lineIndex == index)
              _lines[lineIndex].copyWith(timestamp: null)
            else
              _lines[lineIndex],
        ];
      });
      return;
    }

    final parsed = widget.lyricsService.parseTimestamp(normalized);
    if (parsed == null) return;

    setState(() {
      _lines = [
        for (var lineIndex = 0; lineIndex < _lines.length; lineIndex++)
          if (lineIndex == index)
            _lines[lineIndex].copyWith(timestamp: parsed)
          else
            _lines[lineIndex],
      ];
    });
  }

  List<LyricsLine> _buildNormalizedLyricsLines() {
    final sourceLines = _lines
        .where((line) => line.text.trim().isNotEmpty)
        .map((line) => line.copyWith(text: line.text.trim()))
        .toList();
    if (sourceLines.isEmpty) return const [];

    final filled = List<Duration?>.from(
      sourceLines.map((line) => line.timestamp),
    );
    final stampedIndices = <int>[
      for (var index = 0; index < sourceLines.length; index++)
        if (filled[index] != null) index,
    ];

    if (stampedIndices.isEmpty) {
      return [
        for (var index = 0; index < sourceLines.length; index++)
          LyricsLine(
            timestamp: Duration(seconds: index * 2),
            text: sourceLines[index].text,
          ),
      ];
    }

    const defaultStep = Duration(seconds: 2);
    final firstStampedIndex = stampedIndices.first;
    final firstStampedTime = filled[firstStampedIndex]!;
    for (var index = firstStampedIndex - 1; index >= 0; index--) {
      final backfilled =
          firstStampedTime -
          Duration(
            seconds: defaultStep.inSeconds * (firstStampedIndex - index),
          );
      filled[index] = backfilled.isNegative ? Duration.zero : backfilled;
    }

    for (
      var stampIndex = 0;
      stampIndex < stampedIndices.length - 1;
      stampIndex++
    ) {
      final startIndex = stampedIndices[stampIndex];
      final endIndex = stampedIndices[stampIndex + 1];
      final start = filled[startIndex]!;
      final end = filled[endIndex]!;
      final gapCount = endIndex - startIndex - 1;
      if (gapCount <= 0) continue;

      final deltaMs = end.inMilliseconds - start.inMilliseconds;
      final stepMs = gapCount <= 0 ? 0 : deltaMs ~/ (gapCount + 1);
      for (var offset = 1; offset <= gapCount; offset++) {
        filled[startIndex + offset] = Duration(
          milliseconds: start.inMilliseconds + (stepMs * offset),
        );
      }
    }

    final lastStampedIndex = stampedIndices.last;
    for (var index = lastStampedIndex + 1; index < filled.length; index++) {
      final previous = filled[index - 1] ?? Duration.zero;
      filled[index] = previous + defaultStep;
    }

    var lastMs = 0;
    final normalized = <LyricsLine>[];
    for (var index = 0; index < sourceLines.length; index++) {
      final timestamp = filled[index] ?? Duration(milliseconds: lastMs);
      final nextMs = timestamp.inMilliseconds < lastMs
          ? lastMs
          : timestamp.inMilliseconds;
      lastMs = nextMs;
      normalized.add(
        LyricsLine(
          timestamp: Duration(milliseconds: nextMs),
          text: sourceLines[index].text,
        ),
      );
    }
    return normalized;
  }

  Future<void> _save() async {
    final normalizedLines = _buildNormalizedLyricsLines();
    if (normalizedLines.isEmpty) {
      _showMessage('Add at least one lyric line first.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final lrcContent = widget.lyricsService.buildLrcContent(
        lines: normalizedLines,
        song: widget.song,
      );
      final result = await widget.lyricsService.saveLyricsForSong(
        song: widget.song,
        content: lrcContent,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        LyricsEditorResult(
          message: result.savedBesideSong
              ? 'Saved lyrics beside the song as an `.lrc` file.'
              : 'Saved lyrics in Flick and linked them to this song.',
          lyricsData: result.data,
        ),
      );
    } catch (_) {
      _showMessage('Could not save the lyrics file.');
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

  Future<void> _showInstructions() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Lyrics Sync Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simple mode',
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Paste or type one lyric line per row.\n'
                '2. Play the song.\n'
                '3. Select the current lyric line.\n'
                '4. Tap "Stamp & Next" when you hear that line.\n'
                '5. Save when done.',
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Advanced mode',
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1. Edit timestamps directly for each line.\n'
                '2. Use "Use Current Time" to capture the live playback time.\n'
                '3. Use the shift controls to move all stamped lyrics together.\n'
                '4. Save to generate the final `.lrc` file.',
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tips',
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '- "Use Existing File" links an `.lrc`, `.txt`, or `.xml` file.\n'
                '- If some lines are not stamped, Flick fills their times automatically.\n'
                '- Save writes beside the song when possible, otherwise Flick stores a linked copy.',
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lyrics Sync Studio',
                    style: TextStyle(
                      color: context.adaptiveTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.title,
                    style: TextStyle(
                      color: context.adaptiveTextSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
            IconButton(
              onPressed: _isSaving ? null : _showInstructions,
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'Instructions',
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        _buildModePicker(context),
        const SizedBox(height: AppConstants.spacingMd),
        _buildStatusCards(context),
        const SizedBox(height: AppConstants.spacingMd),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLyricsTextEditor(context),
                const SizedBox(height: AppConstants.spacingMd),
                if (_viewMode == LyricsEditorViewMode.simple)
                  _buildSimpleSyncView(context)
                else
                  _buildAdvancedSyncView(context),
                const SizedBox(height: AppConstants.spacingMd),
                _buildSaveNotice(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save LRC'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModePicker(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: LyricsEditorViewMode.values.map((mode) {
        final selected = mode == _viewMode;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            setState(() {
              _viewMode = mode;
            });
          },
          label: Text(
            mode == LyricsEditorViewMode.simple
                ? 'Simple Mode'
                : 'Advanced Mode',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusCards(BuildContext context) {
    Widget card(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: context.adaptiveTextSecondary),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: context.adaptiveTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(Icons.format_list_bulleted_rounded, 'Lines', '$_usableLineCount'),
        const SizedBox(width: AppConstants.spacingSm),
        card(LucideIcons.clock3, 'Stamped', '$_stampedLineCount'),
        const SizedBox(width: AppConstants.spacingSm),
        card(LucideIcons.timer, 'Now', _currentTimeController.text),
      ],
    );
  }

  Widget _buildLyricsTextEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lyrics Text',
          style: TextStyle(
            color: context.adaptiveTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'One line per lyric row. The sync tools below attach timestamps to these lines.',
          style: TextStyle(color: context.adaptiveTextSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _lyricsTextController,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: 'Paste or type the song lyrics here',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSyncView(BuildContext context) {
    final selectedLine =
        _selectedLineIndex >= 0 && _selectedLineIndex < _lines.length
        ? _lines[_selectedLineIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Sync',
          style: TextStyle(
            color: context.adaptiveTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildPlaybackTools(context),
        const SizedBox(height: AppConstants.spacingSm),
        Container(
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
                  IconButton(
                    onPressed: _selectedLineIndex > 0
                        ? () => _selectLine(_selectedLineIndex - 1)
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Selected line ${_selectedLineIndex + 1} of ${_lines.length}',
                          style: TextStyle(
                            color: context.adaptiveTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedLine?.text.trim().isNotEmpty == true
                              ? selectedLine!.text
                              : 'Pick a lyric line from the list below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.adaptiveTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectedLine?.timestamp != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.lyricsService.formatTimestamp(
                              selectedLine!.timestamp!,
                            ),
                            style: TextStyle(
                              color: context.adaptiveTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _selectedLineIndex < _lines.length - 1
                        ? () => _selectLine(_selectedLineIndex + 1)
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: selectedLine?.text.trim().isNotEmpty == true
                        ? () => _stampSelectedLine(advance: _autoAdvance)
                        : null,
                    icon: const Icon(LucideIcons.clock3),
                    label: Text(_autoAdvance ? 'Stamp & Next' : 'Stamp Now'),
                  ),
                  OutlinedButton.icon(
                    onPressed: selectedLine?.timestamp != null
                        ? _clearSelectedTimestamp
                        : null,
                    icon: const Icon(LucideIcons.eraser),
                    label: const Text('Clear Stamp'),
                  ),
                  FilterChip(
                    selected: _autoAdvance,
                    onSelected: (value) {
                      setState(() {
                        _autoAdvance = value;
                      });
                    },
                    label: const Text('Auto Advance'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _buildShiftTools(context),
        const SizedBox(height: AppConstants.spacingSm),
        _buildLinePickerList(context, compact: false),
      ],
    );
  }

  Widget _buildAdvancedSyncView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Sync',
          style: TextStyle(
            color: context.adaptiveTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildPlaybackTools(context),
        const SizedBox(height: AppConstants.spacingSm),
        _buildShiftTools(context),
        const SizedBox(height: AppConstants.spacingSm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lines.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final line = _lines[index];
            final timestampText = line.timestamp == null
                ? ''
                : widget.lyricsService
                      .formatTimestamp(line.timestamp!)
                      .replaceAll('[', '')
                      .replaceAll(']', '');
            return Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: index == _selectedLineIndex
                    ? AppColors.surfaceLight.withValues(alpha: 0.95)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: index == _selectedLineIndex
                      ? AppColors.accentDim
                      : AppColors.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Line ${index + 1}',
                        style: TextStyle(
                          color: context.adaptiveTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          _selectLine(index);
                          _stampSelectedLine(advance: false);
                        },
                        icon: const Icon(LucideIcons.clock3, size: 14),
                        label: const Text('Use Current Time'),
                      ),
                    ],
                  ),
                  Text(
                    line.text.isEmpty ? '(Empty line)' : line.text,
                    style: TextStyle(
                      color: context.adaptiveTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: timestampText,
                    onTap: () => _selectLine(index),
                    onChanged: (value) => _applyTimestampText(index, value),
                    decoration: InputDecoration(
                      labelText: 'Timestamp',
                      hintText: '00:12.34',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaybackTools(BuildContext context) {
    return Container(
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
            'Playback Assist',
            style: TextStyle(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _seekBy(const Duration(seconds: -2)),
                child: const Text('-2s'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: widget.playerService.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return FilledButton.icon(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      isPlaying ? LucideIcons.pause : LucideIcons.play,
                    ),
                    label: Text(isPlaying ? 'Pause' : 'Play'),
                  );
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _seekBy(const Duration(seconds: 2)),
                child: const Text('+2s'),
              ),
              const Spacer(),
              SizedBox(
                width: 108,
                child: TextField(
                  controller: _currentTimeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Now',
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
        ],
      ),
    );
  }

  Widget _buildShiftTools(BuildContext context) {
    return Container(
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
            'Time Shift',
            style: TextStyle(
              color: context.adaptiveTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Move every stamped lyric forward or backward together.',
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

  Widget _buildLinePickerList(BuildContext context, {required bool compact}) {
    return Container(
      constraints: BoxConstraints(maxHeight: compact ? 200 : 280),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _lines.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.glassBorder),
        itemBuilder: (context, index) {
          final line = _lines[index];
          final selected = index == _selectedLineIndex;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectLine(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: AppConstants.spacingSm,
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
                            line.text.isEmpty ? '(Empty line)' : line.text,
                            maxLines: compact ? 1 : 2,
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
                                ? 'Not stamped yet'
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
                  ],
                ),
              ),
            ),
          );
        },
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
              'Save creates an `.lrc` file. If some lines are not stamped yet, Flick fills their times automatically so the file stays usable.',
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

class _EditableLyricLine {
  final String text;
  final Duration? timestamp;

  const _EditableLyricLine({required this.text, required this.timestamp});

  _EditableLyricLine copyWith({
    String? text,
    Duration? timestamp,
    bool clearTimestamp = false,
  }) {
    return _EditableLyricLine(
      text: text ?? this.text,
      timestamp: clearTimestamp ? null : (timestamp ?? this.timestamp),
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
