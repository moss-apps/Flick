package com.mossapps.flick.car.screens

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.constraints.ConstraintManager
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.SearchPhase
import com.mossapps.flick.car.ui.SearchSink
import com.mossapps.flick.car.ui.SearchVm

/**
 * Search the library. Results appear 300 ms after typing pauses and at once on submit; every
 * keystroke retires the answer to an older query, so a late answer never overwrites a newer
 * one. At Car API 9 the sections are on this page (a SearchHeader); at 8 one SearchTemplate
 * list is cut to the host's limit.
 */
class SearchScreen(carContext: CarContext, host: CarHost) : FlickScreen(carContext, host), SearchSink {
    private val main = Handler(Looper.getMainLooper())

    private var query = ""
    private var phase = SearchPhase.IDLE
    private var results: CarSearchResults? = null
    private var gen = 0
    private var debounce: Runnable? = null

    override val searchSink: SearchSink
        get() = this

    override fun page(): PageSpec {
        val limit = try {
            carContext.getCarService(ConstraintManager::class.java)
                .getContentLimit(ConstraintManager.CONTENT_LIMIT_TYPE_LIST)
        } catch (t: Throwable) {
            Log.w(TAG, "content limit unavailable: ${t.message}")
            DEFAULT_LIST_LIMIT
        }
        return Pages.search(SearchVm(query, phase, results, limit), host.api9)
    }

    override fun reload() {
        // Search has nothing to load until the driver types.
    }

    override fun onDestroyed() {
        debounce?.let { main.removeCallbacks(it) }
        debounce = null
    }

    // ------------------------------------------------------------------ typing

    override fun textChanged(text: String) {
        if (fence.isClosed) return
        if (text == query) return
        query = text
        // Retire the answer to the previous text and any search that has not started.
        gen++
        debounce?.let { main.removeCallbacks(it) }
        debounce = null
        if (text.isBlank()) {
            phase = SearchPhase.IDLE
            results = null
            redraw()
            return
        }
        val token = gen
        val run = Runnable {
            debounce = null
            if (!fence.isClosed && token == gen) search(text)
        }
        debounce = run
        main.postDelayed(run, DEBOUNCE_MS)
    }

    override fun submitted(text: String) {
        if (fence.isClosed) return
        query = text
        debounce?.let { main.removeCallbacks(it) }
        debounce = null
        if (text.isBlank()) {
            gen++
            phase = SearchPhase.IDLE
            results = null
            redraw()
            return
        }
        search(text)
    }

    private fun search(text: String) {
        val token = ++gen
        phase = SearchPhase.LOADING
        redraw()
        host.link.search(text.trim(), CarLimits.SEARCH_PER_TYPE) { result ->
            if (fence.isClosed || token != gen) return@search
            result.onSuccess {
                results = it
                phase = SearchPhase.READY
            }.onFailure {
                Log.w(TAG, "search failed: ${it.message}")
                results = null
                phase = SearchPhase.FAILED
            }
            redraw()
        }
    }

    override fun handle(intent: CarIntent): Boolean {
        if (intent == CarIntent.Retry) {
            if (query.isNotBlank()) search(query)
            return true
        }
        return false
    }

    private companion object {
        const val TAG = "CarSearch"
        const val DEBOUNCE_MS = 300L
        const val DEFAULT_LIST_LIMIT = 6
    }
}
