package com.mossapps.flick.car.screens

import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Template
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.mossapps.flick.car.CarLink
import com.mossapps.flick.car.CarStrings
import com.mossapps.flick.car.Fence
import com.mossapps.flick.car.ui.ActionSpec
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarStyle
import com.mossapps.flick.car.ui.MessagePage
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Render
import com.mossapps.flick.car.ui.SearchSink

/** What a screen needs from the car session that owns it. */
interface CarHost {
    val link: CarLink
    val style: CarStyle

    /** True when the host negotiated Car API 9. The only level any screen reads. */
    val api9: Boolean

    /** ALBUM (design 2.0): the playing album's colour, or silver. Never null. */
    val albumColor: Int

    /** A media session token is registered with the host, so the player template may be sent. */
    val playerReady: Boolean

    /** A play command was just issued and the session has not appeared yet. */
    val playerStarting: Boolean

    /** Navigation and commands every screen shares; see FlickCarSession. */
    fun perform(intent: CarIntent)

    /** Shows the player: pops to the one on the stack, or pushes it. */
    fun showPlayer()

    fun toast(text: String)
}

/**
 * A thin screen: it fetches through [CarLink], keeps the answer in plain fields, and asks
 * `Pages` for a spec and `Render` for the template. Rules every screen shares
 * (docs/ANDROID_AUTO_DESIGN.md, 4.5 and 8):
 *
 * - main thread only; every answer is fenced by a generation and dropped after the
 *   screen is destroyed or a newer request exists;
 * - taps on a screen that is not on top are ignored;
 * - nothing here throws into the host: a page that fails to build renders the retry state.
 */
abstract class FlickScreen(carContext: CarContext, protected val host: CarHost) : Screen(carContext) {
    protected val fence = Fence()

    /** Something changed while this screen was covered; reload when it comes back. */
    private var stale = false

    init {
        lifecycle.addObserver(
            object : DefaultLifecycleObserver {
                override fun onCreate(owner: LifecycleOwner) {
                    safely("load") { reload() }
                }

                override fun onResume(owner: LifecycleOwner) {
                    if (stale) {
                        stale = false
                        safely("reload") { reload() }
                    }
                }

                override fun onDestroy(owner: LifecycleOwner) {
                    fence.close()
                    safely("destroy") { onDestroyed() }
                }
            },
        )
    }

    /** The page for the current state. Pure reads of the screen's own fields. */
    protected abstract fun page(): PageSpec

    /** Fetches what this screen shows. Called on creation, on Retry and when a change reaches it. */
    protected abstract fun reload()

    /** Screen-specific intents. Return true when handled; the rest goes to [CarHost.perform]. */
    protected open fun handle(intent: CarIntent): Boolean = false

    protected open fun onDestroyed() {}

    protected open val searchSink: SearchSink? = null

    /** A change event (queue, modes, library or track) reached the session. */
    open fun onChange(what: String) {}

    /** ALBUM changed: redraw if this screen shows it. */
    open fun onAlbumColorChanged() {}

    final override fun onGetTemplate(): Template {
        return try {
            Render(host.style, host.api9, ::tap, searchSink).template(page())
        } catch (t: Throwable) {
            Log.e(TAG, "${javaClass.simpleName}: page failed: ${t.message}", t)
            fallbackTemplate()
        }
    }

    /** The designed retry state, for a page that could not be built. */
    private fun fallbackTemplate(): Template {
        val retry = MessagePage(
            CarStrings.COULDNT_LOAD,
            actions = listOf(ActionSpec(CarStrings.RETRY, CarIntent.Retry)),
        )
        return Render(host.style, host.api9, ::tap, null).template(retry)
    }

    /** Every tap on this screen's template. */
    protected fun tap(intent: CarIntent) {
        // A late tap on a screen that has since been covered or removed does nothing.
        if (!isTop()) return
        try {
            if (!handle(intent)) host.perform(intent)
        } catch (t: Throwable) {
            Log.e(TAG, "${javaClass.simpleName}: ${intent.javaClass.simpleName} failed: ${t.message}", t)
        }
    }

    protected fun isTop(): Boolean =
        !fence.isClosed && screenManager.top === this

    /** Redraws, if this screen is still alive. Safe at any time (a covered screen ignores it). */
    protected fun redraw() {
        if (fence.isClosed) return
        try {
            invalidate()
        } catch (t: Throwable) {
            Log.w(TAG, "${javaClass.simpleName}: invalidate failed: ${t.message}")
        }
    }

    /** Reloads now when this screen is on top, otherwise when it next resumes. */
    protected fun reloadWhenVisible() {
        if (fence.isClosed) return
        if (isTop() && lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            safely("reload") { reload() }
        } else {
            stale = true
        }
    }

    protected fun safely(what: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, "${javaClass.simpleName}: $what failed: ${t.message}", t)
        }
    }

    private companion object {
        const val TAG = "CarScreen"
    }
}
