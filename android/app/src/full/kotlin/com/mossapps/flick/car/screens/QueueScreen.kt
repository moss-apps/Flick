package com.mossapps.flick.car.screens

import android.util.Log
import androidx.car.app.CarContext
import com.mossapps.flick.car.CarStrings
import com.mossapps.flick.car.model.CarQueue
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.LoadState
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.QueueVm

/**
 * Up next: what is playing, what the driver queued, and the rest of the playing context, in
 * the order they play. It reloads on queue and mode changes only, never on position ticks.
 */
class QueueScreen(carContext: CarContext, host: CarHost) : FlickScreen(carContext, host) {
    private var state = LoadState.LOADING
    private var queue: CarQueue? = null
    private var gen = 0

    override fun page(): PageSpec = Pages.queue(QueueVm(state, queue, host.albumColor), host.api9)

    override fun reload() {
        val token = ++gen
        if (queue == null) state = LoadState.LOADING
        host.link.queue(CarLimits.QUEUE, refresh = true) { result ->
            if (fence.isClosed || token != gen) return@queue
            result.onSuccess { fresh ->
                val unchanged = fresh == queue && state == LoadState.READY
                queue = fresh
                state = LoadState.READY
                if (!unchanged) redraw()
            }.onFailure {
                Log.w(TAG, "queue failed: ${it.message}")
                state = LoadState.FAILED
                redraw()
            }
        }
    }

    override fun handle(intent: CarIntent): Boolean {
        when (intent) {
            CarIntent.Retry -> reload()
            CarIntent.ToggleShuffle -> command { host.link.toggleShuffle(it) }
            CarIntent.CycleLoop -> command { host.link.cycleLoop(it) }
            CarIntent.ClearQueue -> command { host.link.clearQueue(it) }
            is CarIntent.Jump -> host.link.jump(intent.section, intent.index) { result ->
                if (fence.isClosed) return@jump
                result.onSuccess { host.showPlayer() }
                    .onFailure { failure -> Log.w(TAG, "jump failed: ${failure.message}") }
            }
            else -> return false
        }
        return true
    }

    /** Runs a queue command; the change event it causes reloads the page. */
    private fun command(run: ((Result<Unit>) -> Unit) -> Unit) {
        run { result ->
            if (fence.isClosed) return@run
            result.onFailure {
                Log.w(TAG, "command failed: ${it.message}")
                host.toast(CarStrings.COULDNT_LOAD)
            }
        }
    }

    override fun onChange(what: String) {
        when (what) {
            "queue", "modes", "track" -> reloadWhenVisible()
        }
    }

    override fun onAlbumColorChanged() {
        // ALBUM fills the active mode chips, which exist at level 9 only.
        if (host.api9 && isTop()) redraw()
    }

    private companion object {
        const val TAG = "CarQueue"
    }
}
