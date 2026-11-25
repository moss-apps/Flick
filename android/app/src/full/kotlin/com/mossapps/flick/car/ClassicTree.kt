package com.mossapps.flick.car

import com.mossapps.flick.CarMediaId
import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.ListKind

/** One entry of the classic browse tree: the data of a `MediaBrowserCompat.MediaItem`, as plain Kotlin. */
data class ClassicNode(
    val mediaId: String,
    val title: String,
    val subtitle: String?,
    val art: String?,
    val browsable: Boolean,
    val playable: Boolean,
)

/**
 * The classic browse tree for hosts without template support (docs/ANDROID_AUTO_DESIGN.md, 3):
 *
 * ```
 * root - Recently played (playable) - Albums - Artists - Playlists - Favorites - Songs
 * ```
 *
 * Pure Kotlin: it turns the same channel models the templated UI uses into nodes and cuts them
 * to the page the host asked for. Playable items carry a [CarMediaId], which the media session's
 * `onPlayFromMediaId` parses; the structural folders (root, Albums, Artists, Playlists) carry
 * ids that are not media ids on purpose.
 */
object ClassicTree {
    const val ROOT_ID = "flick:root"
    const val ALBUMS_ID = "flick:albums"
    const val ARTISTS_ID = "flick:artists"
    const val PLAYLISTS_ID = "flick:playlists"

    /** The page size when the host does not ask for one. */
    const val DEFAULT_PAGE_SIZE = 100

    /** Nothing is ever fetched or returned beyond the channel's own cap. */
    const val MAX_PAGE_SIZE = CarLimits.LIST

    /** What a browse id names. */
    sealed interface Parent {
        data object Root : Parent
        data class Listing(val kind: ListKind) : Parent

        /** A collection whose children are its tracks. */
        data class Content(val kind: String, val id: String) : Parent
    }

    /** A page: skip [offset] nodes, return at most [size]. */
    data class Window(val offset: Int, val size: Int) {
        /** How many entries to request from Dart so this window can be filled. */
        val limit: Int
            get() = (offset + size).coerceIn(1, MAX_PAGE_SIZE)
    }

    /**
     * The window for `EXTRA_PAGE` and `EXTRA_PAGE_SIZE` (null or negative when absent): the size
     * defaults to 100, is at most 300, and a page without a size uses the default.
     */
    fun window(page: Int?, pageSize: Int?): Window {
        val size = (pageSize?.takeIf { it > 0 } ?: DEFAULT_PAGE_SIZE).coerceAtMost(MAX_PAGE_SIZE)
        val index = page?.takeIf { it > 0 } ?: 0
        return Window(offset = (index.toLong() * size).coerceAtMost(MAX_PAGE_SIZE.toLong()).toInt(), size = size)
    }

    fun parent(mediaId: String?): Parent? {
        when (mediaId) {
            null -> return null
            ROOT_ID -> return Parent.Root
            ALBUMS_ID -> return Parent.Listing(ListKind.ALBUMS)
            ARTISTS_ID -> return Parent.Listing(ListKind.ARTISTS)
            PLAYLISTS_ID -> return Parent.Listing(ListKind.PLAYLISTS)
        }
        val parsed = CarMediaId.parse(mediaId) ?: return null
        // A track is a leaf, not a folder.
        if (parsed.trackId != null) return null
        return Parent.Content(parsed.kind, parsed.id)
    }

    fun root(window: Window): List<ClassicNode> = cut(
        listOf(
            ClassicNode(
                mediaId = CarMediaId("recentlyPlayed", "").encode(),
                title = CarStrings.RECENTLY_PLAYED,
                subtitle = null,
                art = null,
                browsable = true,
                playable = true,
            ),
            folder(ALBUMS_ID, CarStrings.ALBUMS),
            folder(ARTISTS_ID, CarStrings.ARTISTS),
            folder(PLAYLISTS_ID, CarStrings.PLAYLISTS),
            ClassicNode(
                mediaId = CarMediaId("favorites", "").encode(),
                title = CarStrings.FAVORITES,
                subtitle = null,
                art = null,
                browsable = true,
                playable = false,
            ),
            ClassicNode(
                mediaId = CarMediaId("songs", "").encode(),
                title = CarStrings.SONGS,
                subtitle = null,
                art = null,
                browsable = true,
                playable = false,
            ),
        ),
        window,
    )

    /** Albums, artists, playlists (or folders): each one a folder that opens onto its tracks. */
    fun listing(list: CarList, window: Window): List<ClassicNode> =
        cut(list.items.take(MAX_PAGE_SIZE).map { collectionNode(it.kind, it.id, it.title, it.subtitle, it.art) }, window)

    /** The tracks of a collection; each plays the collection from that track. */
    fun tracks(detail: CarCollectionDetail, kind: String, id: String, window: Window): List<ClassicNode> =
        cut(detail.tracks.take(MAX_PAGE_SIZE).map { trackNode(it.id, it.title, it.artist, it.art, kind, id) }, window)

    /** Search: songs first (each plays the result list from itself), then the collections found. */
    fun search(results: CarSearchResults, query: String, window: Window): List<ClassicNode> {
        val cap = CarLimits.SEARCH_PER_TYPE
        val nodes = mutableListOf<ClassicNode>()
        for (track in results.tracks.take(cap)) {
            nodes += trackNode(track.id, track.title, track.artist, track.art, "search", query)
        }
        for (item in (results.albums.take(cap) + results.artists.take(cap) + results.playlists.take(cap))) {
            nodes += collectionNode(item.kind, item.id, item.title, item.subtitle, item.art)
        }
        return cut(nodes, window)
    }

    fun cut(nodes: List<ClassicNode>, window: Window): List<ClassicNode> =
        nodes.drop(window.offset).take(window.size)

    private fun folder(id: String, title: String) = ClassicNode(id, title, null, null, browsable = true, playable = false)

    private fun collectionNode(kind: String, id: String, title: String, subtitle: String?, art: String?) = ClassicNode(
        mediaId = CarMediaId(kind, id).encode(),
        title = title.ifBlank { CarStrings.UNTITLED },
        subtitle = subtitle,
        art = art,
        browsable = true,
        playable = false,
    )

    private fun trackNode(
        trackId: String,
        title: String,
        artist: String,
        art: String?,
        kind: String,
        id: String,
    ) = ClassicNode(
        mediaId = CarMediaId(kind, id, trackId).encode(),
        title = title.ifBlank { CarStrings.UNKNOWN_TITLE },
        subtitle = artist.ifBlank { null },
        art = art,
        browsable = false,
        playable = true,
    )
}
