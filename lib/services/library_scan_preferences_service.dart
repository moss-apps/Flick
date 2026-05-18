import 'package:shared_preferences/shared_preferences.dart';

const int kIgnoredTrackMinSizeBytes = 500 * 1024;
const int kIgnoredTrackMinDurationMs = 60 * 1000;

class LibraryScanPreferences {
  final bool filterNonMusicFilesAndFolders;
  final bool ignoreTracksSmallerThan500Kb;
  final bool ignoreTracksShorterThan60Seconds;
  final bool createPlaylistsFromM3uFiles;
  final bool useDeepScan;

  const LibraryScanPreferences({
    this.filterNonMusicFilesAndFolders = true,
    this.ignoreTracksSmallerThan500Kb = false,
    this.ignoreTracksShorterThan60Seconds = false,
    this.createPlaylistsFromM3uFiles = false,
    this.useDeepScan = false,
  });

  LibraryScanPreferences copyWith({
    bool? filterNonMusicFilesAndFolders,
    bool? ignoreTracksSmallerThan500Kb,
    bool? ignoreTracksShorterThan60Seconds,
    bool? createPlaylistsFromM3uFiles,
    bool? useDeepScan,
  }) {
    return LibraryScanPreferences(
      filterNonMusicFilesAndFolders:
          filterNonMusicFilesAndFolders ?? this.filterNonMusicFilesAndFolders,
      ignoreTracksSmallerThan500Kb:
          ignoreTracksSmallerThan500Kb ?? this.ignoreTracksSmallerThan500Kb,
      ignoreTracksShorterThan60Seconds:
          ignoreTracksShorterThan60Seconds ??
          this.ignoreTracksShorterThan60Seconds,
      createPlaylistsFromM3uFiles:
          createPlaylistsFromM3uFiles ?? this.createPlaylistsFromM3uFiles,
      useDeepScan: useDeepScan ?? this.useDeepScan,
    );
  }
}

class LibraryScanPreferencesService {
  static const _filterNonMusicKey = 'library_scan_filter_non_music';
  static const _ignoreSmallTracksKey = 'library_scan_ignore_small_tracks';
  static const _ignoreShortTracksKey = 'library_scan_ignore_short_tracks';
  static const _createPlaylistsKey = 'library_scan_create_m3u_playlists';
  static const _useDeepScanKey = 'library_scan_use_deep_scan';

  Future<LibraryScanPreferences> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryScanPreferences(
      filterNonMusicFilesAndFolders: prefs.getBool(_filterNonMusicKey) ?? true,
      ignoreTracksSmallerThan500Kb:
          prefs.getBool(_ignoreSmallTracksKey) ?? false,
      ignoreTracksShorterThan60Seconds:
          prefs.getBool(_ignoreShortTracksKey) ?? false,
      createPlaylistsFromM3uFiles: prefs.getBool(_createPlaylistsKey) ?? false,
      useDeepScan: prefs.getBool(_useDeepScanKey) ?? false,
    );
  }

  Future<void> setFilterNonMusicFilesAndFolders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_filterNonMusicKey, value);
  }

  Future<void> setIgnoreTracksSmallerThan500Kb(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ignoreSmallTracksKey, value);
  }

  Future<void> setIgnoreTracksShorterThan60Seconds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ignoreShortTracksKey, value);
  }

  Future<void> setCreatePlaylistsFromM3uFiles(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_createPlaylistsKey, value);
  }

  Future<void> setUseDeepScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDeepScanKey, value);
  }
}
