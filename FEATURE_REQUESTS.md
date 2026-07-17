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

## Audio Analysis

### Measurement

- TT Dynamic Range (DR) measurement
- LUFS loudness analysis
- True Peak (dBTP)
- Loudness Range (LRA)
- Clipping detection
- Effective bit-depth estimation
- Spectral bandwidth analysis
- Fake-lossless detection
- Overall fidelity scoring
- Mastering quality grading
- Cached analysis
- Batch album analysis
- Exportable analysis reports

### Spectrogram

- Calibrated FFT spectrogram
- True re-analysis while zooming
- Higher FFT resolution on deeper zoom
- Stereo / Left / Right / Mid / Side view
- Linear & Log frequency scales
- Tap-to-inspect (Hz, dB, Time)
- Full Nyquist display
- Exportable spectrogram images

### Notes

Several of these pair very well with Flick's existing audio-focused feature
set. In particular:

- **High-value features:** LUFS, True Peak, LRA, Clipping Detection,
  Fake-Lossless Detection, Calibrated FFT Spectrogram, Mid/Side View, Zoom
  Re-analysis.
- **Great for audiophiles:** Dynamic Range Meter, Spectral Bandwidth Analysis,
  Bit-depth Estimation, Mastering Quality Grading.
- **Power-user additions:** Batch Album Analysis, Cached Analysis, Exportable
  Reports, Exportable Spectrograms.
