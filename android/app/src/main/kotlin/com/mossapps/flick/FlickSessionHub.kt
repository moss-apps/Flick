package com.mossapps.flick

import android.os.Handler
import android.os.Looper
import android.support.v4.media.session.MediaSessionCompat
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Publishes what the car needs from MusicNotificationService, which keeps owning
 * the MediaSession: the current session token and the current album colour (the
 * notification colour). A listener is not called on registration; read [token]
 * and [albumColor] when adding it.
 */
object FlickSessionHub {
    fun interface Listener {
        /** Main thread. Called when either value changed. */
        fun onChanged(token: MediaSessionCompat.Token?, albumColor: Int?)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArrayList<Listener>()

    @Volatile
    var token: MediaSessionCompat.Token? = null
        private set

    @Volatile
    var albumColor: Int? = null
        private set

    /** The car module increments this when a car session starts and decrements it when it ends. */
    @Volatile
    var carSessionCount: Int = 0
        set(value) {
            field = value.coerceAtLeast(0)
        }

    fun addListener(listener: Listener) {
        listeners.addIfAbsent(listener)
    }

    fun removeListener(listener: Listener) {
        listeners.remove(listener)
    }

    fun setToken(value: MediaSessionCompat.Token?) {
        if (token == value) return
        token = value
        notifyListeners()
    }

    fun setAlbumColor(value: Int?) {
        if (albumColor == value) return
        albumColor = value
        notifyListeners()
    }

    private fun notifyListeners() {
        if (Looper.myLooper() === Looper.getMainLooper()) {
            dispatch()
        } else {
            mainHandler.post { dispatch() }
        }
    }

    private fun dispatch() {
        val currentToken = token
        val currentColor = albumColor
        for (listener in listeners) {
            try {
                listener.onChanged(currentToken, currentColor)
            } catch (t: Throwable) {
                android.util.Log.w("FlickSessionHub", "listener failed: ${t.message}", t)
            }
        }
    }
}
