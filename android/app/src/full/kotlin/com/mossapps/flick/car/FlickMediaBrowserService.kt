package com.mossapps.flick.car

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import androidx.media.MediaBrowserServiceCompat
import com.mossapps.flick.CarArtProvider
import com.mossapps.flick.FlickSessionHub
import com.mossapps.flick.car.ui.ListKind

/**
 * The classic browse tree for hosts that cannot show templates (docs/ANDROID_AUTO_DESIGN.md, 3).
 * It answers from the same [CarLink] calls as the templated UI, so browsing works with the app
 * closed (the engine starts on demand; a cold start is retried for a few seconds). The playback
 * itself is Flick's own media session, whose token this service adopts once it exists.
 *
 * Any caller may browse: there is no allowlist, and nothing a caller sends is trusted. Media ids
 * are parsed by the session, never executed.
 */
class FlickMediaBrowserService : MediaBrowserServiceCompat() {
    private val main = Handler(Looper.getMainLooper())
    private val link: CarLink by lazy { CarLink.get(applicationContext) }
    private var destroyed = false
    private var tokenAdopted = false

    private val hubListener = FlickSessionHub.Listener { token, _ -> adopt(token) }

    override fun onCreate() {
        super.onCreate()
        FlickSessionHub.addListener(hubListener)
        // The service can be created before any playback: the token comes later.
        adopt(FlickSessionHub.token)
    }

    override fun onDestroy() {
        destroyed = true
        FlickSessionHub.removeListener(hubListener)
        super.onDestroy()
    }

    /** `setSessionToken` is allowed once; take the first token the hub has. */
    private fun adopt(token: MediaSessionCompat.Token?) {
        if (token == null || tokenAdopted || destroyed) return
        try {
            setSessionToken(token)
            tokenAdopted = true
        } catch (t: IllegalStateException) {
            Log.w(TAG, "session token already set: ${t.message}")
            tokenAdopted = true
        }
    }

    override fun onGetRoot(clientPackageName: String, clientUid: Int, rootHints: Bundle?): BrowserRoot =
        BrowserRoot(ClassicTree.ROOT_ID, Bundle().apply { putBoolean(SEARCH_SUPPORTED, true) })

    override fun onLoadChildren(parentId: String, result: Result<MutableList<MediaBrowserCompat.MediaItem>>) {
        load(parentId, result, null)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<MutableList<MediaBrowserCompat.MediaItem>>,
        options: Bundle,
    ) {
        load(parentId, result, options)
    }

    override fun onSearch(query: String, extras: Bundle?, result: Result<MutableList<MediaBrowserCompat.MediaItem>>) {
        result.detach()
        val reply = Reply(result)
        val window = windowOf(extras)
        val trimmed = query.trim()
        if (trimmed.isEmpty()) {
            reply.send(emptyList())
            return
        }
        retrying(SystemClock.elapsedRealtime(), { done -> link.search(trimmed, callback = done) }) { outcome ->
            outcome.onSuccess { reply.send(ClassicTree.search(it, trimmed, window)) }
                .onFailure { reply.fail(it) }
        }
    }

    private fun load(parentId: String, result: Result<MutableList<MediaBrowserCompat.MediaItem>>, options: Bundle?) {
        result.detach()
        val reply = Reply(result)
        val window = windowOf(options)
        val startedAt = SystemClock.elapsedRealtime()
        when (val parent = ClassicTree.parent(parentId)) {
            null -> reply.send(emptyList())
            ClassicTree.Parent.Root -> reply.send(ClassicTree.root(window))
            is ClassicTree.Parent.Listing -> retrying(
                startedAt,
                { done -> link.list(parent.kind, window.limit, callback = done) },
            ) { outcome ->
                outcome.onSuccess { reply.send(ClassicTree.listing(it, window)) }.onFailure { reply.fail(it) }
            }
            is ClassicTree.Parent.Content -> retrying(
                startedAt,
                { done -> link.collection(parent.kind, parent.id, window.limit, callback = done) },
            ) { outcome ->
                outcome.onSuccess { reply.send(ClassicTree.tracks(it, parent.kind, parent.id, window)) }
                    .onFailure { reply.fail(it) }
            }
        }
    }

    private fun windowOf(extras: Bundle?): ClassicTree.Window {
        val page = extras?.getInt(MediaBrowserCompat.EXTRA_PAGE, -1)
        val size = extras?.getInt(MediaBrowserCompat.EXTRA_PAGE_SIZE, -1)
        return ClassicTree.window(page, size)
    }

    /**
     * Runs [request]; while the phone side of Flick is still starting (a cold start with the
     * app closed) asks again every 700 ms for up to 12 s, so the host gets the answer, not an
     * empty folder.
     */
    private fun <T> retrying(
        startedAt: Long,
        request: ((kotlin.Result<T>) -> Unit) -> Unit,
        done: (kotlin.Result<T>) -> Unit,
    ) {
        request { outcome ->
            val failure = outcome.exceptionOrNull()
            val elapsed = SystemClock.elapsedRealtime() - startedAt
            if (failure != null && !destroyed && EngineGate.isStarting(failure) && !EngineGate.gaveUp(elapsed)) {
                main.postDelayed(
                    { if (!destroyed) retrying(startedAt, request, done) },
                    EngineGate.POLL_INTERVAL_MS,
                )
            } else {
                done(outcome)
            }
        }
    }

    /** Sends the answer to the host exactly once. */
    private inner class Reply(private val result: Result<MutableList<MediaBrowserCompat.MediaItem>>) {
        private var sent = false

        fun send(nodes: List<ClassicNode>) {
            if (sent || destroyed) return
            sent = true
            try {
                result.sendResult(nodes.mapTo(mutableListOf()) { item(it) })
            } catch (t: Throwable) {
                Log.w(TAG, "sendResult failed: ${t.message}")
            }
        }

        fun fail(failure: Throwable) {
            Log.w(TAG, "browse failed: ${failure.message}")
            send(emptyList())
        }
    }

    private fun item(node: ClassicNode): MediaBrowserCompat.MediaItem {
        val description = MediaDescriptionCompat.Builder()
            .setMediaId(node.mediaId)
            .setTitle(node.title)
            .setSubtitle(node.subtitle)
            .setIconUri(CarArtProvider.uriFor(this, node.art))
            .build()
        var flags = 0
        if (node.browsable) flags = flags or MediaBrowserCompat.MediaItem.FLAG_BROWSABLE
        if (node.playable) flags = flags or MediaBrowserCompat.MediaItem.FLAG_PLAYABLE
        return MediaBrowserCompat.MediaItem(description, flags)
    }

    private companion object {
        const val TAG = "FlickBrowser"
        const val SEARCH_SUPPORTED = "android.media.browse.SEARCH_SUPPORTED"
    }
}
