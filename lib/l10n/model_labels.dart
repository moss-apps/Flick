// 模型层的本地化展示扩展。
//
// **为什么单独一个文件**：`lib/models/` 必须保持与语言无关。模型只描述数据与状态，
// 不该知道「当前是什么语言」——否则模型层会同时依赖 UI 层，既破坏分层，也让本来
// 可以纯逻辑单测的模型必须先把 locale 环境搭起来。
//
// 上游 review 的原话：
//
//   keeps models locale-free, and will only translate at the widget layer.
//   Global l10n in models will hurt the layering or testability and
//   callable-typed fields break constant enums.
//
// 所以展示文案全部搬到这里。模型文件里只留 `storageValue` 这类**持久化键**——它们
// 是数据不是文案，永远不翻译。
//
// 扩展沿用原来的成员名（`label` / `description` / `menuLabel` / …），因此调用点
// 不需要改写；调用方只要 import 本文件（或 import `l10n.dart`，后者 re-export 了
// 本文件）即可。
//
// 这里读的是全局 `l10n` 而不是 `context.l10n`，因为其中一部分成员在无 BuildContext
// 的地方被使用（持久化默认值、调试输出等）。需要显式传入时，请改用 `l10n.dart`
// 里的 `context.l10n` 版访问器。

import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/advance_list_order.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/models/shuffle_mode.dart';
import 'package:flick/models/song_tile_thumbnail_mode.dart';
import 'package:flick/models/song_view_mode.dart';

// ---------------------------------------------------------------------------
// 推进列表顺序
// ---------------------------------------------------------------------------
extension AdvanceListOrderL10n on AdvanceListOrder {
  String get label => switch (this) {
    AdvanceListOrder.alphabetical => l10n.alphabetical,
    AdvanceListOrder.dateAdded => l10n.dateAdded,
    AdvanceListOrder.random => l10n.random,
  };

  String get description => switch (this) {
    AdvanceListOrder.alphabetical => l10n.advanceToTheNextCategoryAlphabetically,
    AdvanceListOrder.dateAdded => l10n.advanceToTheNextMostRecently,
    AdvanceListOrder.random => l10n.advanceToARandomCategory,
  };
}

// ---------------------------------------------------------------------------
// 专辑取色模式
// ---------------------------------------------------------------------------
extension AlbumColorModeL10n on AlbumColorMode {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    AlbumColorMode.off => l10n.off,
    AlbumColorMode.subtle => l10n.subtle,
    AlbumColorMode.moderate => l10n.moderate,
    AlbumColorMode.vibrant => l10n.vibrant,
  };

  String get description => switch (this) {
    AlbumColorMode.off => l10n.useTheDefaultMonochromeTheme,
    AlbumColorMode.subtle => l10n.faintHueShiftFromAlbumArt,
    AlbumColorMode.moderate => l10n.noticeableTintingFromAlbumArt,
    AlbumColorMode.vibrant => l10n.boldSaturatedColorsFromAlbumArt,
  };
}

// ---------------------------------------------------------------------------
// 音频引擎类型
// ---------------------------------------------------------------------------
extension AudioEngineTypeL10n on AudioEngineType {
  String get userFacingLabel => switch (this) {
    AudioEngineType.normalAndroid => l10n.justAudioExoplayer,
    AudioEngineType.rustOboe => l10n.rustViaOboe,
    AudioEngineType.usbDacExperimental => l10n.bitPerfectUsbDac,
    AudioEngineType.dapInternalHighRes => l10n.rustViaOboeHighRes,
  };
}

// ---------------------------------------------------------------------------
// 底部导航按钮
// ---------------------------------------------------------------------------
extension NavBarButtonL10n on NavBarButton {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    NavBarButton.menu => l10n.menu,
    NavBarButton.songs => l10n.songs14,
    NavBarButton.settings => l10n.settings,
    NavBarButton.albums => l10n.albums,
    NavBarButton.artists => l10n.artists,
    NavBarButton.folders => l10n.folders,
    NavBarButton.playlists => l10n.playlists,
    NavBarButton.favorites => l10n.favorites,
    NavBarButton.search => l10n.search,
  };
}

// ---------------------------------------------------------------------------
// 播放来源
// ---------------------------------------------------------------------------
extension PlaybackSourceL10n on PlaybackSource {
  String get label => switch (this) {
    PlaybackSource.album => l10n.album,
    PlaybackSource.artist => l10n.artist,
    PlaybackSource.folder => l10n.folder,
    PlaybackSource.playlist => l10n.playlist2,
    PlaybackSource.allSongs => l10n.allSongs,
    PlaybackSource.network => l10n.network,
    PlaybackSource.unknown => l10n.unknown,
  };
}

// ---------------------------------------------------------------------------
// 播放器快捷按钮
// ---------------------------------------------------------------------------
extension PlayerActionButtonL10n on PlayerActionButton {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    PlayerActionButton.none => l10n.none,
    PlayerActionButton.lyrics => l10n.lyrics,
    PlayerActionButton.favorites => l10n.favorites,
    PlayerActionButton.visualizer => l10n.visualizer,
    PlayerActionButton.ratings => l10n.rating,
    PlayerActionButton.queue => l10n.queue,
    PlayerActionButton.sleepTimer => l10n.sleepTimer2,
    PlayerActionButton.share => l10n.share,
    PlayerActionButton.usbVolume => l10n.usbVolume,
    PlayerActionButton.equalizer => l10n.equalizer,
    PlayerActionButton.volume => l10n.volume,
    PlayerActionButton.cast => l10n.cast,
  };
}

// ---------------------------------------------------------------------------
// 播放器布局模式
// ---------------------------------------------------------------------------
extension PlayerScreenModeL10n on PlayerScreenMode {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    PlayerScreenMode.immersive => l10n.immersive,
    PlayerScreenMode.artworkCard => l10n.artworkCard,
  };

  String get description => switch (this) {
    PlayerScreenMode.immersive => l10n.fullBleedAlbumArtWithThe,
    PlayerScreenMode.artworkCard => l10n.roundedAlbumArtCardWithA,
  };
}

// ---------------------------------------------------------------------------
// 进度条样式
// ---------------------------------------------------------------------------
extension ProgressBarStyleL10n on ProgressBarStyle {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    ProgressBarStyle.waveform => l10n.waveform,
    ProgressBarStyle.line => l10n.line,
  };

  String get description => switch (this) {
    ProgressBarStyle.waveform => l10n.verticalBarsThatAnimateAcrossThe,
    ProgressBarStyle.line => l10n.cleanStraightLineWithPrecisionScrubbing,
  };
}

// ---------------------------------------------------------------------------
// 随机播放模式
// ---------------------------------------------------------------------------
extension ShuffleModeL10n on ShuffleMode {
  String get label => switch (this) {
    ShuffleMode.off => l10n.off,
    ShuffleMode.songs => l10n.songs14,
    ShuffleMode.songsAndCategories => l10n.songsCategories,
    ShuffleMode.categories => l10n.categories,
    ShuffleMode.random => l10n.random,
  };

  String get description => switch (this) {
    ShuffleMode.off => l10n.playInOrder,
    ShuffleMode.songs => l10n.shuffleSongsInCurrentList,
    ShuffleMode.songsAndCategories => l10n.shuffleSongsAndJumpBetweenCategories,
    ShuffleMode.categories => l10n.playCategoriesInRandomOrderTracks,
    ShuffleMode.random => l10n.trueRandomMayRepeatBeforeList,
  };
}

// ---------------------------------------------------------------------------
// 歌曲缩略图模式
// ---------------------------------------------------------------------------
extension SongTileThumbnailModeL10n on SongTileThumbnailMode {
  String get label => labelFor(l10n);

  String labelFor(AppLocalizations l10n) => switch (this) {
    SongTileThumbnailMode.artwork => l10n.albumArt,
    SongTileThumbnailMode.trackNumber => l10n.trackNumber,
    SongTileThumbnailMode.trackNumberOnArt => l10n.numberOnArt,
  };

  String get description => switch (this) {
    SongTileThumbnailMode.artwork => l10n.showAlbumArtwork,
    SongTileThumbnailMode.trackNumber => l10n.showTheTrackNumber,
    SongTileThumbnailMode.trackNumberOnArt => l10n.showTheNumberOverBlurredArt,
  };
}

// ---------------------------------------------------------------------------
// 歌曲列表视图模式
// ---------------------------------------------------------------------------
extension SongViewModeL10n on SongViewMode {
  String get menuLabel => switch (this) {
    SongViewMode.orbit => l10n.orbital,
    SongViewMode.list => l10n.list,
  };
}

// ---------------------------------------------------------------------------
// 说明：Song 与 Playlist 上曾也被搬过来几个成员，核实后撤销了。
//
//   * `Song.formattedDuration` —— 纯格式化（mm:ss / hh:mm:ss），不含任何文案，
//     本来就该留在模型里。
//   * `Song.dsdRateLabel`      —— 返回 'DSD64' / 'DSD128' 这类**技术标识**，
//     不是界面文案，同样留原地。
//   * `AudioEngineType.logLabel` —— 返回 'NORMAL_ANDROID' 这类**日志常量**，
//     翻译了反而让日志难以检索。
//   * `Playlist.toString`      —— 调试输出。分类器已把 toString 判为禁译。
//
// 教训：搬运成员前要**核实它到底用没用 l10n**（以及是不是文案），
// 不能只按名字猜。
// ---------------------------------------------------------------------------
