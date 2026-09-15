package com.mossapps.flick

import android.content.Context
import android.util.Log
import android.os.Handler
import android.os.Looper
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient

// ponytail: Cast driven via MediaRouter route selection + CastContext session.
// Discovery = MediaRouter routes supporting remote playback; connect = selectRoute
// (CastContext creates the session); control = RemoteMediaClient on the session.
// All interesting native state (session lifecycle, playback status, volume,
// route changes) is forwarded to Dart via onEvent → cast_events channel.
class CastController(private val context: Context) {
    private val mediaRouter: MediaRouter by lazy { MediaRouter.getInstance(context) }
    // ponytail: Cast SDK needs Google Play Services; null out on GMS-free
    // devices (GrapheneOS etc.) so the app runs without Cast instead of
    // crashing on launch. MediaRouter output routing still works without GMS.
    private val castContext: CastContext? by lazy {
        try {
            CastContext.getSharedInstance(context)
        } catch (e: Throwable) {
            Log.w("CastController", "Cast SDK unavailable (no Google Play Services): ${e.message}")
            null
        }
    }
    private val handler = Handler(Looper.getMainLooper())

    /** Called on the main thread for every cast event destined for Dart. */
    var onEvent: ((Map<String, Any?>) -> Unit)? = null

    private var connectedSession: CastSession? = null
    private var mediaClientCallback: RemoteMediaClient.Callback? = null
    private var attachedClient: RemoteMediaClient? = null
    private var lastVolume: Double? = null
    private var statusTicker: Runnable? = null

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) {
            connectedSession = session
            emit(mapOf("event" to "sessionStarted"))
            attachMediaClientListener(session)
        }
        override fun onSessionEnded(session: CastSession, error: Int) {
            connectedSession = null
            detachMediaClientListener()
            emit(mapOf("event" to "sessionEnded"))
        }
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
            connectedSession = session
            emit(mapOf("event" to "sessionResumed"))
            attachMediaClientListener(session)
        }
        override fun onSessionStarting(p0: CastSession) {}
        override fun onSessionStartFailed(p0: CastSession, p1: Int) {}
        override fun onSessionEnding(p0: CastSession) {}
        override fun onSessionResuming(p0: CastSession, p1: String) {}
        override fun onSessionResumeFailed(p0: CastSession, p1: Int) {}
        override fun onSessionSuspended(p0: CastSession, p1: Int) {}
    }

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo) {
            if (route.playbackType == MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE) {
                emit(
                    mapOf(
                        "event" to "routeSelected",
                        "id" to route.id.toString(),
                        "name" to (route.name?.toString() ?: ""),
                    )
                )
            }
        }
        override fun onRouteUnselected(router: MediaRouter, route: MediaRouter.RouteInfo) {
            if (route.playbackType == MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE) {
                emit(
                    mapOf(
                        "event" to "routeUnselected",
                        "id" to route.id.toString(),
                        "name" to (route.name?.toString() ?: ""),
                    )
                )
            }
        }
        override fun onRouteVolumeChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
            if (route.playbackType == MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE && route.volumeMax > 0) {
                emit(
                    mapOf(
                        "event" to "volume",
                        "volume" to route.volume.toDouble() / route.volumeMax.toDouble(),
                    )
                )
            }
        }
    }

    private val routeSelector: MediaRouteSelector = MediaRouteSelector.Builder()
        .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
        .build()

    fun start() {
        castContext?.sessionManager?.addSessionManagerListener(sessionListener, CastSession::class.java)
        mediaRouter.addCallback(routeSelector, routerCallback, MediaRouter.CALLBACK_FLAG_UNFILTERED_EVENTS)
    }

    private fun emit(event: Map<String, Any?>) {
        val sink = onEvent ?: return
        handler.post { sink(event) }
    }

    private fun attachMediaClientListener(session: CastSession) {
        val client = session.remoteMediaClient ?: return
        detachMediaClientListener()
        attachedClient = client
        val callback = object : RemoteMediaClient.Callback() {
            override fun onStatusUpdated() {
                emitStatus(client)
                emitVolumeIfChanged()
            }
        }
        mediaClientCallback = callback
        client.registerCallback(callback)
        startStatusTicker(client)
    }

    private fun detachMediaClientListener() {
        stopStatusTicker()
        val cb = mediaClientCallback
        if (cb != null) attachedClient?.unregisterCallback(cb)
        mediaClientCallback = null
        attachedClient = null
        lastVolume = null
    }

    // ponytail: RemoteMediaClient only pushes on status boundaries; a 1s tick
    // keeps the Dart-side position slider moving between them, mirroring the
    // DLNA polling path.
    private fun startStatusTicker(client: RemoteMediaClient) {
        stopStatusTicker()
        val tick = object : Runnable {
            override fun run() {
                if (connectedSession == null) return
                if (client.isPlaying) emitStatus(client)
                emitVolumeIfChanged()
                handler.postDelayed(this, 1000L)
            }
        }
        statusTicker = tick
        handler.postDelayed(tick, 1000L)
    }

    private fun stopStatusTicker() {
        statusTicker?.let { handler.removeCallbacks(it) }
        statusTicker = null
    }

    private fun emitStatus(client: RemoteMediaClient) {
        emit(
            mapOf(
                "event" to "status",
                "position" to client.approximateStreamPosition,
                "duration" to client.streamDuration,
                "playing" to client.isPlaying,
            )
        )
    }

    fun discover(): List<Map<String, Any>> {
        // ponytail: MediaRouter exposes no selector-filtered getRoutes(); pull all
        // and keep remote-playback routes (Cast devices surface here).
        val routes = mediaRouter.routes
        val out = mutableListOf<Map<String, Any>>()
        for (r in routes) {
            if (r.isDefault) continue
            if (r.playbackType != MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE) continue
            out.add(
                mapOf(
                    "id" to (r.id.toString()),
                    "name" to (r.name?.toString() ?: "Chromecast"),
                )
            )
        }
        return out
    }

    fun connect(deviceId: String) {
        val routes = mediaRouter.routes
        val target = routes.firstOrNull { it.id.toString() == deviceId } ?: return
        mediaRouter.selectRoute(target)
    }

    fun disconnect() {
        val sessionManager = castContext?.sessionManager
        if (sessionManager?.currentCastSession != null) {
            sessionManager.endCurrentSession(true)
        }
        connectedSession = null
        detachMediaClientListener()
    }

    private fun client(): RemoteMediaClient? {
        val sessionManager = castContext?.sessionManager ?: return null
        return connectedSession?.remoteMediaClient ?: sessionManager.currentCastSession?.remoteMediaClient
    }

    fun load(url: String, title: String?, artist: String?) {
        val meta = MediaMetadata(MediaMetadata.MEDIA_TYPE_MUSIC_TRACK)
        if (title != null) meta.putString(MediaMetadata.KEY_TITLE, title)
        if (artist != null) meta.putString(MediaMetadata.KEY_ARTIST, artist)
        val info = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType("audio/*")
            .setMetadata(meta)
            .build()
        client()?.load(info)
    }

    fun play() {
        client()?.play()
    }

    fun pause() {
        client()?.pause()
    }

    fun stop() {
        client()?.stop()
    }

    fun seek(positionMs: Long) {
        client()?.seek(positionMs)
    }

    fun setVolume(volume: Double) {
        client()?.setStreamVolume(volume)
    }

    // ponytail: RemoteMediaClient.Callback has no volume hook; diff the
    // session volume on every status tick instead. MediaRouter's
    // onRouteVolumeChanged covers external changes.
    private fun emitVolumeIfChanged() {
        val v = currentVolume() ?: return
        if (v != lastVolume) {
            lastVolume = v
            emit(mapOf("event" to "volume", "volume" to v))
        }
    }

    private fun currentVolume(): Double? {
        return try {
            (connectedSession ?: castContext?.sessionManager?.currentCastSession)?.volume
        } catch (_: Exception) {
            null
        }
    }

    fun getVolume(): Double? = currentVolume()

    // ponytail: local audio output route selection via MediaRouter.
    // Covers Speaker / Wired / Bluetooth / USB — complements the USB DAC & BT
    // settings already in the app. System routes are included here intentionally.
    fun getOutputRoutes(): List<Map<String, Any>> {
        val routes = mediaRouter.routes
        val out = mutableListOf<Map<String, Any>>()
        for (r in routes) {
            if (r.isDefault) continue
            out.add(
                mapOf(
                    "id" to r.id.toString(),
                    "name" to (r.name?.toString() ?: "Output"),
                    "type" to outputTypeLabel(r),
                    "selected" to r.isSelected,
                )
            )
        }
        return out
    }

    fun selectOutputRoute(deviceId: String): Boolean {
        val target = mediaRouter.routes.firstOrNull { it.id.toString() == deviceId } ?: return false
        mediaRouter.selectRoute(target)
        return true
    }

    private fun outputTypeLabel(r: MediaRouter.RouteInfo): String {
        return when (r.deviceType) {
            MediaRouter.RouteInfo.DEVICE_TYPE_SPEAKER -> "Speaker"
            MediaRouter.RouteInfo.DEVICE_TYPE_BLUETOOTH -> "Bluetooth"
            MediaRouter.RouteInfo.DEVICE_TYPE_TV -> "TV / Receiver"
            MediaRouter.RouteInfo.DEVICE_TYPE_GROUP -> "Group"
            else -> "Other"
        }
    }
}
