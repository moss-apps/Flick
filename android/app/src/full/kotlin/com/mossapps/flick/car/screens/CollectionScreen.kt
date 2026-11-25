package com.mossapps.flick.car.screens

import android.util.Log
import androidx.car.app.CarContext
import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.CollectionTarget
import com.mossapps.flick.car.ui.CollectionVm
import com.mossapps.flick.car.ui.LoadState
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages

/**
 * An album, artist, playlist, folder, Songs, Favorites, "See all" list, or one of the whole
 * lists (albums, artists, playlists, folders, recently added). Tapping a track plays the
 * complete collection from that track, like the phone.
 */
class CollectionScreen(
    carContext: CarContext,
    host: CarHost,
    private val target: CollectionTarget,
) : FlickScreen(carContext, host) {
    private var state = LoadState.LOADING
    private var detail: CarCollectionDetail? = null
    private var list: CarList? = null

    /** Up next is offered, and whether the playing song is in this collection. */
    private var hasUpNext = false
    private var playing = false

    private var loadGen = 0
    private var queueGen = 0

    private fun live(generation: Int, current: Int) = !fence.isClosed && generation == current

    override fun page(): PageSpec = Pages.collection(
        CollectionVm(
            target = target,
            state = state,
            detail = detail,
            list = list,
            hasUpNext = hasUpNext,
            playing = playing,
            albumColor = host.albumColor,
        ),
        host.api9,
    )

    override fun reload() {
        val token = ++loadGen
        if (detail == null && list == null) state = LoadState.LOADING
        when (target) {
            is CollectionTarget.Content -> host.link.collection(target.kind, target.id, CarLimits.LIST) { result ->
                if (!live(token, loadGen)) return@collection
                result.onSuccess { fresh ->
                    val unchanged = fresh == detail && state == LoadState.READY
                    detail = fresh
                    state = LoadState.READY
                    refreshPlaying()
                    if (!unchanged) redraw()
                }.onFailure { failed(it) }
            }
            is CollectionTarget.Listing -> host.link.list(target.kind, CarLimits.LIST) { result ->
                if (!live(token, loadGen)) return@list
                result.onSuccess { fresh ->
                    val unchanged = fresh == list && state == LoadState.READY
                    list = fresh
                    state = LoadState.READY
                    refreshPlaying()
                    if (!unchanged) redraw()
                }.onFailure { failed(it) }
            }
        }
    }

    private fun failed(failure: Throwable) {
        Log.w(TAG, "${target.title} failed: ${failure.message}")
        state = LoadState.FAILED
        redraw()
    }

    /**
     * One small `queue` request tells whether something is playing or queued (the Up next
     * action) and whether the playing song belongs here (the chips take the ALBUM colour).
     */
    private fun refreshPlaying() {
        val token = ++queueGen
        host.link.queue(limit = 1) { result ->
            if (!live(token, queueGen)) return@queue
            result.onSuccess { queue ->
                val nextUpNext = queue.current != null || queue.fromYou.isNotEmpty() || queue.fromContext.isNotEmpty()
                val currentId = queue.current?.id
                val nextPlaying = currentId != null && detail?.tracks?.any { it.id == currentId } == true
                if (nextUpNext != hasUpNext || nextPlaying != playing) {
                    hasUpNext = nextUpNext
                    playing = nextPlaying
                    redraw()
                }
            }
        }
    }

    override fun handle(intent: CarIntent): Boolean {
        if (intent == CarIntent.Retry) {
            reload()
            return true
        }
        return false
    }

    override fun onChange(what: String) {
        when (what) {
            "library" -> reloadWhenVisible()
            // The track under the playing indicator changed; the contents did not.
            "track", "queue" -> if (state == LoadState.READY && isTop()) refreshPlaying()
        }
    }

    override fun onAlbumColorChanged() {
        // ALBUM tints the chips of the playing collection, at level 9 only.
        if (host.api9 && playing && isTop()) redraw()
    }

    private companion object {
        const val TAG = "CarCollection"
    }
}
