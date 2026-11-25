package com.mossapps.flick.car.model

/** The channel answered with something that is not the contract (docs/ANDROID_AUTO_DESIGN.md, 4.3). */
class CarModelException(message: String) : Exception(message)

enum class CarLoop { OFF, ALL, ONE }

/** `Track {id, title, artist, album, art?, durationMs, quality?, trackNo?}` */
data class CarTrack(
    val id: String,
    val title: String,
    val artist: String,
    val album: String,
    val art: String?,
    val durationMs: Long,
    val quality: String?,
    val trackNo: Int?,
)

/** `Collection {kind, id, title, subtitle?, art?, count?}`, plus the additive `quality`. */
data class CarCollection(
    val kind: String,
    val id: String,
    val title: String,
    val subtitle: String?,
    val art: String?,
    val count: Int?,
    val quality: String?,
)

data class CarStatus(val ready: Boolean, val songCount: Int)

data class CarCounts(
    val songs: Int,
    val albums: Int,
    val artists: Int,
    val playlists: Int,
    val favorites: Int,
    val folders: Int,
)

data class CarHome(
    val resume: CarTrack?,
    val jumpBackIn: List<CarCollection>,
    val recentlyAdded: List<CarCollection>,
    val mostPlayed: List<CarTrack>,
    val playlists: List<CarCollection>,
    val counts: CarCounts,
    val queueCount: Int,
)

data class CarList(val items: List<CarCollection>, val total: Int)

data class CarCollectionDetail(
    val title: String,
    val subtitle: String?,
    val art: String?,
    val quality: String?,
    val tracks: List<CarTrack>,
    val albums: List<CarCollection>,
    val total: Int,
    /** The dominant cover colour (ARGB) when Dart computed one. */
    val color: Int?,
)

data class CarSearchResults(
    val tracks: List<CarTrack>,
    val albums: List<CarCollection>,
    val artists: List<CarCollection>,
    val playlists: List<CarCollection>,
) {
    val isEmpty: Boolean
        get() = tracks.isEmpty() && albums.isEmpty() && artists.isEmpty() && playlists.isEmpty()
}

data class CarQueue(
    val current: CarTrack?,
    val fromYou: List<CarTrack>,
    val fromContext: List<CarTrack>,
    val contextName: String?,
    val shuffle: Boolean,
    val loop: CarLoop,
)

/**
 * Reads the plain maps and lists the Dart side answers with. Strict about the
 * shape (a result that is not a map is [CarModelException]) and forgiving about
 * the fields: Dart integers arrive as Int or Long, ids may be numbers, an entry
 * that cannot be read is dropped without shifting the ones after it, and a
 * missing optional field is null.
 */
object CarModels {
    /** These collections are the whole list, so they carry no id of their own. */
    val SINGLETON_KINDS = setOf("songs", "favorites", "recentlyAdded", "mostPlayed", "recentlyPlayed")

    fun status(raw: Any?): CarStatus {
        val map = map(raw, "status")
        return CarStatus(
            ready = map["ready"] == true,
            songCount = int(map["songCount"]) ?: 0,
        )
    }

    fun home(raw: Any?): CarHome {
        val map = map(raw, "home")
        val counts = (map["counts"] as? Map<*, *>)
        return CarHome(
            resume = track(map["resume"]),
            jumpBackIn = collections(map["jumpBackIn"]),
            recentlyAdded = collections(map["recentlyAdded"]),
            mostPlayed = tracks(map["mostPlayed"]),
            playlists = collections(map["playlists"]),
            counts = CarCounts(
                songs = int(counts?.get("songs")) ?: 0,
                albums = int(counts?.get("albums")) ?: 0,
                artists = int(counts?.get("artists")) ?: 0,
                playlists = int(counts?.get("playlists")) ?: 0,
                favorites = int(counts?.get("favorites")) ?: 0,
                folders = int(counts?.get("folders")) ?: 0,
            ),
            queueCount = int(map["queueCount"]) ?: 0,
        )
    }

    fun list(raw: Any?): CarList {
        val map = map(raw, "list")
        val items = collections(map["items"])
        return CarList(items, total = int(map["total"])?.coerceAtLeast(items.size) ?: items.size)
    }

    fun collection(raw: Any?): CarCollectionDetail {
        val map = map(raw, "collection")
        val tracks = tracks(map["tracks"])
        return CarCollectionDetail(
            title = string(map["title"]) ?: "",
            subtitle = string(map["subtitle"]),
            art = string(map["art"]),
            quality = string(map["quality"]),
            tracks = tracks,
            albums = collections(map["albums"]),
            total = int(map["total"])?.coerceAtLeast(tracks.size) ?: tracks.size,
            color = int(map["color"]),
        )
    }

    fun search(raw: Any?): CarSearchResults {
        val map = map(raw, "search")
        return CarSearchResults(
            tracks = tracks(map["tracks"]),
            albums = collections(map["albums"]),
            artists = collections(map["artists"]),
            playlists = collections(map["playlists"]),
        )
    }

    fun queue(raw: Any?): CarQueue {
        val map = map(raw, "queue")
        return CarQueue(
            current = track(map["current"]),
            fromYou = tracks(map["fromYou"]),
            fromContext = tracks(map["fromContext"]),
            contextName = string(map["contextName"]),
            shuffle = map["shuffle"] == true,
            loop = loop(map["loop"]),
        )
    }

    fun loop(raw: Any?): CarLoop = when (raw) {
        "all" -> CarLoop.ALL
        "one" -> CarLoop.ONE
        else -> CarLoop.OFF
    }

    /** One track, or null when it has no usable id. */
    fun track(raw: Any?): CarTrack? {
        val map = raw as? Map<*, *> ?: return null
        val id = id(map["id"])?.takeIf { it.isNotEmpty() } ?: return null
        return CarTrack(
            id = id,
            title = string(map["title"]) ?: "",
            artist = string(map["artist"]) ?: "",
            album = string(map["album"]) ?: "",
            art = string(map["art"]),
            durationMs = long(map["durationMs"])?.coerceAtLeast(0) ?: 0L,
            quality = string(map["quality"]),
            trackNo = int(map["trackNo"])?.takeIf { it > 0 },
        )
    }

    /** One collection, or null when it has no kind or no id (singleton kinds need none). */
    fun collectionItem(raw: Any?): CarCollection? {
        val map = raw as? Map<*, *> ?: return null
        val kind = string(map["kind"]) ?: return null
        val id = id(map["id"]) ?: return null
        if (id.isEmpty() && kind !in SINGLETON_KINDS) return null
        return CarCollection(
            kind = kind,
            id = id,
            title = string(map["title"]) ?: "",
            subtitle = string(map["subtitle"]),
            art = string(map["art"]),
            count = int(map["count"])?.takeIf { it >= 0 },
            quality = string(map["quality"]),
        )
    }

    fun tracks(raw: Any?): List<CarTrack> =
        (raw as? List<*>)?.mapNotNull { track(it) } ?: emptyList()

    fun collections(raw: Any?): List<CarCollection> =
        (raw as? List<*>)?.mapNotNull { collectionItem(it) } ?: emptyList()

    // ---------------------------------------------------------------- scalars

    private fun map(raw: Any?, what: String): Map<*, *> =
        raw as? Map<*, *> ?: throw CarModelException("$what: expected a map, got ${raw?.javaClass?.simpleName}")

    /** A non-blank string; anything else is absent. */
    fun string(raw: Any?): String? = (raw as? String)?.takeIf { it.isNotBlank() }

    /** An id is a non-empty string or a number written out. Singleton collections use "". */
    private fun id(raw: Any?): String? = when (raw) {
        is String -> raw
        is Number -> raw.toString()
        else -> null
    }

    /** Int from Int, Long (wrapping, which is right for ARGB colours) or any other number. */
    fun int(raw: Any?): Int? = (raw as? Number)?.toInt()

    fun long(raw: Any?): Long? = (raw as? Number)?.toLong()
}
