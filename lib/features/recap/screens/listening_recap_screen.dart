import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/services/csv_export_service.dart';
import 'package:flick/services/gallery_save_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wrapped-style listening recap with daily, weekly, monthly, and yearly views.
class ListeningRecapScreen extends StatefulWidget {
  const ListeningRecapScreen({super.key});

  @override
  State<ListeningRecapScreen> createState() => _ListeningRecapScreenState();
}

class _ListeningRecapScreenState extends State<ListeningRecapScreen> {
  final RecentlyPlayedRepository _recentlyPlayedRepository =
      RecentlyPlayedRepository();
  final GallerySaveService _gallerySaveService = GallerySaveService();
  final CsvExportService _csvExportService = CsvExportService();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _cardBoundaryKey = GlobalKey();
  final GlobalKey _topSongsPosterBoundaryKey = GlobalKey();
  final GlobalKey _topArtistsPosterBoundaryKey = GlobalKey();

  ListeningRecapPeriod _selectedPeriod = ListeningRecapPeriod.daily;
  _RecapPosterBackgroundMode _posterBackgroundMode =
      _RecapPosterBackgroundMode.defaultArt;
  Map<ListeningRecapPeriod, ListeningRecap> _recaps = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExportingCsv = false;
  bool _isExportingTxt = false;
  String? _cameraBackgroundPath;
  String? _galleryBackgroundPath;
  _RecapRankingPosterType? _savingPosterType;
  _RecapRankingPosterType? _savedPosterType;
  StreamSubscription<void>? _historySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecaps();
      _watchHistory();
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  void _watchHistory() {
    _historySubscription = _recentlyPlayedRepository.watchHistory().listen((_) {
      _loadRecaps(showLoadingState: false);
    });
  }

  Future<void> _loadRecaps({bool showLoadingState = true}) async {
    if (!mounted) return;

    if (showLoadingState) {
      setState(() => _isLoading = true);
    }

    try {
      final recaps = await _recentlyPlayedRepository.getListeningRecaps();
      if (!mounted) return;
      setState(() {
        _recaps = recaps;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recaps = {};
        _isLoading = false;
      });
    }
  }

  ListeningRecap _currentRecap() {
    return _recaps[_selectedPeriod] ??
        ListeningRecap.empty(
          _selectedPeriod,
          _selectedPeriod.rangeFor(DateTime.now()),
        );
  }

  String? _recapAlbumArtPath(ListeningRecap recap) {
    final path =
        recap.topSong?.song.albumArt ??
        recap.topAlbum?.representativeSong.albumArt;
    return path == null || path.isEmpty ? null : path;
  }

  String? _posterBackgroundImagePath(ListeningRecap recap) {
    return switch (_posterBackgroundMode) {
      _RecapPosterBackgroundMode.defaultArt => null,
      _RecapPosterBackgroundMode.albumArt => _recapAlbumArtPath(recap),
      _RecapPosterBackgroundMode.cameraPhoto => _cameraBackgroundPath,
      _RecapPosterBackgroundMode.galleryPhoto => _galleryBackgroundPath,
    };
  }

  void _selectDefaultPosterBackground() {
    setState(() {
      _posterBackgroundMode = _RecapPosterBackgroundMode.defaultArt;
    });
  }

  void _selectAlbumArtPosterBackground() {
    final hasAlbumArt = _recapAlbumArtPath(_currentRecap()) != null;
    if (!hasAlbumArt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No album art is available yet.')),
      );
      return;
    }

    setState(() {
      _posterBackgroundMode = _RecapPosterBackgroundMode.albumArt;
    });
  }

  Future<void> _takePosterBackgroundPhoto() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      final canOpenSettings = status.isPermanentlyDenied || status.isRestricted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canOpenSettings
                ? 'Camera permission is disabled. Enable it in settings to take a poster background photo.'
                : 'Camera permission is needed to take a poster background photo.',
          ),
          action: canOpenSettings
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ),
      );
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (!mounted || image == null) return;

    setState(() {
      _cameraBackgroundPath = image.path;
      _posterBackgroundMode = _RecapPosterBackgroundMode.cameraPhoto;
    });
  }

  Future<void> _pickPosterBackgroundImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (!mounted || image == null) return;

    setState(() {
      _galleryBackgroundPath = image.path;
      _posterBackgroundMode = _RecapPosterBackgroundMode.galleryPhoto;
    });
  }

  Future<void> _saveCurrentRecap() async {
    if (_isSaving) return;

    final recap = _currentRecap();
    setState(() => _isSaving = true);

    try {
      final bytes = await _captureRecapPng(_cardBoundaryKey);
      if (bytes == null) {
        throw const GallerySaveException(
          'The recap card is not ready to capture yet.',
        );
      }

      await _gallerySaveService.saveImage(
        bytes: bytes,
        fileName: _buildRecapFileName(recap),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recap saved to your gallery')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveRecapCsv() async {
    if (_isExportingCsv || _isExportingTxt) return;

    setState(() => _isExportingCsv = true);

    try {
      final recap = _currentRecap();
      await _csvExportService.saveCsv(recap);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recap saved as CSV')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _saveRecapTxt() async {
    if (_isExportingCsv || _isExportingTxt) return;

    setState(() => _isExportingTxt = true);

    try {
      final recap = _currentRecap();
      await _csvExportService.saveTxt(recap);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recap saved as TXT')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isExportingTxt = false);
    }
  }

  GlobalKey _rankingPosterBoundaryKey(_RecapRankingPosterType type) {
    return switch (type) {
      _RecapRankingPosterType.topSongs => _topSongsPosterBoundaryKey,
      _RecapRankingPosterType.topArtists => _topArtistsPosterBoundaryKey,
    };
  }

  Future<void> _saveRankingPoster(_RecapRankingPosterType type) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _savingPosterType = type;
      _savedPosterType = null;
    });

    try {
      final recap = _currentRecap();
      final bytes = await _captureRecapPng(_rankingPosterBoundaryKey(type));
      if (bytes == null) {
        throw const GallerySaveException(
          'The ranking poster is still rendering.',
        );
      }

      await _gallerySaveService.saveImage(
        bytes: bytes,
        fileName: _buildRecapFileName(recap, variant: type.fileNameSuffix),
      );

      if (!mounted) return;
      setState(() {
        _savingPosterType = null;
        _savedPosterType = type;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.title} saved to your gallery')),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && _savedPosterType == type) {
        setState(() => _savedPosterType = null);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingPosterType = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = _currentRecap();

    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: _RecapBackdrop()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildPeriodPicker(context),
                  const SizedBox(height: AppConstants.spacingSm),
                  if (!recap.hasData)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppConstants.spacingMd,
                      ),
                      child: Text(
                        recap.period.emptyMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.adaptiveTextSecondary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _isLoading && _recaps.isEmpty
                        ? _buildLoadingState(context)
                        : RefreshIndicator(
                            onRefresh: _loadRecaps,
                            color: AppColors.textPrimary,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                AppConstants.spacingLg,
                                AppConstants.spacingMd,
                                AppConstants.spacingLg,
                                AppConstants.navBarHeight + 96,
                              ),
                              child: AnimatedSwitcher(
                                duration: AppConstants.animationNormal,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: Column(
                                  key: ValueKey(_selectedPeriod),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio:
                                            _RecapPosterDimensions.aspectRatio,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          child: RepaintBoundary(
                                            key: _cardBoundaryKey,
                                            child: _ListeningRecapHeroCard(
                                              recap: recap,
                                              backgroundMode:
                                                  _posterBackgroundMode,
                                              backgroundImagePath:
                                                  _posterBackgroundImagePath(
                                                    recap,
                                                  ),
                                              frameSize: _RecapPosterDimensions
                                                  .referenceSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppConstants.spacingMd,
                                    ),
                                    _buildActionRow(recap),
                                    const SizedBox(
                                      height: AppConstants.spacingLg,
                                    ),
                                    if (recap.hasData) ...[
                                      _buildHighlightCards(context, recap),
                                      const SizedBox(
                                        height: AppConstants.spacingLg,
                                      ),
                                      _buildRankingSection(
                                        context,
                                        title: 'Top Songs',
                                        subtitle:
                                            'The tracks that defined this ${recap.period.label.toLowerCase()}',
                                        type: _RecapRankingPosterType.topSongs,
                                        actionLabel: 'Download Poster',
                                        onActionTap: recap.topSongs.isEmpty
                                            ? null
                                            : () => _saveRankingPoster(
                                                _RecapRankingPosterType
                                                    .topSongs,
                                              ),
                                        isSaving:
                                            _savingPosterType ==
                                            _RecapRankingPosterType.topSongs,
                                        isSuccess:
                                            _savedPosterType ==
                                            _RecapRankingPosterType.topSongs,
                                        children: [
                                          if (recap.topSongs.isNotEmpty)
                                            _RankingHeroTile.song(
                                              item: recap.topSongs.first,
                                              accent: _RecapRankingPosterType
                                                  .topSongs
                                                  .accent,
                                            ),
                                          if (recap.topSongs.length > 1) ...[
                                            const SizedBox(
                                              height: AppConstants.spacingMd,
                                            ),
                                            for (
                                              var index = 1;
                                              index <
                                                  math.min(
                                                    recap.topSongs.length,
                                                    5,
                                                  );
                                              index++
                                            )
                                              _RankingTile.song(
                                                rank: index + 1,
                                                item: recap.topSongs[index],
                                                maxPlays:
                                                    recap.topSongs.first.plays,
                                                accent: _RecapRankingPosterType
                                                    .topSongs
                                                    .accent,
                                              ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(
                                        height: AppConstants.spacingLg,
                                      ),
                                      _buildRankingSection(
                                        context,
                                        title: 'Top Artists',
                                        subtitle:
                                            'Your most replayed voices and projects',
                                        type:
                                            _RecapRankingPosterType.topArtists,
                                        actionLabel: 'Download Poster',
                                        onActionTap: recap.topArtists.isEmpty
                                            ? null
                                            : () => _saveRankingPoster(
                                                _RecapRankingPosterType
                                                    .topArtists,
                                              ),
                                        isSaving:
                                            _savingPosterType ==
                                            _RecapRankingPosterType.topArtists,
                                        isSuccess:
                                            _savedPosterType ==
                                            _RecapRankingPosterType.topArtists,
                                        children: [
                                          if (recap.topArtists.isNotEmpty)
                                            _RankingHeroTile.artist(
                                              item: recap.topArtists.first,
                                              accent: _RecapRankingPosterType
                                                  .topArtists
                                                  .accent,
                                            ),
                                          if (recap.topArtists.length > 1) ...[
                                            const SizedBox(
                                              height: AppConstants.spacingMd,
                                            ),
                                            for (
                                              var index = 1;
                                              index <
                                                  math.min(
                                                    recap.topArtists.length,
                                                    5,
                                                  );
                                              index++
                                            )
                                              _RankingTile.artist(
                                                rank: index + 1,
                                                item: recap.topArtists[index],
                                                maxPlays: recap
                                                    .topArtists
                                                    .first
                                                    .plays,
                                                accent: _RecapRankingPosterType
                                                    .topArtists
                                                    .accent,
                                              ),
                                          ],
                                        ],
                                      ),
                                    ] else
                                      _buildEmptyDetailState(context, recap),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            _HiddenRankingPosterCaptureHost(
              recap: recap,
              topSongsBoundaryKey: _topSongsPosterBoundaryKey,
              topArtistsBoundaryKey: _topArtistsPosterBoundaryKey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(
                LucideIcons.arrowLeft,
                color: context.adaptiveTextPrimary,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flick Replay',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                Text(
                  'Your daily, weekly, monthly, and yearly listening recap',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPicker(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final period = ListeningRecapPeriod.values[index];
          final isSelected = period == _selectedPeriod;

          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: AnimatedContainer(
              duration: AppConstants.animationFast,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEDF6FF), Color(0xFF8AB7FF)],
                      )
                    : null,
                color: isSelected ? null : AppColors.glassBackground,
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.28)
                      : AppColors.glassBorder,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF8AB7FF,
                          ).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  period.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.background : Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppConstants.spacingSm),
        itemCount: ListeningRecapPeriod.values.length,
      ),
    );
  }

  Widget _buildActionRow(ListeningRecap recap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosterBackgroundSelector(
          mode: _posterBackgroundMode,
          hasAlbumArt: _recapAlbumArtPath(recap) != null,
          hasCameraPhoto: _cameraBackgroundPath != null,
          hasGalleryPhoto: _galleryBackgroundPath != null,
          onDefaultTap: _selectDefaultPosterBackground,
          onAlbumArtTap: _selectAlbumArtPosterBackground,
          onCameraTap: _takePosterBackgroundPhoto,
          onGalleryTap: _pickPosterBackgroundImage,
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _RecapActionButton(
          icon: Icons.download_rounded,
          label: _isSaving ? 'Saving...' : 'Save to Gallery',
          isPrimary: true,
          onTap: _isSaving ? null : _saveCurrentRecap,
        ),
        if (recap.hasData) ...[
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              Expanded(
                child: _RecapActionButton(
                  icon: Icons.table_chart_rounded,
                  label: _isExportingCsv ? 'Saving...' : 'Save as CSV',
                  onTap:
                      (_isExportingCsv || _isExportingTxt)
                          ? null
                          : _saveRecapCsv,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: _RecapActionButton(
                  icon: Icons.description_rounded,
                  label: _isExportingTxt ? 'Saving...' : 'Save as TXT',
                  onTap:
                      (_isExportingCsv || _isExportingTxt)
                          ? null
                          : _saveRecapTxt,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightCards(BuildContext context, ListeningRecap recap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 640;
        final itemWidth = isStacked
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: [
            SizedBox(
              width: itemWidth,
              child: _InsightCard(
                title: 'Top Artist',
                value: recap.topArtist?.artist ?? 'No data yet',
                detail: recap.topArtist == null
                    ? 'Start listening to unlock this card'
                    : '${recap.topArtist!.plays} plays · ${recap.topArtist!.uniqueSongs} songs',
                accent: const Color(0xFFFFD47A),
                icon: Icons.mic_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _InsightCard(
                title: 'Top Album',
                value: recap.topAlbum?.album ?? 'No data yet',
                detail: recap.topAlbum == null
                    ? 'Albums will show up here once you replay them'
                    : '${recap.topAlbum!.artist} · ${recap.topAlbum!.plays} plays',
                accent: const Color(0xFF7CD9FF),
                icon: LucideIcons.disc,
                imagePath: recap.topAlbum?.representativeSong.albumArt,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRankingSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
    required _RecapRankingPosterType type,
    String? actionLabel,
    VoidCallback? onActionTap,
    bool isSaving = false,
    bool isSuccess = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: type.gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -30,
              child: _GlowOrb(size: 180, colors: type.leadingOrbColors),
            ),
            Positioned(
              bottom: -70,
              right: -20,
              child: _GlowOrb(size: 200, colors: type.trailingOrbColors),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (actionLabel != null && onActionTap != null) ...[
                        const SizedBox(width: AppConstants.spacingSm),
                        _SectionPosterButton(
                          label: actionLabel,
                          onTap: onActionTap,
                          isSaving: isSaving,
                          isSuccess: isSuccess,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetailState(BuildContext context, ListeningRecap recap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_motion_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: context.responsiveIcon(30),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            recap.period.emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.adaptiveTextSecondary),
    );
  }
}

enum _RecapPosterBackgroundMode { defaultArt, albumArt, cameraPhoto, galleryPhoto }

extension _RecapPosterBackgroundModeX on _RecapPosterBackgroundMode {
  String get label {
    return switch (this) {
      _RecapPosterBackgroundMode.defaultArt => 'Default',
      _RecapPosterBackgroundMode.albumArt => 'Album Art',
      _RecapPosterBackgroundMode.cameraPhoto => 'Camera',
      _RecapPosterBackgroundMode.galleryPhoto => 'Gallery',
    };
  }

  IconData get icon {
    return switch (this) {
      _RecapPosterBackgroundMode.defaultArt => Icons.auto_awesome_rounded,
      _RecapPosterBackgroundMode.albumArt => LucideIcons.disc,
      _RecapPosterBackgroundMode.cameraPhoto => Icons.photo_camera_rounded,
      _RecapPosterBackgroundMode.galleryPhoto => Icons.photo_library_rounded,
    };
  }
}

class _PosterBackgroundSelector extends StatelessWidget {
  final _RecapPosterBackgroundMode mode;
  final bool hasAlbumArt;
  final bool hasCameraPhoto;
  final bool hasGalleryPhoto;
  final VoidCallback onDefaultTap;
  final VoidCallback onAlbumArtTap;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  const _PosterBackgroundSelector({
    required this.mode,
    required this.hasAlbumArt,
    required this.hasCameraPhoto,
    required this.hasGalleryPhoto,
    required this.onDefaultTap,
    required this.onAlbumArtTap,
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poster background',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Wrap(
          spacing: AppConstants.spacingXs,
          runSpacing: AppConstants.spacingXs,
          children: [
            _PosterBackgroundChoice(
              mode: _RecapPosterBackgroundMode.defaultArt,
              isSelected: mode == _RecapPosterBackgroundMode.defaultArt,
              onTap: onDefaultTap,
            ),
            _PosterBackgroundChoice(
              mode: _RecapPosterBackgroundMode.albumArt,
              isSelected: mode == _RecapPosterBackgroundMode.albumArt,
              onTap: hasAlbumArt ? onAlbumArtTap : null,
            ),
            _PosterBackgroundChoice(
              mode: _RecapPosterBackgroundMode.cameraPhoto,
              isSelected: mode == _RecapPosterBackgroundMode.cameraPhoto,
              label: hasCameraPhoto ? 'Retake' : null,
              onTap: onCameraTap,
            ),
            _PosterBackgroundChoice(
              mode: _RecapPosterBackgroundMode.galleryPhoto,
              isSelected: mode == _RecapPosterBackgroundMode.galleryPhoto,
              label: hasGalleryPhoto ? 'Pick again' : null,
              onTap: onGalleryTap,
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _RecapActionButton(
          icon: LucideIcons.heart,
          label: 'Enjoying Flick Replay?  Buy me a Ko-fi',
          isPrimary: false,
          onTap: () async {
            try {
              await launchUrl(
                Uri.parse('https://ko-fi.com/ultraelectronica'),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {}
          },
        ),
      ],
    );
  }
}

class _PosterBackgroundChoice extends StatelessWidget {
  final _RecapPosterBackgroundMode mode;
  final bool isSelected;
  final String? label;
  final VoidCallback? onTap;

  const _PosterBackgroundChoice({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
            vertical: AppConstants.spacingXs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFF5F7FF), Color(0xFF9CC4FF)],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.26)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                size: 16,
                color: isSelected
                    ? AppColors.background
                    : Colors.white.withValues(alpha: isEnabled ? 0.82 : 0.38),
              ),
              const SizedBox(width: 6),
              Text(
                label ?? mode.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.background
                      : Colors.white.withValues(alpha: isEnabled ? 0.88 : 0.42),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningRecapHeroCard extends StatelessWidget {
  final ListeningRecap recap;
  final _RecapPosterBackgroundMode backgroundMode;
  final String? backgroundImagePath;
  final Size frameSize;

  const _ListeningRecapHeroCard({
    required this.recap,
    required this.backgroundMode,
    required this.backgroundImagePath,
    required this.frameSize,
  });

  @override
  Widget build(BuildContext context) {
    final topSong = recap.topSong;
    final albumArtPath =
        topSong?.song.albumArt ?? recap.topAlbum?.representativeSong.albumArt;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          const Positioned.fill(child: _PosterDefaultBackground()),
          if (backgroundImagePath != null)
            Positioned.fill(
              child: _PosterImageBackground(
                imagePath: backgroundImagePath!,
                blurSigma: backgroundMode == _RecapPosterBackgroundMode.albumArt
                    ? 24
                    : 8,
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: 26,
            child: Text(
              'Flick\nReplay',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 0.82,
                letterSpacing: -2.8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 58,
              ),
            ),
          ),
          Positioned(
            top: 36,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PosterPill(label: recap.period.label.toUpperCase()),
                const SizedBox(height: 10),
                SizedBox(
                  width: 150,
                  child: Text(
                    _formatRecapRange(recap),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.15,
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 164,
            left: 28,
            child: _PosterTotalPlaysText(recap: recap),
          ),
          Positioned(
            top: 186,
            right: -22,
            child: Transform.rotate(
              angle: -0.08,
              child: _PosterAlbumArtFeature(imagePath: albumArtPath),
            ),
          ),
          Positioned(
            top: 356,
            left: 26,
            right: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOP SONG',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1ED760),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  topSong?.song.title ?? 'No plays yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 0.96,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        topSong?.song.artist ?? recap.period.emptyMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              height: 1.12,
                              color: Colors.white.withValues(alpha: 0.76),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    Text(
                      topSong == null
                          ? '0 plays'
                          : _formatPlayCount(topSong.plays),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 92,
            child: _PosterMetricStrip(recap: recap),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 34,
            child: Text(
              _heroClosingLine(recap),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.25,
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 10,
            child: Text(
              'Made with Flick Player  |  Support Development',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.1,
                color: Colors.white.withValues(alpha: 0.28),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      width: frameSize.width,
      height: frameSize.height,
      child: card,
    );
  }
}

enum _RecapRankingPosterType { topSongs, topArtists }

extension _RecapRankingPosterTypeX on _RecapRankingPosterType {
  String get title {
    return switch (this) {
      _RecapRankingPosterType.topSongs => 'Top Songs',
      _RecapRankingPosterType.topArtists => 'Top Artists',
    };
  }

  String get fileNameSuffix {
    return switch (this) {
      _RecapRankingPosterType.topSongs => 'top_songs',
      _RecapRankingPosterType.topArtists => 'top_artists',
    };
  }

  Color get accent {
    return switch (this) {
      _RecapRankingPosterType.topSongs => const Color(0xFF8AB7FF),
      _RecapRankingPosterType.topArtists => const Color(0xFFFFD47A),
    };
  }

  List<Color> get gradientColors {
    return switch (this) {
      _RecapRankingPosterType.topSongs => const [
        Color(0xFF09111D),
        Color(0xFF111B28),
        Color(0xFF23151D),
      ],
      _RecapRankingPosterType.topArtists => const [
        Color(0xFF140F08),
        Color(0xFF151B1D),
        Color(0xFF1A1210),
      ],
    };
  }

  List<Color> get leadingOrbColors {
    return switch (this) {
      _RecapRankingPosterType.topSongs => const [
        Color(0xFF5A9BFF),
        Color(0x005A9BFF),
      ],
      _RecapRankingPosterType.topArtists => const [
        Color(0xFFFFB35A),
        Color(0x00FFB35A),
      ],
    };
  }

  List<Color> get trailingOrbColors {
    return switch (this) {
      _RecapRankingPosterType.topSongs => const [
        Color(0xFFE16BFF),
        Color(0x00E16BFF),
      ],
      _RecapRankingPosterType.topArtists => const [
        Color(0xFF6ECFFF),
        Color(0x006ECFFF),
      ],
    };
  }
}

class _RecapRankingPosterCard extends StatelessWidget {
  final ListeningRecap recap;
  final _RecapRankingPosterType type;
  final Size? frameSize;

  const _RecapRankingPosterCard({
    required this.recap,
    required this.type,
    this.frameSize,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? leadWidget;
    final List<Widget> remainingRows;

    switch (type) {
      case _RecapRankingPosterType.topSongs:
        final songs = recap.topSongs.take(5).toList();
        if (songs.isEmpty) {
          leadWidget = null;
          remainingRows = const [];
        } else {
          leadWidget = _RankingHeroTile.song(
            item: songs.first,
            accent: type.accent,
          );
          final maxPlays = songs.first.plays;
          remainingRows = [
            for (var i = 1; i < songs.length; i++)
              _RankingTile.song(
                rank: i + 1,
                item: songs[i],
                maxPlays: maxPlays,
                accent: type.accent,
              ),
          ];
        }
        break;
      case _RecapRankingPosterType.topArtists:
        final artists = recap.topArtists.take(5).toList();
        if (artists.isEmpty) {
          leadWidget = null;
          remainingRows = const [];
        } else {
          leadWidget = _RankingHeroTile.artist(
            item: artists.first,
            accent: type.accent,
          );
          final maxPlays = artists.first.plays;
          remainingRows = [
            for (var i = 1; i < artists.length; i++)
              _RankingTile.artist(
                rank: i + 1,
                item: artists[i],
                maxPlays: maxPlays,
                accent: type.accent,
              ),
          ];
        }
        break;
    }

    return SizedBox(
      width: frameSize?.width ?? _RecapPosterDimensions.referenceWidth,
      height: frameSize?.height ?? _RecapPosterDimensions.referenceHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: type.gradientColors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -96,
                left: -42,
                child: _GlowOrb(size: 270, colors: type.leadingOrbColors),
              ),
              Positioned(
                top: 154,
                right: -124,
                child: _GlowOrb(size: 300, colors: type.trailingOrbColors),
              ),
              Positioned(
                bottom: -128,
                left: 22,
                child: _GlowOrb(
                  size: 300,
                  colors: const [Color(0xFF1ED760), Color(0x001ED760)],
                ),
              ),
              Positioned(
                top: 102,
                left: -116,
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    width: 630,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusRound,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 30,
                left: 26,
                child: Text(
                  'Flick\nReplay',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 0.86,
                    letterSpacing: -1.6,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 34,
                  ),
                ),
              ),
              Positioned(
                top: 36,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _PosterPill(label: recap.period.label.toUpperCase()),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      child: Text(
                        _formatRecapRange(recap),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.15,
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 126,
                left: 26,
                child: Text(
                  type.title.replaceFirst(' ', '\n'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    height: 0.78,
                    letterSpacing: -4.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 86,
                  ),
                ),
              ),
              Positioned(
                top: 152,
                right: 22,
                child: Text(
                  '05',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    height: 0.8,
                    letterSpacing: -6,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.12),
                    fontSize: 132,
                  ),
                ),
              ),
              if (leadWidget != null) ...[
                Positioned(top: 294, left: 26, right: 26, child: leadWidget),
                Positioned(
                  left: 26,
                  right: 26,
                  bottom: 34,
                  child: Column(children: remainingRows),
                ),
              ] else
                Positioned(
                  left: 26,
                  right: 26,
                  bottom: 220,
                  child: _buildEmptyState(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(
            type == _RecapRankingPosterType.topSongs
                ? Icons.queue_music_rounded
                : Icons.mic_rounded,
            color: Colors.white.withValues(alpha: 0.82),
            size: 32,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'No ranking data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapPosterDimensions {
  static const double referenceWidth = 420;
  static const double referenceHeight = 760;
  static const Size referenceSize = Size(referenceWidth, referenceHeight);
  static const double aspectRatio = referenceWidth / referenceHeight;
}

class _HiddenRankingPosterCaptureHost extends StatelessWidget {
  final ListeningRecap recap;
  final GlobalKey topSongsBoundaryKey;
  final GlobalKey topArtistsBoundaryKey;

  const _HiddenRankingPosterCaptureHost({
    required this.recap,
    required this.topSongsBoundaryKey,
    required this.topArtistsBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    final offset = context.screenWidth + _RecapPosterDimensions.referenceWidth;

    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: topSongsBoundaryKey,
              child: _RecapRankingPosterCard(
                recap: recap,
                type: _RecapRankingPosterType.topSongs,
                frameSize: _RecapPosterDimensions.referenceSize,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            RepaintBoundary(
              key: topArtistsBoundaryKey,
              child: _RecapRankingPosterCard(
                recap: recap,
                type: _RecapRankingPosterType.topArtists,
                frameSize: _RecapPosterDimensions.referenceSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapBackdrop extends StatelessWidget {
  const _RecapBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF040608), Color(0xFF0A0A0A)],
              ),
            ),
          ),
          Positioned(
            top: -160,
            left: -80,
            child: _GlowOrb(
              size: 360,
              colors: const [Color(0xFF1B3258), Color(0x001B3258)],
            ),
          ),
          Positioned(
            top: context.screenHeight * 0.28,
            right: -120,
            child: _GlowOrb(
              size: 320,
              colors: const [Color(0xFF4A2A1F), Color(0x004A2A1F)],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterDefaultBackground extends StatelessWidget {
  const _PosterDefaultBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06101E), Color(0xFF161B2B), Color(0xFF28131D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -96,
            left: -42,
            child: _GlowOrb(
              size: 270,
              colors: const [Color(0xFF4A96FF), Color(0x004A96FF)],
            ),
          ),
          Positioned(
            top: 170,
            right: -110,
            child: _GlowOrb(
              size: 280,
              colors: const [Color(0xFFE16BFF), Color(0x00E16BFF)],
            ),
          ),
          Positioned(
            bottom: -130,
            left: 40,
            child: _GlowOrb(
              size: 320,
              colors: const [Color(0xFFFFB35A), Color(0x00FFB35A)],
            ),
          ),
          Positioned(
            top: 86,
            left: -120,
            child: Transform.rotate(
              angle: -0.34,
              child: Container(
                width: 620,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterImageBackground extends StatelessWidget {
  final String imagePath;
  final double blurSigma;

  const _PosterImageBackground({
    required this.imagePath,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: Transform.scale(
            scale: 1.12,
            child: CachedImageWidget(
              imagePath: imagePath,
              fit: BoxFit.cover,
              errorWidget: const _PosterDefaultBackground(),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
          ),
        ),
      ],
    );
  }
}

class _PosterPill extends StatelessWidget {
  final String label;

  const _PosterPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _PosterTotalPlaysText extends StatelessWidget {
  final ListeningRecap recap;

  const _PosterTotalPlaysText({required this.recap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL PLAYS',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        Text(
          '${recap.totalPlays}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            height: 0.78,
            letterSpacing: -5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 96,
          ),
        ),
        Text(
          recap.hasData ? 'plays logged' : 'waiting for plays',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PosterAlbumArtFeature extends StatelessWidget {
  final String? imagePath;

  const _PosterAlbumArtFeature({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    const size = 198.0;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 34,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: imagePath == null || imagePath!.isEmpty
              ? ColoredBox(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 62,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                )
              : CachedImageWidget(
                  imagePath: imagePath,
                  fit: BoxFit.cover,
                  errorWidget: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 62,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _PosterMetricStrip extends StatelessWidget {
  final ListeningRecap recap;

  const _PosterMetricStrip({required this.recap});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'Listen Time',
        value: _formatCompactDuration(recap.totalListeningTime),
      ),
      _MetricData(label: 'Active Days', value: '${recap.activeDays}'),
      _MetricData(label: 'Peak Hour', value: _formatPeakHour(recap.peakHour)),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: AppConstants.spacingMd),
          Expanded(child: _PosterTextMetric(data: metrics[index])),
        ],
      ],
    );
  }
}

class _PosterTextMetric extends StatelessWidget {
  final _MetricData data;

  const _PosterTextMetric({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            height: 0.95,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF1ED760),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.label.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            height: 1.05,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final String label;
  final String value;

  const _MetricData({required this.label, required this.value});
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final IconData icon;
  final String? imagePath;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    required this.icon,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd - 1),
              child: imagePath == null || imagePath!.isEmpty
                  ? Icon(icon, color: accent)
                  : CachedImageWidget(imagePath: imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.adaptiveTextTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero tile for the #1 ranked item, styled as a prominent featured card.
class _RankingHeroTile extends StatelessWidget {
  final String label;
  final String title;
  final String artist;
  final String plays;
  final String duration;
  final String? imagePath;
  final bool isArtist;
  final Color accent;

  const _RankingHeroTile({
    required this.label,
    required this.title,
    required this.artist,
    required this.plays,
    required this.duration,
    required this.accent,
    this.imagePath,
    this.isArtist = false,
  });

  factory _RankingHeroTile.song({
    required RankedRecapSong item,
    required Color accent,
  }) {
    return _RankingHeroTile(
      label: '#1 SONG',
      title: item.song.title,
      artist: item.song.artist,
      plays: _formatPlayCount(item.plays),
      duration: _formatCompactDuration(item.listeningTime),
      imagePath: item.song.albumArt,
      accent: accent,
    );
  }

  factory _RankingHeroTile.artist({
    required RankedRecapArtist item,
    required Color accent,
  }) {
    return _RankingHeroTile(
      label: '#1 ARTIST',
      title: item.artist,
      artist: '${item.uniqueSongs} songs',
      plays: _formatPlayCount(item.plays),
      duration: _formatCompactDuration(item.listeningTime),
      accent: accent,
      isArtist: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: isArtist ? 0 : -0.06,
            child: isArtist
                ? _PosterArtistAvatar(name: title, size: 96, accent: accent)
                : _PosterArtThumb(imagePath: imagePath, size: 96),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 0.98,
                    letterSpacing: -0.9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Row(
                  children: [
                    Text(
                      plays,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Text(
                      duration,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile for ranked items #2-#5 with a progress bar showing relative plays.
class _RankingTile extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String trailing;
  final String? imagePath;
  final bool isArtist;
  final int plays;
  final int maxPlays;
  final Color accent;

  const _RankingTile({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.plays,
    required this.maxPlays,
    required this.accent,
    this.imagePath,
    this.isArtist = false,
  });

  factory _RankingTile.song({
    required int rank,
    required RankedRecapSong item,
    required int maxPlays,
    required Color accent,
  }) {
    return _RankingTile(
      rank: rank,
      title: item.song.title,
      subtitle:
          '${item.song.artist} · ${_formatCompactDuration(item.listeningTime)}',
      trailing: _formatPlayCount(item.plays),
      imagePath: item.song.albumArt,
      plays: item.plays,
      maxPlays: maxPlays,
      accent: accent,
    );
  }

  factory _RankingTile.artist({
    required int rank,
    required RankedRecapArtist item,
    required int maxPlays,
    required Color accent,
  }) {
    return _RankingTile(
      rank: rank,
      title: item.artist,
      subtitle:
          '${item.uniqueSongs} songs · ${_formatCompactDuration(item.listeningTime)}',
      trailing: _formatPlayCount(item.plays),
      plays: item.plays,
      maxPlays: maxPlays,
      accent: accent,
      isArtist: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = maxPlays > 0 ? (plays / maxPlays).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: rank == 5 ? 0 : AppConstants.spacingMd),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 0.9,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              if (isArtist)
                _PosterArtistAvatar(
                  name: title,
                  size: 46,
                  accent: accent,
                  fontSize: 17,
                )
              else
                _PosterArtThumb(
                  imagePath: imagePath,
                  size: 46,
                  borderRadius: 13,
                ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.05,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                trailing,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(
                  accent.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPosterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSaving;
  final bool isSuccess;

  const _SectionPosterButton({
    required this.label,
    required this.onTap,
    this.isSaving = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
            vertical: AppConstants.spacingXs,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: _buildIcon(),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (isSaving) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    if (isSuccess) {
      return Icon(
        key: const ValueKey('success'),
        Icons.check_rounded,
        size: 16,
        color: Colors.greenAccent,
      );
    }
    return Icon(
      key: const ValueKey('default'),
      Icons.crop_portrait_rounded,
      size: 16,
      color: Colors.white.withValues(alpha: 0.7),
    );
  }
}

class _PosterArtThumb extends StatelessWidget {
  final String? imagePath;
  final double size;
  final double borderRadius;

  const _PosterArtThumb({
    this.imagePath,
    this.size = 86,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x40FFFFFF), Color(0x08FFFFFF)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, borderRadius - 4)),
        child: imagePath == null || imagePath!.isEmpty
            ? Container(
                color: Colors.white.withValues(alpha: 0.08),
                child: Icon(
                  Icons.music_note_rounded,
                  size: size * 0.34,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              )
            : CachedImageWidget(imagePath: imagePath!, fit: BoxFit.cover),
      ),
    );
  }
}

class _PosterArtistAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  final Color accent;

  const _PosterArtistAvatar({
    required this.name,
    required this.size,
    required this.accent,
    this.fontSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.88),
            accent.withValues(alpha: 0.32),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          color: AppColors.background,
        ),
      ),
    );
  }
}

class _RecapActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _RecapActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            gradient: isPrimary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF5F7FF), Color(0xFF9CC4FF)],
                  )
                : null,
            color: isPrimary ? null : AppColors.glassBackground,
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.26)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
                color: isPrimary ? AppColors.background : Colors.white,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? AppColors.background : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Uint8List?> _captureRecapPng(GlobalKey boundaryKey) async {
  await Future.delayed(const Duration(milliseconds: 32));

  final context = boundaryKey.currentContext;
  if (context == null) return null;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) return null;

  final image = await renderObject.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return null;

  return byteData.buffer.asUint8List();
}

String _buildRecapFileName(ListeningRecap recap, {String? variant}) {
  final now = DateTime.now();
  final variantSegment = variant == null ? 'replay' : 'replay_$variant';
  return 'flick_${recap.period.label.toLowerCase()}_${variantSegment}_${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}.png';
}

String _saveErrorMessage(Object error) {
  if (error is GallerySaveException) {
    return error.message;
  }
  return 'Failed to save the recap image.';
}

String _heroClosingLine(ListeningRecap recap) {
  if (!recap.hasData) {
    return recap.period.emptyMessage;
  }

  if (recap.topArtist != null && recap.topSong != null) {
    final topSongPlays = _formatPlayCount(recap.topSong!.plays);
    return '${recap.topArtist!.artist} led the rotation, and "${recap.topSong!.song.title}" finished as your most replayed track with $topSongPlays out of ${recap.totalPlays} total.';
  }

  if (recap.topSong != null) {
    return '"${recap.topSong!.song.title}" led this ${recap.period.label.toLowerCase()} recap with ${_formatPlayCount(recap.topSong!.plays)} out of ${recap.totalPlays} total.';
  }

  return 'Your listening pattern is starting to take shape.';
}

String _formatRecapRange(ListeningRecap recap) {
  final endInclusive = recap.endExclusive.subtract(const Duration(days: 1));
  switch (recap.period) {
    case ListeningRecapPeriod.daily:
      return '${_monthName(recap.start.month)} ${recap.start.day}, ${recap.start.year}';
    case ListeningRecapPeriod.weekly:
      return '${_monthName(recap.start.month)} ${recap.start.day} - ${_monthName(endInclusive.month)} ${endInclusive.day}, ${endInclusive.year}';
    case ListeningRecapPeriod.monthly:
      return '${_monthName(recap.start.month)} ${recap.start.year}';
    case ListeningRecapPeriod.yearly:
      return '${recap.start.year}';
  }
}

String _formatCompactDuration(Duration duration) {
  if (duration == Duration.zero) return '0m';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }
  return '${duration.inMinutes}m';
}

String _formatPeakHour(int? hour) {
  if (hour == null) return '--';
  final period = hour >= 12 ? 'PM' : 'AM';
  final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$normalizedHour $period';
}

String _formatPlayCount(int plays) {
  return plays == 1 ? '1 play' : '$plays plays';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
