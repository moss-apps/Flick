package com.mossapps.flick.car.screens

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.car.app.CarContext
import com.mossapps.flick.car.EngineGate
import com.mossapps.flick.car.Probe
import com.mossapps.flick.car.model.CarHome
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.EngineState
import com.mossapps.flick.car.ui.ListKind
import com.mossapps.flick.car.ui.LoadState
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.RootTab
import com.mossapps.flick.car.ui.RootVm

/**
 * The root page. At Car API 9 the first section is the destination chips (Home, Albums,
 * Artists, Playlists) and a tap re-renders this same screen in place; at level 8 the Browse
 * grid pushes collection screens. A cold start waits for the phone side of Flick with the
 * loading template (EngineGate), then shows "Flick is still starting" with Retry.
 */
class RootScreen(carContext: CarContext, host: CarHost) : FlickScreen(carContext, host) {
    private val main = Handler(Looper.getMainLooper())

    private var engine = EngineState.STARTING
    private var tab = RootTab.HOME
    private var home: CarHome? = null
    private var homeState = LoadState.LOADING
    private var tabList: CarList? = null
    private var tabKind: ListKind? = null
    private var tabState = LoadState.LOADING
    private var probeStartedAt = 0L
    private var pendingProbe: Runnable? = null

    // One generation per kind of request, so a home refresh does not retire a list request.
    private var probeGen = 0
    private var homeGen = 0
    private var tabGen = 0

    private fun live(generation: Int, current: Int) = !fence.isClosed && generation == current

    override fun page(): PageSpec = Pages.root(
        RootVm(
            engine = engine,
            tab = tab,
            home = home,
            homeState = homeState,
            tabList = tabList,
            tabState = tabState,
            albumColor = host.albumColor,
        ),
        host.api9,
    )

    override fun onDestroyed() {
        pendingProbe?.let { main.removeCallbacks(it) }
        pendingProbe = null
    }

    // ----------------------------------------------------------------- loading

    /** Start over: wait for the engine if it was not ready, then fetch the home answer. */
    override fun reload() {
        if (engine == EngineState.READY) {
            loadHome(refresh = true)
        } else {
            startProbe()
        }
    }

    private fun startProbe() {
        pendingProbe?.let { main.removeCallbacks(it) }
        pendingProbe = null
        val token = ++probeGen
        engine = EngineState.STARTING
        homeState = LoadState.LOADING
        probeStartedAt = SystemClock.elapsedRealtime()
        redraw()
        probe(token)
    }

    private fun probe(token: Int) {
        host.link.status { result ->
            if (!live(token, probeGen)) return@status
            when (EngineGate.classify(result)) {
                Probe.READY -> {
                    engine = EngineState.READY
                    loadHome(refresh = false)
                }
                Probe.WAIT -> {
                    if (EngineGate.gaveUp(SystemClock.elapsedRealtime() - probeStartedAt)) {
                        engine = EngineState.STILL_STARTING
                        redraw()
                    } else {
                        val next = Runnable {
                            pendingProbe = null
                            if (live(token, probeGen)) probe(token)
                        }
                        pendingProbe = next
                        main.postDelayed(next, EngineGate.POLL_INTERVAL_MS)
                    }
                }
                Probe.FAILED -> {
                    // The engine answers but the library does not: a retry state, not a wait.
                    Log.w(TAG, "status failed: ${result.exceptionOrNull()?.message}")
                    engine = EngineState.READY
                    homeState = LoadState.FAILED
                    redraw()
                }
            }
        }
    }

    private fun loadHome(refresh: Boolean) {
        val token = ++homeGen
        if (home == null) homeState = LoadState.LOADING
        host.link.home(refresh) { result ->
            if (!live(token, homeGen)) return@home
            result.onSuccess { fresh ->
                // Only a changed answer redraws (docs/ANDROID_AUTO_DESIGN.md, 4.5).
                val unchanged = fresh == home && homeState == LoadState.READY
                home = fresh
                homeState = LoadState.READY
                if (!unchanged) redraw()
                if (tab != RootTab.HOME) loadTab(refresh)
            }.onFailure { failure ->
                Log.w(TAG, "home failed: ${failure.message}")
                homeState = LoadState.FAILED
                redraw()
            }
        }
    }

    private fun loadTab(refresh: Boolean) {
        val kind = when (tab) {
            RootTab.ALBUMS -> ListKind.ALBUMS
            RootTab.ARTISTS -> ListKind.ARTISTS
            RootTab.PLAYLISTS -> ListKind.PLAYLISTS
            RootTab.HOME -> return
        }
        if (tabKind != kind) {
            tabKind = kind
            tabList = null
        }
        if (tabList == null) tabState = LoadState.LOADING
        val token = ++tabGen
        host.link.list(kind, CarLimits.LIST, refresh) { result ->
            if (!live(token, tabGen) || tabKind != kind) return@list
            result.onSuccess { fresh ->
                val unchanged = fresh == tabList && tabState == LoadState.READY
                tabList = fresh
                tabState = LoadState.READY
                if (!unchanged) redraw()
            }.onFailure { failure ->
                Log.w(TAG, "list ${kind.wire} failed: ${failure.message}")
                tabState = LoadState.FAILED
                redraw()
            }
        }
    }

    // ----------------------------------------------------------------- events

    override fun handle(intent: CarIntent): Boolean {
        when (intent) {
            is CarIntent.SelectTab -> {
                if (host.api9 && intent.tab != tab) {
                    tab = intent.tab
                    // Only the selected key changes now; the data follows with one more redraw.
                    redraw()
                    loadTab(refresh = false)
                }
                return true
            }
            CarIntent.Retry -> {
                // A retry starts from the top: the engine may have come up since.
                if (engine == EngineState.READY) loadHome(refresh = true) else startProbe()
                return true
            }
            else -> return false
        }
    }

    override fun onChange(what: String) {
        when (what) {
            // Resume, Up next and the lists all come from the library or the player.
            "library", "track", "queue" -> if (engine == EngineState.READY) reloadWhenVisible()
        }
    }

    override fun onAlbumColorChanged() {
        // ALBUM tints the hero icons, which exist at level 9 only.
        if (host.api9 && isTop()) redraw()
    }

    private companion object {
        const val TAG = "CarRoot"
    }
}
