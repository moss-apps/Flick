import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/widgets/identify_album_sheet.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/apple_music/album_identification_service.dart';
import 'package:flick/services/apple_music/auto_metadata_enricher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Lists album folders still missing artist or album tags and opens the
/// identification sheet for each. Backed by the same grouping the background
/// auto-enricher uses, so ambiguous matches end up here.
class MissingMetadataScreen extends StatefulWidget {
  const MissingMetadataScreen({super.key});

  @override
  State<MissingMetadataScreen> createState() => _MissingMetadataScreenState();
}

class _MissingMetadataScreenState extends State<MissingMetadataScreen> {
  late Future<List<_UntaggedAlbum>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_UntaggedAlbum>> _load() async {
    final songs = await SongRepository().getAllSongs();
    final groups = AutoMetadataEnricher.groupMissingByFolder(songs);
    final albums = [
      for (final entry in groups.entries)
        _UntaggedAlbum(folder: entry.key, songs: entry.value),
    ];
    albums.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return albums;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _identify(_UntaggedAlbum album) async {
    final result = await IdentifyAlbumSheet.show(
      context,
      songs: album.songs,
      initialArtist: album.artist,
      initialAlbum: album.album,
    );
    if (result != null) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Fix Missing Metadata',
      body: FutureBuilder<List<_UntaggedAlbum>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(AppConstants.spacingXl),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final albums = snapshot.data ?? const <_UntaggedAlbum>[];
          if (albums.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppConstants.spacingXl),
              child: Text(
                'Every album has artist and album tags.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsSectionHeader('Needs metadata'),
              SettingsCard(
                children: [
                  for (var index = 0; index < albums.length; index++) ...[
                    if (index > 0) const SettingsDivider(),
                    NavigationSetting(
                      icon: LucideIcons.disc3,
                      title: albums[index].title,
                      subtitle: albums[index].subtitle,
                      onTap: () => _identify(albums[index]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),
              const SizedBox(height: AppConstants.navBarHeight + 40),
            ],
          );
        },
      ),
    );
  }
}

class _UntaggedAlbum {
  _UntaggedAlbum({required this.folder, required this.songs});

  final String folder;
  final List<Song> songs;

  ({String artist, String album}) get _seeds =>
      AlbumIdentificationService.deriveFolderSeeds(songs);

  String get artist => _seeds.artist;

  String get album => _seeds.album;

  String get title => album.isNotEmpty ? album : 'Unknown Album';

  String get subtitle {
    final count = songs.length;
    final files = count == 1 ? '1 file' : '$count files';
    return artist.isEmpty ? files : '$files • $artist';
  }
}
