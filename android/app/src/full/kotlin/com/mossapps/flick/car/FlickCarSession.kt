package com.mossapps.flick.car

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.Session
import androidx.car.app.media.MediaConstants
import androidx.car.app.media.MediaPlaybackManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.mossapps.flick.FlickSessionHub
import com.mossapps.flick.car.screens.CarHost
import com.mossapps.flick.car.screens.CollectionScreen
import com.mossapps.flick.car.screens.FlickScreen
import com.mossapps.flick.car.screens.PlayerScreen
import com.mossapps.flick.car.screens.QueueScreen
import com.mossapps.flick.car.screens.RootScreen
import com.mossapps.flick.car.screens.SearchScreen
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarPalette
import com.mossapps.flick.car.ui.CarStyle
import com.mossapps.flick.car.ui.CollectionTarget
import com.mossapps.flick.car.ui.ListKind

/**
 * One car session. It registers Flick's media session with the host (never before there is
 * one, and again whenever it changes), counts itself in [FlickSessionHub.carSessionCount] so
 * the app is not killed while a car is connected, fans change events out to the screens, and
 * owns the navigation and commands every screen shares.
 *
 * Started with SHOW_MEDIA_PLAYBACK it opens on the player above the root page, so Back works;
 * the same intent later pops to the player already on the stack, or pushes one.
 */
class FlickCarSession : Session(), CarHost {
    override val link: CarLink by lazy { CarLink.get(carContext) }
    override val style: CarStyle by lazy { CarStyle(carContext) }
    override val api9: Boolean by lazy { CarStyle.api9(carContext) }

    override val albumColor: Int
        get() = CarPalette.album(FlickSessionHub.albumColor)

    override var playerReady: Boolean = false
        private set

    override var playerStarting: Boolean = false
        private set

    private val main = Handler(Looper.getMainLooper())
    private var destroyed = false
    private var registeredToken: MediaSessionCompat.Token? = null
    private var lastAlbumColor: Int? = null
    private val clearStarting = Runnable { endStarting() }

    private val hubListener = FlickSessionHub.Listener { token, color -> onHubChanged(token, color) }
    private val changeListener = CarLink.ChangeListener { what -> onChange(what) }

    override fun onCreateScreen(intent: Intent): Screen {
        FlickSessionHub.carSessionCount += 1
        lastAlbumColor = FlickSessionHub.albumColor
        lifecycle.addObserver(
            object : DefaultLifecycleObserver {
                override fun onDestroy(owner: LifecycleOwner) {
                    destroyed = true
                    main.removeCallbacks(clearStarting)
                    FlickSessionHub.removeListener(hubListener)
                    link.removeChangeListener(changeListener)
                    FlickSessionHub.carSessionCount -= 1
                }
            },
        )
        FlickSessionHub.addListener(hubListener)
        link.addChangeListener(changeListener)
        register(FlickSessionHub.token)

        val screens = carContext.getCarService(ScreenManager::class.java)
        val root = RootScreen(carContext, this)
        if (intent.action == MediaConstants.ACTION_SHOW_MEDIA_PLAYBACK) {
            // Back from the player must lead somewhere: the root goes underneath it.
            screens.push(root)
            return PlayerScreen(carContext, this)
        }
        return root
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action == MediaConstants.ACTION_SHOW_MEDIA_PLAYBACK) showPlayer()
    }

    // ------------------------------------------------------------ media session

    /**
     * Registers the token with the host. A MediaPlaybackTemplate is only ever sent once this
     * has succeeded ([playerReady]); until then the player shows a message.
     */
    private fun register(token: MediaSessionCompat.Token?) {
        registeredToken = token
        if (token == null) {
            playerReady = false
            return
        }
        playerReady = try {
            carContext.getCarService(MediaPlaybackManager::class.java).registerMediaPlaybackToken(token)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "registerMediaPlaybackToken failed: ${t.message}", t)
            false
        }
        if (playerReady) endStarting()
    }

    private fun onHubChanged(token: MediaSessionCompat.Token?, color: Int?) {
        if (destroyed) return
        if (token != registeredToken) {
            register(token)
            (topScreen() as? PlayerScreen)?.let { redraw(it) }
        }
        if (color != lastAlbumColor) {
            lastAlbumColor = color
            // Only the screen that is showing it redraws, at most once per track.
            (topScreen() as? FlickScreen)?.onAlbumColorChanged()
        }
    }

    private fun onChange(what: String) {
        if (destroyed) return
        val screens = carContext.getCarService(ScreenManager::class.java)
        for (screen in screens.screenStack) (screen as? FlickScreen)?.onChange(what)
    }

    // ------------------------------------------------------------- navigation

    override fun perform(intent: CarIntent) {
        if (destroyed) return
        when (intent) {
            is CarIntent.OpenList ->
                push(CollectionScreen(carContext, this, CollectionTarget.Listing(intent.kind, titleOf(intent.kind))))
            is CarIntent.OpenCollection ->
                push(CollectionScreen(carContext, this, CollectionTarget.Content(intent.kind, intent.id, intent.title)))
            is CarIntent.Play -> play(intent)
            is CarIntent.Enqueue -> enqueue(intent)
            CarIntent.Resume -> {
                beginStarting()
                showPlayer()
                link.resume { result -> result.onFailure { playFailed(it) } }
            }
            CarIntent.OpenSearch -> if (topScreen() !is SearchScreen) push(SearchScreen(carContext, this))
            CarIntent.OpenUpNext -> if (topScreen() !is QueueScreen) push(QueueScreen(carContext, this))
            CarIntent.Browse -> popToRoot()
            // The screen that owns them handles these; none left means the screen was gone.
            is CarIntent.SelectTab, CarIntent.Retry, CarIntent.ToggleShuffle, CarIntent.CycleLoop,
            CarIntent.ClearQueue, is CarIntent.Jump -> Unit
        }
    }

    private fun push(screen: Screen) {
        CarNav.push(carContext.getCarService(ScreenManager::class.java), screen)
    }

    private fun popToRoot() {
        val screens = carContext.getCarService(ScreenManager::class.java)
        if (screens.stackSize > 1) screens.popToRoot()
    }

    override fun showPlayer() {
        if (destroyed) return
        val screens = carContext.getCarService(ScreenManager::class.java)
        if (screens.top is PlayerScreen) return
        if (screens.screenStack.any { it is PlayerScreen }) {
            screens.popTo(PlayerScreen.MARKER)
            return
        }
        push(PlayerScreen(carContext, this))
    }

    /** Invalidating a screen that is not started is a no-op; this only guards against the host. */
    private fun redraw(screen: Screen) {
        try {
            screen.invalidate()
        } catch (t: Throwable) {
            Log.w(TAG, "invalidate failed: ${t.message}")
        }
    }

    private fun topScreen(): Screen? = try {
        carContext.getCarService(ScreenManager::class.java).top
    } catch (t: IllegalStateException) {
        // The first screen has not been created yet.
        null
    }

    private fun titleOf(kind: ListKind): String = when (kind) {
        ListKind.ALBUMS -> CarStrings.ALBUMS
        ListKind.ARTISTS -> CarStrings.ARTISTS
        ListKind.PLAYLISTS -> CarStrings.PLAYLISTS
        ListKind.FOLDERS -> CarStrings.FOLDERS
        ListKind.RECENTLY_ADDED -> CarStrings.RECENTLY_ADDED
    }

    // --------------------------------------------------------------- commands

    private fun play(intent: CarIntent.Play) {
        beginStarting()
        showPlayer()
        link.play(intent.kind, intent.id, intent.trackId, intent.shuffle) { result ->
            result.onFailure { playFailed(it) }
        }
    }

    private fun enqueue(intent: CarIntent.Enqueue) {
        link.enqueue(intent.kind, intent.id) { result ->
            result.onSuccess { toast(CarStrings.ADDED_TO_UP_NEXT) }
                .onFailure {
                    Log.w(TAG, "enqueue failed: ${it.message}")
                    toast(CarStrings.COULDNT_LOAD)
                }
        }
    }

    private fun playFailed(failure: Throwable) {
        Log.w(TAG, "play failed: ${failure.message}")
        if (destroyed) return
        endStarting()
        toast(CarStrings.COULDNT_PLAY)
        // Nothing started: do not leave the driver on an empty player.
        val screens = carContext.getCarService(ScreenManager::class.java)
        if (screens.top is PlayerScreen && !playerReady && screens.stackSize > 1) screens.pop()
    }

    /** The session may appear a moment after a play command; say so instead of "Nothing playing". */
    private fun beginStarting() {
        if (playerReady) return
        playerStarting = true
        main.removeCallbacks(clearStarting)
        main.postDelayed(clearStarting, STARTING_MS)
    }

    private fun endStarting() {
        if (!playerStarting) return
        playerStarting = false
        main.removeCallbacks(clearStarting)
        (topScreen() as? PlayerScreen)?.let { redraw(it) }
    }

    override fun toast(text: String) {
        try {
            CarToast.makeText(carContext, text, CarToast.LENGTH_SHORT).show()
        } catch (t: Throwable) {
            Log.w(TAG, "toast failed: ${t.message}")
        }
    }

    private companion object {
        const val TAG = "FlickCar"
        const val STARTING_MS = 10_000L
    }
}
