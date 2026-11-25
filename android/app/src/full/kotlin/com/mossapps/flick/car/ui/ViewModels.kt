package com.mossapps.flick.car.ui

import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarHome
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.model.CarQueue
import com.mossapps.flick.car.model.CarSearchResults

/** The caps of docs/ANDROID_AUTO_DESIGN.md, 8: thousands of cover requests froze Android Auto. */
object CarLimits {
    const val LIST = 300
    const val QUEUE = 100
    const val SEARCH_PER_TYPE = 30
    const val JUMP_BACK_IN = 8
    const val RECENTLY_ADDED = 12
    const val MOST_PLAYED = 5
    const val HOME_PLAYLISTS = 12

    /** The stack the host allows. Root, collection, collection, Up next, player. */
    const val STACK = 5
}

/** Where a data request stands. */
enum class LoadState { LOADING, READY, FAILED }

/** Whether the phone side of Flick has started answering (design 2.1, state table). */
enum class EngineState {
    /** Polling; the template is the loading state. */
    STARTING,

    /** 12 s passed with no answer: "Flick is still starting" with Retry. */
    STILL_STARTING,
    READY,
}

data class RootVm(
    val engine: EngineState,
    val tab: RootTab,
    /** The last good answer; kept while a refresh fails so the page can say "Couldn't refresh". */
    val home: CarHome?,
    val homeState: LoadState,
    /** The list behind the Albums, Artists or Playlists chip (Car API 9). */
    val tabList: CarList?,
    val tabState: LoadState,
    /** ALBUM (resolved: never null). */
    val albumColor: Int,
) {
    /** Up next is offered when something is playing or queued. */
    val hasUpNext: Boolean
        get() = home != null && (home.resume != null || home.queueCount > 0)
}

/** A collection screen shows either a collection (`collection` method) or a list (`list` method). */
sealed interface CollectionTarget {
    val title: String

    data class Content(val kind: String, val id: String, override val title: String) : CollectionTarget

    data class Listing(val kind: ListKind, override val title: String) : CollectionTarget
}

data class CollectionVm(
    val target: CollectionTarget,
    val state: LoadState,
    val detail: CarCollectionDetail?,
    val list: CarList?,
    val hasUpNext: Boolean,
    /** The playing song belongs to this collection: its chips take the ALBUM colour. */
    val playing: Boolean,
    val albumColor: Int,
)

data class QueueVm(
    val state: LoadState,
    val queue: CarQueue?,
    val albumColor: Int,
)

enum class SearchPhase { IDLE, LOADING, READY, FAILED }

data class SearchVm(
    val query: String,
    val phase: SearchPhase,
    val results: CarSearchResults?,
    /** The host's list limit (ConstraintManager); level 8 cuts its single list to it. */
    val listLimit: Int,
)

data class PlayerVm(
    /** A session token is registered with the host. */
    val ready: Boolean,
    /** A play command was just issued and the session has not appeared yet. */
    val starting: Boolean,
    val albumColor: Int,
)
