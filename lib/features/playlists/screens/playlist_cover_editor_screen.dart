import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/features/playlists/utils/playlist_cover_crop_math.dart';
import 'package:flick/features/playlists/utils/playlist_cover_edit.dart';
import 'package:flick/features/playlists/utils/playlist_cover_render.dart';
import 'package:flick/features/playlists/utils/playlist_cover_vignette.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';

/// Full-screen editor for a user-selected playlist cover.
///
/// Pops with the path to a temporary JPEG, which the caller copies into
/// durable storage before deleting it.
class PlaylistCoverEditorScreen extends StatefulWidget {
  const PlaylistCoverEditorScreen({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  State<PlaylistCoverEditorScreen> createState() =>
      _PlaylistCoverEditorScreenState();
}

enum _OrientationAction {
  rotateLeft,
  rotateRight,
  flipHorizontal,
  flipVertical,
}

class _PlaylistCoverEditorScreenState extends State<PlaylistCoverEditorScreen> {
  static const int _cropTab = 0;
  static const int _adjustTab = 1;
  static const int _filtersTab = 2;

  final TransformationController _controller = TransformationController();
  final ScrollController _panelScrollController = ScrollController();

  PlaylistCoverEdit _edit = const PlaylistCoverEdit();
  Uint8List? _imageBytes;
  Size? _imageSize;
  bool _preparing = true;
  bool _failed = false;
  bool _saving = false;
  bool _viewportReady = false;
  bool _cropChanged = false;
  bool _suppressCropDirty = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  double? _viewportSide;
  int _selectedTab = _cropTab;

  Uint8List? _filterThumbnailBytes;
  bool _filterThumbnailLoading = false;
  bool _pendingFilterThumbnail = false;
  int _thumbnailRequest = 0;

  bool get _dirty => _edit.hasEdits || _cropChanged;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
    _prepare();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTransformChanged)
      ..dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (_suppressCropDirty) return;
    if (_cropChanged) return;
    setState(() {
      _cropChanged = true;
      _filterThumbnailBytes = null;
    });
  }

  Future<void> _prepare() async {
    try {
      final data = await compute(preparePlaylistCover, widget.sourcePath);
      if (!mounted) return;
      setState(() {
        _imageBytes = data['bytes'] as Uint8List;
        _imageSize = Size(
          (data['width'] as int).toDouble(),
          (data['height'] as int).toDouble(),
        );
        _preparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _failed = true;
      });
    }
  }

  void _setTransform(Matrix4 value) {
    _suppressCropDirty = true;
    _controller.value = value;
    _suppressCropDirty = false;
  }

  void _centerViewport(double side) {
    if (_viewportSide == side) return;
    _viewportSide = side;
    _viewportReady = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewportSide != side) return;
      final imageSize = _imageSize;
      if (imageSize == null) return;

      final oriented = _edit.orientedSize(imageSize);
      final coverScale = math.max(
        side / oriented.width,
        side / oriented.height,
      );
      final childWidth = oriented.width * coverScale;
      final childHeight = oriented.height * coverScale;
      _setTransform(
        Matrix4.identity()..setTranslationRaw(
          (side - childWidth) / 2,
          (side - childHeight) / 2,
          0,
        ),
      );
      setState(() => _viewportReady = true);

      if (_pendingFilterThumbnail && _selectedTab == _filtersTab) {
        _pendingFilterThumbnail = false;
        _prepareFilterThumbnail();
      }
    });
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (index == _filtersTab) {
      _prepareFilterThumbnail();
    }
  }

  void _updateEdit(PlaylistCoverEdit edit) {
    setState(() => _edit = edit);
  }

  void _resetAll() {
    if (_saving) return;

    final imageSize = _imageSize;
    final side = _viewportSide;
    setState(() {
      _edit = const PlaylistCoverEdit();
      _cropChanged = false;
      _filterThumbnailBytes = null;
    });

    if (imageSize != null && side != null) {
      final oriented = _edit.orientedSize(imageSize);
      final coverScale = math.max(
        side / oriented.width,
        side / oriented.height,
      );
      final childWidth = oriented.width * coverScale;
      final childHeight = oriented.height * coverScale;
      _setTransform(
        Matrix4.identity()..setTranslationRaw(
          (side - childWidth) / 2,
          (side - childHeight) / 2,
          0,
        ),
      );
    }

    if (_selectedTab == _filtersTab) {
      _prepareFilterThumbnail();
    }
  }

  void _applyOrientation(_OrientationAction action) {
    final imageSize = _imageSize;
    final side = _viewportSide;
    if (!_viewportReady || imageSize == null || side == null) return;

    final viewport = Size.square(side);
    final oldOriented = _edit.orientedSize(imageSize);
    final oldCrop = calculatePlaylistCoverCrop(
      viewportSize: viewport,
      imageSize: oldOriented,
      transform: _controller.value,
    );
    if (oldCrop.width <= 0) return;

    final nextEdit = switch (action) {
      _OrientationAction.rotateLeft => _edit.rotateCounterClockwise(),
      _OrientationAction.rotateRight => _edit.rotateClockwise(),
      _OrientationAction.flipHorizontal => _edit.flipHorizontal(),
      _OrientationAction.flipVertical => _edit.flipVertical(),
    };
    final nextOriented = nextEdit.orientedSize(imageSize);
    final center = _mapCropCenter(oldCrop.center, oldOriented, action);

    setState(() {
      _edit = nextEdit;
      _filterThumbnailBytes = null;
    });
    _setTransform(
      calculatePlaylistCoverTransform(
        viewportSize: viewport,
        imageSize: nextOriented,
        cropCenter: center,
        cropSide: oldCrop.width,
      ),
    );
  }

  Offset _mapCropCenter(
    Offset center,
    Size oldSize,
    _OrientationAction action,
  ) {
    return switch (action) {
      _OrientationAction.rotateLeft => Offset(
        center.dy,
        oldSize.width - center.dx,
      ),
      _OrientationAction.rotateRight => Offset(
        oldSize.height - center.dy,
        center.dx,
      ),
      _OrientationAction.flipHorizontal => Offset(
        oldSize.width - center.dx,
        center.dy,
      ),
      _OrientationAction.flipVertical => Offset(
        center.dx,
        oldSize.height - center.dy,
      ),
    };
  }

  Future<void> _save() async {
    final imageSize = _imageSize;
    final side = _viewportSide;
    if (_saving || !_viewportReady || imageSize == null || side == null) {
      return;
    }

    final oriented = _edit.orientedSize(imageSize);
    final crop = calculatePlaylistCoverCrop(
      viewportSize: Size.square(side),
      imageSize: oriented,
      transform: _controller.value,
    );
    if (crop.width <= 0) return;

    setState(() => _saving = true);
    try {
      final bytes = await compute(renderPlaylistCover, <String, Object>{
        'path': widget.sourcePath,
        'preparedWidth': imageSize.width.round(),
        'preparedHeight': imageSize.height.round(),
        'quarterTurns': _edit.quarterTurns,
        'mirrored': _edit.mirrored,
        'cropLeft': crop.left,
        'cropTop': crop.top,
        'cropSide': crop.width,
        'maxOutput': 1600,
        'quality': 90,
        'applyEffects': true,
        'colorMatrix': _edit.colorMatrix.values,
        'vignette': _edit.vignette,
      });
      if (bytes == null) {
        throw const FormatException('Could not render playlist cover');
      }
      if (!mounted) return;

      final temporaryDirectory = await getTemporaryDirectory();
      final directory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'playlist_cover_edit',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'playlist_cover_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() => _saving = false);
      _popWithResult(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showFlickSnackBar(
        SnackBar(
          content: Text(context.l10n.englishForFilipino.couldNotUpdatePlaylistCover),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _prepareFilterThumbnail() async {
    final imageSize = _imageSize;
    final side = _viewportSide;
    if (!_viewportReady || imageSize == null || side == null) {
      _pendingFilterThumbnail = true;
      return;
    }
    _pendingFilterThumbnail = false;

    final oriented = _edit.orientedSize(imageSize);
    final crop = calculatePlaylistCoverCrop(
      viewportSize: Size.square(side),
      imageSize: oriented,
      transform: _controller.value,
    );
    if (crop.width <= 0) return;

    final requestId = ++_thumbnailRequest;
    setState(() => _filterThumbnailLoading = true);
    try {
      final bytes = await compute(renderPlaylistCover, <String, Object>{
        'path': widget.sourcePath,
        'preparedWidth': imageSize.width.round(),
        'preparedHeight': imageSize.height.round(),
        'quarterTurns': _edit.quarterTurns,
        'mirrored': _edit.mirrored,
        'cropLeft': crop.left,
        'cropTop': crop.top,
        'cropSide': crop.width,
        'maxOutput': 256,
        'quality': 80,
        'applyEffects': false,
      });
      if (!mounted || requestId != _thumbnailRequest) return;
      setState(() {
        _filterThumbnailBytes = bytes;
        _filterThumbnailLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _thumbnailRequest) return;
      setState(() => _filterThumbnailLoading = false);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_discardDialogOpen) return;
    _discardDialogOpen = true;
    final l10n = context.l10n;
    final confirmed = await FlickDialogs.confirm(
      context,
      title: l10n.discardChanges2,
      message: l10n.youHaveUnsavedChangesAreYou,
      confirmLabel: l10n.discard,
      destructive: true,
    );
    _discardDialogOpen = false;
    if (confirmed && mounted) {
      _popWithResult(null);
    }
  }

  void _popWithResult(Object? result) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final landscape = media.size.width > media.size.height;

    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        if (_dirty) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        // Leave the shell's bottom-bar clearance transparent so the ambient
        // background stays visible behind the floating mini player and
        // navigation bar, matching the rest of the app.
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: l10n.close,
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.x),
          ),
          title: Text(l10n.editCover),
          actions: [
            TextButton(
              onPressed: _saving || (!_edit.hasEdits && !_cropChanged)
                  ? null
                  : _resetAll,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              child: Text(l10n.reset),
            ),
            TextButton(
              onPressed: !_viewportReady || _saving || _failed ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.save),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Opaque canvas behind the editor content.
            Positioned.fill(
              bottom: bottomInset,
              child: const ColoredBox(color: Colors.black),
            ),
            // Keep the shell's bottom-bar zone on the editor's surface color
            // so the floating mini player and navigation bar read as gray
            // glass instead of picking up the ambient artwork behind them.
            if (bottomInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomInset,
                child: const ColoredBox(color: AppColors.surface),
              ),
            SafeArea(
              top: false,
              child: _preparing
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                  ? _buildError(l10n)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final preview = _buildPreview();
                        final panel = _buildPanel(l10n, landscape: landscape);
                        if (landscape) {
                          return Row(
                            children: [
                              Expanded(child: preview),
                              SizedBox(width: 300, child: panel),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Expanded(child: preview),
                            SizedBox(height: 260, child: panel),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.imageOff,
              size: 32,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.couldNotOpenThatPhotoTry,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(constraints.maxWidth, constraints.maxHeight);
        final side = math.max(1.0, available - 32);
        if (_imageSize != null && _imageBytes != null) {
          _centerViewport(side);
        }

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: !_viewportReady || _imageSize == null || _imageBytes == null
                ? const Center(child: CircularProgressIndicator())
                : ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          transformationController: _controller,
                          constrained: false,
                          minScale: 1,
                          maxScale: 4,
                          child: _buildImage(side),
                        ),
                        if (_edit.vignette > 0)
                          Positioned.fill(
                            child: _VignetteOverlay(amount: _edit.vignette),
                          ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(
                              showGrid: _selectedTab == _cropTab,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildImage(double side) {
    final imageSize = _imageSize!;
    final oriented = _edit.orientedSize(imageSize);
    final coverScale = math.max(side / oriented.width, side / oriented.height);
    final displayWidth = imageSize.width * coverScale;
    final displayHeight = imageSize.height * coverScale;

    Widget image = Image.memory(
      _imageBytes!,
      width: displayWidth,
      height: displayHeight,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
    final matrix = _edit.colorMatrix;
    if (!matrix.isIdentity) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix.values),
        child: image,
      );
    }
    image = RotatedBox(
      quarterTurns: _edit.quarterTurns,
      child: Transform.flip(flipX: _edit.mirrored, child: image),
    );

    return SizedBox(
      width: oriented.width * coverScale,
      height: oriented.height * coverScale,
      child: image,
    );
  }

  Widget _buildPanel(AppLocalizations l10n, {required bool landscape}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: landscape
            ? null
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: landscape
            ? const Border(left: BorderSide(color: AppColors.glassBorder))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildTab(l10n.crop, _cropTab),
              _buildTab(l10n.adjust, _adjustTab),
              _buildTab(l10n.filters, _filtersTab),
            ],
          ),
          Expanded(
            child: Scrollbar(
              controller: _panelScrollController,
              // The Adjust tab is the one that overflows on phones. Keep the
              // thumb visible there so it is obvious that more controls are
              // below the fold.
              thumbVisibility: _selectedTab == _adjustTab,
              thickness: 3,
              radius: const Radius.circular(2),
              child: SingleChildScrollView(
                controller: _panelScrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: switch (_selectedTab) {
                  _adjustTab => _buildAdjustTools(l10n),
                  _filtersTab => _buildFilterTools(l10n),
                  _ => _buildCropTools(l10n),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropTools(AppLocalizations l10n) {
    final enabled = _viewportReady && !_saving;
    return Column(
      children: [
        Row(
          children: [
            _toolButton(
              icon: LucideIcons.rotateCcw,
              label: l10n.rotateLeft,
              onPressed: enabled
                  ? () => _applyOrientation(_OrientationAction.rotateLeft)
                  : null,
            ),
            _toolButton(
              icon: LucideIcons.rotateCw,
              label: l10n.rotateRight,
              onPressed: enabled
                  ? () => _applyOrientation(_OrientationAction.rotateRight)
                  : null,
            ),
            _toolButton(
              icon: LucideIcons.flipHorizontal,
              label: l10n.flipHorizontal,
              onPressed: enabled
                  ? () => _applyOrientation(_OrientationAction.flipHorizontal)
                  : null,
            ),
            _toolButton(
              icon: LucideIcons.flipVertical,
              label: l10n.flipVertical,
              onPressed: enabled
                  ? () => _applyOrientation(_OrientationAction.flipVertical)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.cropCoverHint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final color = onPressed == null
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(color: color, fontSize: 13, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustTools(AppLocalizations l10n) {
    return Column(
      children: [
        _adjustSlider(
          label: l10n.brightness,
          value: _edit.brightness,
          min: -1,
          max: 1,
          onChanged: (value) => _updateEdit(_edit.copyWith(brightness: value)),
        ),
        _adjustSlider(
          label: l10n.contrast,
          value: _edit.contrast,
          min: -1,
          max: 1,
          onChanged: (value) => _updateEdit(_edit.copyWith(contrast: value)),
        ),
        _adjustSlider(
          label: l10n.saturation,
          value: _edit.saturation,
          min: -1,
          max: 1,
          onChanged: (value) => _updateEdit(_edit.copyWith(saturation: value)),
        ),
        _adjustSlider(
          label: l10n.warmth,
          value: _edit.warmth,
          min: -1,
          max: 1,
          onChanged: (value) => _updateEdit(_edit.copyWith(warmth: value)),
        ),
        _adjustSlider(
          label: l10n.vignette,
          value: _edit.vignette,
          min: 0,
          max: 1,
          onChanged: (value) => _updateEdit(_edit.copyWith(vignette: value)),
        ),
      ],
    );
  }

  Widget _adjustSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final display = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: _saving ? null : onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$display',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTools(AppLocalizations l10n) {
    final bytes = _filterThumbnailBytes;
    if (bytes == null) {
      if (_filterThumbnailLoading) {
        return const SizedBox(
          height: 104,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return SizedBox(
        height: 104,
        child: Center(
          child: IconButton(
            tooltip: l10n.filters,
            onPressed: _prepareFilterThumbnail,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PlaylistCoverFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final filter = PlaylistCoverFilter.values[index];
          return _FilterTile(
            label: _filterLabel(l10n, filter),
            thumbnailBytes: bytes,
            matrix: _edit.manualColorMatrix.compose(filter.matrix),
            vignette: _edit.vignette,
            selected: _edit.filter == filter,
            onTap: () => _updateEdit(_edit.copyWith(filter: filter)),
          );
        },
      ),
    );
  }

  String _filterLabel(AppLocalizations l10n, PlaylistCoverFilter filter) {
    return switch (filter) {
      PlaylistCoverFilter.original => l10n.filterOriginal,
      PlaylistCoverFilter.mono => l10n.filterMono,
      PlaylistCoverFilter.warm => l10n.filterWarm,
      PlaylistCoverFilter.cool => l10n.filterCool,
      PlaylistCoverFilter.fade => l10n.filterFade,
      PlaylistCoverFilter.punch => l10n.filterPunch,
      PlaylistCoverFilter.noir => l10n.filterNoir,
    };
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.thumbnailBytes,
    required this.matrix,
    required this.vignette,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Uint8List thumbnailBytes;
  final CoverColorMatrix matrix;
  final double vignette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.memory(
      thumbnailBytes,
      width: 68,
      height: 68,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (!matrix.isIdentity) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix.values),
        child: image,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.white : AppColors.glassBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (vignette > 0) _VignetteOverlay(amount: vignette),
                  if (selected)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();

    const steps = 32;
    final stops = <double>[for (var i = 0; i <= steps; i++) i / steps];
    final colors = <Color>[
      for (final distance in stops)
        Color.fromRGBO(
          0,
          0,
          0,
          playlistCoverVignetteFactor(
            normalizedDistance: distance,
            amount: amount,
          ),
        ),
    ];

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: playlistCoverVignetteRadius,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white54;
    canvas.drawRect(Offset.zero & size, border);

    if (!showGrid) return;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white24;
    final thirdX = size.width / 3;
    final thirdY = size.height / 3;
    canvas.drawLine(Offset(thirdX, 0), Offset(thirdX, size.height), grid);
    canvas.drawLine(
      Offset(thirdX * 2, 0),
      Offset(thirdX * 2, size.height),
      grid,
    );
    canvas.drawLine(Offset(0, thirdY), Offset(size.width, thirdY), grid);
    canvas.drawLine(
      Offset(0, thirdY * 2),
      Offset(size.width, thirdY * 2),
      grid,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.showGrid != showGrid;
  }
}
