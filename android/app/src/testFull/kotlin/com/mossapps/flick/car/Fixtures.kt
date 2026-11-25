package com.mossapps.flick.car

import com.mossapps.flick.car.model.CarCollection
import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarCounts
import com.mossapps.flick.car.model.CarHome
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.model.CarLoop
import com.mossapps.flick.car.model.CarQueue
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.model.CarTrack
import com.mossapps.flick.car.ui.CollectionTarget
import com.mossapps.flick.car.ui.CollectionVm
import com.mossapps.flick.car.ui.EngineState
import com.mossapps.flick.car.ui.ListKind
import com.mossapps.flick.car.ui.LoadState
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.PlayerVm
import com.mossapps.flick.car.ui.QueueVm
import com.mossapps.flick.car.ui.RootTab
import com.mossapps.flick.car.ui.RootVm
import com.mossapps.flick.car.ui.SearchPhase
import com.mossapps.flick.car.ui.SearchVm

/** Rich fixtures: more than every cap, every optional field both present and absent. */
object Fixtures {
    const val ALBUM = 0xFF3A7BD5.toInt()

    fun track(n: Int, art: Boolean = n % 3 != 0, quality: Boolean = n % 2 == 0, trackNo: Int? = n) = CarTrack(
        id = "t$n",
        title = "Song $n",
        artist = "Artist ${n % 7}",
        album = "Album ${n % 5}",
        art = if (art) "/data/art/$n.jpg" else null,
        durationMs = 60_000L + n * 1_000L,
        quality = if (quality) "24/96 FLAC" else null,
        trackNo = trackNo,
    )

    fun tracks(count: Int, from: Int = 1) = (from until from + count).map { track(it) }

    fun collection(kind: String, n: Int, art: Boolean = n % 4 != 0) = CarCollection(
        kind = kind,
        id = "$kind$n",
        title = "${kind.replaceFirstChar { it.uppercase() }} $n",
        subtitle = if (kind == "album") "Artist ${n % 7}" else null,
        art = if (art) "/data/art/$kind$n.jpg" else null,
        count = n + 3,
        quality = if (kind == "album" && n % 2 == 0) "24/192 FLAC" else null,
    )

    fun collections(kind: String, count: Int) = (1..count).map { collection(kind, it) }

    fun home(
        songs: Int = 4812,
        resume: CarTrack? = track(1),
        queueCount: Int = 14,
        favorites: Int = 22,
        folders: Int = 3,
    ) = CarHome(
        resume = resume,
        jumpBackIn = collections("album", 10),
        recentlyAdded = collections("album", 15),
        mostPlayed = tracks(8),
        playlists = collections("playlist", 15),
        counts = CarCounts(
            songs = songs,
            albums = 321,
            artists = 150,
            playlists = 15,
            favorites = favorites,
            folders = folders,
        ),
        queueCount = queueCount,
    )

    fun emptyHome() = CarHome(
        resume = null,
        jumpBackIn = emptyList(),
        recentlyAdded = emptyList(),
        mostPlayed = emptyList(),
        playlists = emptyList(),
        counts = CarCounts(0, 0, 0, 0, 0, 0),
        queueCount = 0,
    )

    fun list(kind: String, items: Int, total: Int = items) = CarList(collections(kind, items), total)

    fun detail(
        tracks: Int = 12,
        total: Int = tracks,
        albums: Int = 0,
        title: String = "Kind of Blue",
        subtitle: String? = "Miles Davis",
        quality: String? = "24/192 FLAC",
        art: String? = "/data/art/cover.jpg",
    ) = CarCollectionDetail(
        title = title,
        subtitle = subtitle,
        art = art,
        quality = quality,
        tracks = tracks(tracks),
        albums = collections("album", albums),
        total = total,
        color = null,
    )

    fun queue(
        you: Int = 3,
        context: Int = 150,
        current: CarTrack? = track(900),
        shuffle: Boolean = true,
        loop: CarLoop = CarLoop.ALL,
        contextName: String? = "Kind of Blue",
    ) = CarQueue(
        current = current,
        fromYou = tracks(you, from = 1000),
        fromContext = tracks(context, from = 2000),
        contextName = contextName,
        shuffle = shuffle,
        loop = loop,
    )

    fun search(perType: Int = 40) = CarSearchResults(
        tracks = tracks(perType),
        albums = collections("album", perType),
        artists = collections("artist", perType),
        playlists = collections("playlist", perType),
    )

    // ------------------------------------------------------------ view models

    fun rootVm(
        tab: RootTab = RootTab.HOME,
        home: CarHome? = home(),
        homeState: LoadState = LoadState.READY,
        engine: EngineState = EngineState.READY,
        tabList: CarList? = null,
        tabState: LoadState = LoadState.READY,
    ) = RootVm(engine, tab, home, homeState, tabList, tabState, ALBUM)

    fun collectionVm(
        target: CollectionTarget,
        detail: CarCollectionDetail? = null,
        list: CarList? = null,
        state: LoadState = LoadState.READY,
        hasUpNext: Boolean = true,
        playing: Boolean = false,
    ) = CollectionVm(target, state, detail, list, hasUpNext, playing, ALBUM)

    fun content(kind: String, id: String = "$kind-id", title: String = "Title") =
        CollectionTarget.Content(kind, id, title)

    fun listing(kind: ListKind) = CollectionTarget.Listing(kind, kind.name.lowercase())

    /** Every page the car can show, at every state this fixture set can reach. */
    fun allPages(api9: Boolean): Map<String, PageSpec> {
        val pages = linkedMapOf<String, PageSpec>()
        fun add(name: String, page: PageSpec) {
            pages[name] = page
        }

        add("root home", Pages.root(rootVm(), api9))
        add("root home no resume", Pages.root(rootVm(home = home(resume = null, queueCount = 0, favorites = 0, folders = 0)), api9))
        add("root starting", Pages.root(rootVm(engine = EngineState.STARTING), api9))
        add("root still starting", Pages.root(rootVm(engine = EngineState.STILL_STARTING), api9))
        add("root empty library", Pages.root(rootVm(home = emptyHome()), api9))
        add("root failed, no home", Pages.root(rootVm(home = null, homeState = LoadState.FAILED), api9))
        add("root loading, no home", Pages.root(rootVm(home = null, homeState = LoadState.LOADING), api9))
        add("root failed refresh", Pages.root(rootVm(homeState = LoadState.FAILED), api9))
        add("root albums tab", Pages.root(rootVm(RootTab.ALBUMS, tabList = list("album", 300, total = 321)), api9))
        add("root artists tab", Pages.root(rootVm(RootTab.ARTISTS, tabList = list("artist", 40)), api9))
        add("root playlists tab", Pages.root(rootVm(RootTab.PLAYLISTS, tabList = list("playlist", 5)), api9))
        add("root tab loading", Pages.root(rootVm(RootTab.ALBUMS, tabList = null, tabState = LoadState.LOADING), api9))
        add("root tab failed", Pages.root(rootVm(RootTab.ALBUMS, tabList = null, tabState = LoadState.FAILED), api9))
        add("root tab empty", Pages.root(rootVm(RootTab.PLAYLISTS, tabList = list("playlist", 0)), api9))

        fun coll(name: String, vm: CollectionVm) = add(name, Pages.collection(vm, api9))
        coll("album", collectionVm(content("album"), detail(12)))
        coll("album playing", collectionVm(content("album"), detail(12), playing = true))
        coll("album, truncated", collectionVm(content("album"), detail(300, total = 450)))
        coll("artist", collectionVm(content("artist"), detail(40, albums = 6, subtitle = null, quality = null)))
        coll("artist playing", collectionVm(content("artist"), detail(40, albums = 6), playing = true))
        coll("playlist", collectionVm(content("playlist"), detail(25, subtitle = null)))
        coll("songs", collectionVm(content("songs", id = ""), detail(500, total = 4812, subtitle = null, quality = null)))
        coll("favorites", collectionVm(content("favorites", id = ""), detail(30, subtitle = null)))
        coll("folder", collectionVm(content("folder"), detail(18, subtitle = null)))
        coll("most played", collectionVm(content("mostPlayed", id = ""), detail(60, subtitle = null, art = null)))
        coll("empty", collectionVm(content("playlist"), detail(0, albums = 0)))
        coll("loading", collectionVm(content("album"), state = LoadState.LOADING))
        coll("failed", collectionVm(content("album"), state = LoadState.FAILED))
        coll("no up next", collectionVm(content("album"), detail(12), hasUpNext = false))
        for (kind in ListKind.values()) {
            val wire = when (kind) {
                ListKind.ALBUMS, ListKind.RECENTLY_ADDED -> "album"
                ListKind.ARTISTS -> "artist"
                ListKind.PLAYLISTS -> "playlist"
                ListKind.FOLDERS -> "folder"
            }
            coll("list ${kind.name}", collectionVm(listing(kind), list = list(wire, 300, total = 400)))
            coll("list ${kind.name} loading", collectionVm(listing(kind), state = LoadState.LOADING))
            coll("list ${kind.name} failed", collectionVm(listing(kind), state = LoadState.FAILED))
            coll("list ${kind.name} empty", collectionVm(listing(kind), list = list(wire, 0)))
        }

        add("queue", Pages.queue(QueueVm(LoadState.READY, queue(), ALBUM), api9))
        add("queue no user queue", Pages.queue(QueueVm(LoadState.READY, queue(you = 0), ALBUM), api9))
        add("queue no context", Pages.queue(QueueVm(LoadState.READY, queue(context = 0), ALBUM), api9))
        add("queue empty", Pages.queue(QueueVm(LoadState.READY, queue(you = 0, context = 0, current = null), ALBUM), api9))
        add("queue modes off", Pages.queue(QueueVm(LoadState.READY, queue(shuffle = false, loop = CarLoop.OFF), ALBUM), api9))
        add("queue repeat one", Pages.queue(QueueVm(LoadState.READY, queue(loop = CarLoop.ONE, contextName = null), ALBUM), api9))
        add("queue loading", Pages.queue(QueueVm(LoadState.LOADING, null, ALBUM), api9))
        add("queue failed", Pages.queue(QueueVm(LoadState.FAILED, null, ALBUM), api9))

        fun search(name: String, vm: SearchVm) = add(name, Pages.search(vm, api9))
        search("search idle", SearchVm("", SearchPhase.IDLE, null, 6))
        search("search loading", SearchVm("mil", SearchPhase.LOADING, null, 6))
        search("search failed", SearchVm("mil", SearchPhase.FAILED, null, 6))
        search("search empty", SearchVm("zzz", SearchPhase.READY, CarSearchResults(emptyList(), emptyList(), emptyList(), emptyList()), 6))
        search("search results", SearchVm("mil", SearchPhase.READY, search(), 6))
        search("search results long limit", SearchVm("mil", SearchPhase.READY, search(), 200))

        add("player ready", Pages.player(PlayerVm(ready = true, starting = false, albumColor = ALBUM), api9))
        add("player starting", Pages.player(PlayerVm(ready = false, starting = true, albumColor = ALBUM), api9))
        add("player not ready", Pages.player(PlayerVm(ready = false, starting = false, albumColor = ALBUM), api9))
        return pages
    }
}
