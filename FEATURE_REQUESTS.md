# Feature Requests

User-suggested enhancements that are deferred (not implemented yet).

## Album list view — additional columns

The album list view (`_AlbumListTile` in
`lib/features/songs/screens/songs_screen.dart`) currently shows artwork, album
name, track count, artist, and (newly added) **Year**.

Requested but not yet built:

- **Genre** column — derivable from `Song.genre` (first non-null across the
  album's songs, same scan pattern used for Year).
- **Total duration** column — sum of `Song.duration` across the album's songs.
- **Track count as its own column** (currently inline in the subtitle as
  `"$trackCount tracks • $artist"`).

Adding more columns means turning the `Row` in `_AlbumListTile.build` into a
wider multi-column layout (or a true `DataTable`). Watch for overflow on narrow
devices — consider making columns configurable/toggleable via a setting when
this is picked up.
