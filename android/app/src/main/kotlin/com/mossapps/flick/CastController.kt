package com.mossapps.flick

import android.content.Context
import android.util.Log
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import java.util.concurrent.TimeUnit

// ponytail: Cast driven via MediaRouter route selection + CastContext session.
// Discovery = MediaRouter routes supporting remote playback; connect = selectRoute
// (CastContext creates the session); control = RemoteMediaClient on the session.
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
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    private var eventSink: android.os.Handler? = null
    private var connectedSession: CastSession? = null

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) {
            connectedSession = session
        }
        override fun onSessionEnded(session: CastSession, error: Int) {
            connectedSession = null
        }
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
            connectedSession = session
        }
        override fun onSessionStarting(p0: CastSession) {}
        override fun onSessionStartFailed(p0: CastSession, p1: Int) {}
        override fun onSessionEnding(p0: CastSession) {}
        override fun onSessionResuming(p0: CastSession, p1: String) {}
        override fun onSessionResumeFailed(p0: CastSession, p1: Int) {}
        override fun onSessionSuspended(p0: CastSession, p1: Int) {}
    }

    fun start() {
        castContext?.sessionManager?.addSessionManagerListener(sessionListener, CastSession::class.java)
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
