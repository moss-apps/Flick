import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/recently_played_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../services/color_extraction_service.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/gallery_save_service.dart';
import '../../../widgets/common/display_mode_wrapper.dart';
import '../widgets/replay_card_options.dart';
import '../widgets/replay_poster.dart';
import '../widgets/replay_style.dart';

enum _Background { original, album, camera, gallery }

enum _Panel { look, background, details }

/// The recap is frozen when this route opens, including during image capture.
class ReplayStudioScreen extends ConsumerStatefulWidget {
  final ListeningRecap recap;
  final ReplayCardOptions initialOptions;
  final ValueChanged<ReplayCardOptions>? onOptionsChanged;

  const ReplayStudioScreen({
    super.key,
    required this.recap,
    this.initialOptions = const ReplayCardOptions(),
    this.onOptionsChanged,
  });

  @override
  ConsumerState<ReplayStudioScreen> createState() => _ReplayStudioScreenState();
}

class _ReplayStudioScreenState extends ConsumerState<ReplayStudioScreen> {
  final _boundaryKey = GlobalKey();
  final _gallery = GallerySaveService();
  final _csv = CsvExportService();
  final _picker = ImagePicker();
  final _controlsScroll = ScrollController();
  late ReplayCardOptions _options = widget.initialOptions;
  _Panel _panel = _Panel.look;
  ReplayPosterType _type = ReplayPosterType.overview;
  _Background _background = _Background.original;
  String? _cameraPath;
  String? _galleryPath;
  bool _busy = false;
  bool _saved = false;
  bool _capturing = false;
  bool _inspecting = false;
  bool _sampling = false;
  int _colorGeneration = 0;
  String? _error;

  @override
  void dispose() {
    _colorGeneration++;
    _controlsScroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.pop(context, _options);

  void _resetDesign() {
    if (_busy) return;
    _colorGeneration++;
    setState(() => _sampling = false);
    _setOptions(const ReplayCardOptions());
  }

  void _setOptions(ReplayCardOptions options) {
    _change(() => _options = options);
    widget.onOptionsChanged?.call(_options);
  }

  Future<void> _setLook(ReplayLook look) async {
    if (_busy) return;
    final generation = ++_colorGeneration;
    _setOptions(_options.copyWith(look: look));
    if (look != ReplayLook.artwork || _options.artworkColor != null) {
      setState(() => _sampling = false);
      return;
    }
    setState(() => _sampling = true);
    final color = await ColorExtractionService().extractDominantColor(
      _albumPath,
    );
    if (!mounted || generation != _colorGeneration) return;
    setState(() => _sampling = false);
    if (color == null) {
      _setOptions(_options.copyWith(look: ReplayLook.signal));
      setState(
        () => _error =
            'Could not read the cover colors. Signal is still available.',
      );
    } else {
      _setOptions(_options.copyWith(artworkColor: color));
    }
  }

  String? get _albumPath {
    final songPath = widget.recap.topSong?.song.albumArt;
    if (songPath != null && songPath.isNotEmpty) return songPath;
    final albumPath = widget.recap.topAlbum?.representativeSong.albumArt;
    return albumPath == null || albumPath.isEmpty ? null : albumPath;
  }

  String? get _backgroundPath => switch (_background) {
    _Background.original => null,
    _Background.album => _albumPath,
    _Background.camera => _cameraPath,
    _Background.gallery => _galleryPath,
  };

  void _change(VoidCallback change) {
    if (_busy) return;
    setState(() {
      change();
      _saved = false;
      _error = null;
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (source == ImageSource.camera) {
        final permission = await Permission.camera.request();
        if (!mounted) return;
        if (!permission.isGranted) {
          setState(
            () => _error =
                'Camera access is needed. You can enable it in Android settings.',
          );
          return;
        }
      }
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (!mounted || image == null) return;
      setState(() {
        _saved = false;
        if (source == ImageSource.camera) {
          _cameraPath = image.path;
          _background = _Background.camera;
        } else {
          _galleryPath = image.path;
          _background = _Background.gallery;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open that photo. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({String? format}) async {
    if (_busy || _sampling) return;
    setState(() {
      _busy = true;
      _saved = false;
      _error = null;
      _capturing = format == null;
    });
    try {
      if (format == 'CSV') {
        if (await _csv.saveCsv(widget.recap) == null) return;
      } else if (format == 'TXT') {
        if (await _csv.saveTxt(widget.recap) == null) return;
      } else {
        // Decode source images before capturing. A fast tap must not export a
        // missing-image frame while Android is still decoding the chosen photo.
        final paths = <String>{
          ?_backgroundPath,
          ...widget.recap.topSongs
              .take(5)
              .map((s) => s.song.albumArt)
              .whereType<String>(),
        }.where((path) => path.isNotEmpty);
        for (final path in paths) {
          if (!mounted) return;
          final ImageProvider image = path.startsWith('http')
              ? NetworkImage(path)
              : FileImage(File(path));
          await precacheImage(image, context, onError: (_, _) {});
        }
        // Wait for the selected composition's paint, not an arbitrary timer.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final boundary = _boundaryKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
          throw const GallerySaveException(
            'The poster is not ready yet. Try saving again.',
          );
        }
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) {
            throw const GallerySaveException(
              'Could not create the poster image.',
            );
          }
          final stamp = DateTime.now()
              .toIso8601String()
              .replaceAll(':', '-')
              .replaceAll('.', '-');
          await _gallery.saveImage(
            bytes: bytes.buffer.asUint8List(),
            fileName:
                'flick_${widget.recap.period.name}_replay_${_type.name}_$stamp.png',
          );
        } finally {
          image.dispose();
        }
      }
      if (!mounted) return;
      setState(() => _saved = format == null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            format == null
                ? '${_type.label} saved to your gallery'
                : 'Recap saved as $format',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is GallerySaveException
              ? error.message
              : 'Could not save your recap. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _capturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animations = ref.watch(
      appPreferencesProvider.select((p) => p.animationsEnabled),
    );
    return DisplayModeWrapper(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) || !animations,
        ),
        child: Builder(builder: _studio),
      ),
    );
  }

  Widget _studio(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      bottom: false,
      child: Padding(
        // MainShell supplies the actual floating bar + mini-player clearance.
        // Only content receives it; no opaque scaffold slab sits behind it.
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to Replay',
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Replay Studio',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: ReplayStyle.paper,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reset card design',
                    onPressed: _busy ? null : _resetDesign,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final type in ReplayPosterType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _choice(
                        type.label,
                        _type == type,
                        () => _change(() => _type = type),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 23;
                  if (constraints.maxWidth >= 650 &&
                      constraints.maxHeight > 280) {
                    return Row(
                      children: [
                        Expanded(child: _preview()),
                        SizedBox(
                          width: math.min(360, constraints.maxWidth * 0.48),
                          child: Column(
                            children: [
                              _tabs(),
                              Expanded(child: _controls()),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  // At extreme text sizes / short windows, allow all controls
                  // to scroll rather than squeezing text into fixed-height UI.
                  if (largeText || constraints.maxHeight < 350) {
                    return SingleChildScrollView(
                      controller: _controlsScroll,
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          SizedBox(height: 250, child: _preview()),
                          _tabs(),
                          _panelContent(),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: _preview()),
                      _tabs(),
                      SizedBox(
                        height: math.min(180, constraints.maxHeight * 0.36),
                        child: _controls(),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ReplayStyle.paper,
                        ),
                      ),
                      if (_error!.startsWith('Camera'))
                        TextButton(
                          onPressed: openAppSettings,
                          child: const Text('Open Android settings'),
                        ),
                    ],
                  ),
                ),
              ),
            _saveDock(context),
          ],
        ),
      ),
    ),
  );

  Widget _preview() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
    child: Semantics(
      label: '${_type.label} poster preview. ${widget.recap.totalPlays} plays.',
      button: true,
      child: GestureDetector(
        onTap: _inspect,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ReplayPoster(
                        recap: widget.recap,
                        type: _type,
                        options: _options,
                        backgroundPath: _backgroundPath,
                        animated: !_capturing && !_inspecting,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to inspect · 1260 × 2280 PNG',
              style: TextStyle(fontSize: 11, color: ReplayStyle.muted),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _inspect() async {
    if (_busy) return;
    setState(() => _inspecting = true);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: FittedBox(
                    child: ReplayPoster(
                      recap: widget.recap,
                      type: _type,
                      options: _options,
                      backgroundPath: _backgroundPath,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _inspecting = false);
  }

  Widget _tabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final panel in _Panel.values)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _panel == panel
                  ? ReplayStyle.paper
                  : ReplayStyle.muted,
              backgroundColor: _panel == panel
                  ? AppColors.glassBackgroundStrong
                  : null,
              minimumSize: const Size(80, 48),
            ),
            onPressed: () {
              if (_controlsScroll.hasClients) _controlsScroll.jumpTo(0);
              setState(() => _panel = panel);
            },
            child: Text(switch (panel) {
              _Panel.look => 'Look',
              _Panel.background => 'Background',
              _Panel.details => 'Details',
            }),
          ),
      ],
    ),
  );

  Widget _controls() => SingleChildScrollView(
    controller: _controlsScroll,
    child: _panelContent(),
  );

  Widget _panelContent() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_panel == _Panel.look) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final look in ReplayLook.values)
                _choice(
                  look.label,
                  _options.look == look,
                  look == ReplayLook.artwork && _albumPath == null
                      ? null
                      : () => _setLook(look),
                  swatch: switch (look) {
                    ReplayLook.signal => ReplayStyle.signal,
                    ReplayLook.night => ReplayStyle.ink,
                    ReplayLook.artwork =>
                      _options.artworkColor ?? ReplayStyle.paper,
                  },
                ),
            ],
          ),
          if (_sampling)
            const Text(
              'Reading the cover colors…',
              style: TextStyle(color: ReplayStyle.silver),
            ),
          const SizedBox(height: 12),
          const Text(
            'Sleeves',
            style: TextStyle(color: ReplayStyle.silver, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _choice(
                'Single',
                !_options.layered,
                () => _setOptions(_options.copyWith(layered: false)),
              ),
              _choice(
                'Layered',
                _options.layered,
                () => _setOptions(_options.copyWith(layered: true)),
              ),
            ],
          ),
        ],
        if (_panel == _Panel.background) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _choice(
                'Designed',
                _background == _Background.original,
                () => _change(() => _background = _Background.original),
              ),
              _choice(
                'Album art',
                _background == _Background.album,
                _albumPath == null
                    ? null
                    : () => _change(() => _background = _Background.album),
              ),
              _choice(
                _cameraPath == null ? 'Camera' : 'Retake photo',
                _background == _Background.camera,
                () => _pick(ImageSource.camera),
              ),
              _choice(
                _galleryPath == null ? 'Gallery' : 'Pick again',
                _background == _Background.gallery,
                () => _pick(ImageSource.gallery),
              ),
            ],
          ),
          if (_backgroundPath != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Photo framing',
              style: TextStyle(color: ReplayStyle.silver, fontSize: 13),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [
                  ('Top', Alignment.topCenter),
                  ('Center', Alignment.center),
                  ('Bottom', Alignment.bottomCenter),
                ])
                  _choice(
                    preset.$1,
                    _options.photoAlignment == preset.$2,
                    () => _setOptions(
                      _options.copyWith(photoAlignment: preset.$2),
                    ),
                  ),
              ],
            ),
          ],
        ],
        if (_panel == _Panel.details) ...[
          const Text(
            'Overview metrics · choose up to 3',
            style: TextStyle(color: ReplayStyle.silver, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final metric in ReplayMetric.values)
                _choice(
                  metric.label,
                  _options.metrics.contains(metric),
                  !_options.metrics.contains(metric) &&
                          _options.metrics.length >= 3
                      ? null
                      : () {
                          final metrics = [..._options.metrics];
                          metrics.contains(metric)
                              ? metrics.remove(metric)
                              : metrics.add(metric);
                          _setOptions(_options.copyWith(metrics: metrics));
                        },
                ),
            ],
          ),
          _toggle(
            'Living ornament',
            _options.ornaments,
            (value) => _options.copyWith(ornaments: value),
          ),
          _toggle(
            'Surface shading',
            _options.surfaceDetail,
            (value) => _options.copyWith(surfaceDetail: value),
          ),
          _toggle(
            'Play badges',
            _options.badges,
            (value) => _options.copyWith(badges: value),
          ),
          _toggle(
            'Extra covers',
            _options.secondaryArtwork,
            (value) => _options.copyWith(secondaryArtwork: value),
          ),
          _toggle(
            'Footer line',
            _options.tagline,
            (value) => _options.copyWith(tagline: value),
          ),
        ],
      ],
    ),
  );

  Widget _toggle(
    String label,
    bool value,
    ReplayCardOptions Function(bool) update,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      label,
      style: const TextStyle(fontSize: 14, color: ReplayStyle.paper),
    ),
    value: value,
    activeTrackColor: ReplayStyle.silver,
    activeThumbColor: ReplayStyle.ink,
    onChanged: _busy ? null : (value) => _setOptions(update(value)),
  );

  Widget _saveDock(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.94),
            AppColors.surface.withValues(alpha: 0.97),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ReplayStyle.paper,
                  foregroundColor: ReplayStyle.ink,
                  minimumSize: const Size(48, 52),
                ),
                onPressed: _busy || _sampling ? null : () => _save(),
                icon: AnimatedSwitcher(
                  duration: ReplayStyle.duration(context),
                  child: Icon(
                    _busy
                        ? Icons.hourglass_top_rounded
                        : _saved
                        ? Icons.check_rounded
                        : Icons.download_rounded,
                    key: ValueKey((_busy, _saved)),
                    size: 20,
                  ),
                ),
                label: Text(
                  _busy
                      ? 'Preparing…'
                      : _saved
                      ? 'Saved · again'
                      : 'Save PNG',
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'More export options',
              enabled: !_busy,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: ReplayStyle.silver,
              ),
              onSelected: (value) =>
                  value == 'support' ? _support() : _save(format: value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'CSV', child: Text('Export CSV')),
                PopupMenuItem(value: 'TXT', child: Text('Export TXT')),
                PopupMenuItem(
                  value: 'support',
                  child: Text('Support Flick on Ko-fi'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _support() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://ko-fi.com/ultraelectronica'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Could not open Ko-fi');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Ko-fi. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _choice(
    String label,
    bool selected,
    VoidCallback? action, {
    Color? swatch,
  }) {
    return ChoiceChip(
      label: Text(label),
      avatar: swatch == null
          ? null
          : Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: ReplayStyle.muted, width: 0.5),
              ),
            ),
      selected: selected,
      onSelected: _busy || action == null ? null : (_) => action(),
      selectedColor: ReplayStyle.paper,
      backgroundColor: AppColors.glassBackgroundStrong,
      disabledColor: ReplayStyle.surface,
      checkmarkColor: ReplayStyle.ink,
      labelStyle: TextStyle(
        color: selected
            ? ReplayStyle.ink
            : action == null
            ? ReplayStyle.muted
            : ReplayStyle.silver,
      ),
      side: BorderSide(color: selected ? ReplayStyle.paper : ReplayStyle.rule),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      chipAnimationStyle: ChipAnimationStyle(
        selectAnimation: AnimationStyle(
          duration: ReplayStyle.duration(context),
        ),
      ),
    );
  }
}
