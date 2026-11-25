package com.mossapps.flick.car.ui

/*
 * A page as plain data, independent of the Car App Library (docs/ANDROID_AUTO_DESIGN.md, 6).
 *
 * Pages builds these from a view model, Render turns them into templates. A spec
 * that only exists at Car API 9 implements [Api9Spec]; a JVM test builds every page
 * at level 8 and walks the tree to prove none appears. Taps are [CarIntent]s (data),
 * not lambdas, so a page can be compared and inspected.
 *
 * No androidx.car import is allowed in this file or in Pages.kt.
 */

/** Marker: this spec can only be drawn at Car API 9 and must never be built for a level 8 host. */
interface Api9Spec

// ------------------------------------------------------------------- intents

enum class RootTab { HOME, ALBUMS, ARTISTS, PLAYLISTS }

/** Whole-list destinations answered by the channel's `list` method. */
enum class ListKind(val wire: String) {
    ALBUMS("albums"),
    ARTISTS("artists"),
    PLAYLISTS("playlists"),
    FOLDERS("folders"),
    RECENTLY_ADDED("recentlyAdded"),
}

/** What a tap does. The screen decides how: a push, a channel command, a reload. */
sealed interface CarIntent {
    /** Push the list screen of albums, artists, playlists, folders or recently added. */
    data class OpenList(val kind: ListKind) : CarIntent

    /** Push a collection screen: album, artist, playlist, folder, songs, favorites, mostPlayed... */
    data class OpenCollection(val kind: String, val id: String, val title: String) : CarIntent

    /** Play the complete collection, from [trackId] when given; [shuffle] turns shuffle on. */
    data class Play(
        val kind: String,
        val id: String,
        val trackId: String? = null,
        val shuffle: Boolean = false,
    ) : CarIntent

    data class Enqueue(val kind: String, val id: String) : CarIntent

    /** Continue what the phone had loaded. */
    data object Resume : CarIntent

    data class SelectTab(val tab: RootTab) : CarIntent

    data object OpenSearch : CarIntent
    data object OpenUpNext : CarIntent
    data object Retry : CarIntent

    /** Back to the root page. */
    data object Browse : CarIntent

    data object ToggleShuffle : CarIntent
    data object CycleLoop : CarIntent
    data object ClearQueue : CarIntent

    /** Jump to a queue row: [section] is `you` or `context`, [index] counts inside it. */
    data class Jump(val section: String, val index: Int) : CarIntent
}

// -------------------------------------------------------------------- images

enum class IconId {
    ALBUMS, ARTISTS, PLAYLISTS, SONGS, FAVORITES, FOLDERS, SEARCH, QUEUE,
    SHUFFLE, REPEAT, REPEAT_ONE, PLAY, ADD_QUEUE, PLACEHOLDER,
}

/** An ARGB tint for a bundled icon. Level 9 only: lower hosts take the default tint. */
data class IconTint(val color: Int) : Api9Spec

/**
 * A cover ([art] is a file path the channel handed out; null means the bundled
 * placeholder) or a bundled [icon]. Never both.
 */
data class ImageSpec(
    val art: String? = null,
    val icon: IconId? = null,
    val tint: IconTint? = null,
) {
    init {
        require(art == null || icon == null) { "an image is a cover or an icon, not both" }
    }

    companion object {
        fun cover(art: String?) = ImageSpec(art = art)
        fun icon(id: IconId, tint: IconTint? = null) = ImageSpec(icon = id, tint = tint)
    }
}

// ------------------------------------------------------------------ headers

enum class StartAction { NONE, BACK, APP_ICON }

data class ActionSpec(val title: String, val onClick: CarIntent)

/** Header subtitle and cover: Car API 9 only. */
data class HeaderModern(val subtitle: String?, val startImage: ImageSpec?) : Api9Spec

data class HeaderSpec(
    val title: String,
    val start: StartAction,
    val end: List<ActionSpec> = emptyList(),
    val modern: HeaderModern? = null,
)

/** A section header with a click target or a headline: Car API 9 only. At 8 a section has a plain title. */
data class SectionHeaderSpec(
    val title: String,
    val subtitle: String? = null,
    val headline: String? = null,
    val onClick: CarIntent? = null,
) : Api9Spec {
    init {
        require(subtitle == null || headline == null) { "a section header has a headline or a subtitle, not both" }
    }
}

/** Search header of the sectioned search page: Car API 9 only. */
data class SearchHeaderSpec(val initialText: String, val hint: String) : Api9Spec

// ----------------------------------------------------------------- sections

/** Marks a grid or condensed section that keeps its incomplete last row as is: Car API 9 only. */
data object LastRowAsIs : Api9Spec

sealed interface SectionSpec

enum class RowImage { NONE, SMALL, LARGE }

data class RowSpec(
    val title: String,
    val texts: List<String> = emptyList(),
    val image: ImageSpec? = null,
    val imageSize: RowImage = RowImage.LARGE,
    val browsable: Boolean = false,
    val indexable: Boolean = false,
    val onClick: CarIntent? = null,
)

data class RowSectionSpec(
    val title: String?,
    val rows: List<RowSpec>,
    val header: SectionHeaderSpec? = null,
) : SectionSpec

enum class GridSize { SMALL, LARGE }

data class GridItemSpec(
    val title: String,
    val text: String? = null,
    val image: ImageSpec,
    val onClick: CarIntent? = null,
)

/** [iconTiles]: the items carry bundled icons, not covers (drawn with the icon image type). */
data class GridSectionSpec(
    val title: String?,
    val size: GridSize,
    val items: List<GridItemSpec>,
    val circle: Boolean = false,
    val iconTiles: Boolean = false,
    val header: SectionHeaderSpec? = null,
    val lastRow: LastRowAsIs? = null,
) : SectionSpec

data class CondensedItemSpec(
    val title: String,
    val text: String? = null,
    val leading: ImageSpec? = null,
    val onClick: CarIntent? = null,
)

data class CondensedSectionSpec(
    val title: String?,
    val items: List<CondensedItemSpec>,
    val header: SectionHeaderSpec? = null,
    val lastRow: LastRowAsIs? = LastRowAsIs,
) : SectionSpec, Api9Spec

data class SpotlightSectionSpec(
    val title: String?,
    val cover: ImageSpec,
    val items: List<CondensedItemSpec>,
) : SectionSpec, Api9Spec

/** [fill] is the banner background (ARGB); null keeps the host's. */
data class BannerSpec(
    val title: String,
    val subtitle: String? = null,
    val leading: ImageSpec? = null,
    val fill: Int? = null,
    val action: ActionSpec? = null,
    val onClick: CarIntent? = null,
)

data class BannerSectionSpec(val banner: BannerSpec) : SectionSpec, Api9Spec

/** [fill] null means no fill (outlined); [content] is the text colour on it. All ARGB. */
data class ChipLook(val fill: Int?, val outline: Int?, val content: Int)

data class ChipSpec(
    val title: String,
    val selected: Boolean,
    val look: ChipLook,
    val icon: ImageSpec? = null,
    val onClick: CarIntent,
)

data class ChipSectionSpec(val chips: List<ChipSpec>) : SectionSpec, Api9Spec

// -------------------------------------------------------------------- pages

sealed interface PageSpec

/**
 * One SectionedItemTemplate. Level 8 pages have a [header]; the level 9 search page
 * has a [search] header instead. [playbackAction] adds `Action.MEDIA_PLAYBACK`: below
 * level 9 only, because at 9 the host draws its own minimized control panel.
 */
data class SectionedPage(
    val header: HeaderSpec?,
    val sections: List<SectionSpec>,
    val search: SearchHeaderSpec? = null,
    val loading: Boolean = false,
    val playbackAction: Boolean = false,
    val indexing: Boolean = false,
) : PageSpec

/** Level 8 search: a SearchTemplate with one list of rows. */
data class SearchListPage(
    val initialText: String,
    val hint: String,
    val rows: List<RowSpec>,
    val noItemsMessage: String,
    val loading: Boolean = false,
) : PageSpec

/** A MessageTemplate: a loading state or a message with actions. */
data class MessagePage(
    val message: String,
    val title: String? = null,
    val start: StartAction = StartAction.BACK,
    val loading: Boolean = false,
    val actions: List<ActionSpec> = emptyList(),
) : PageSpec

/** Media playback accent and round progress caps: Car API 9 only. */
data class PlayerStyle9(val accent: Int) : Api9Spec

/** The host's MediaPlaybackTemplate; transport, art and progress come from the registered session. */
data class PlayerPage(val header: HeaderSpec, val style: PlayerStyle9? = null) : PageSpec
