package com.mossapps.flick

import android.content.Context
import android.content.IntentFilter
import android.util.Log
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteDescriptor
import androidx.mediarouter.media.MediaRouteProvider
import androidx.mediarouter.media.MediaRouteProviderDescriptor
import androidx.mediarouter.media.MediaRouteProviderService
import androidx.mediarouter.media.MediaRouter

// ponytail: publishes DLNA renderers as MediaRouter remote-playback routes so
// the system (volume panel, output switcher) treats them as real outputs.
// Dart pushes discovery results in; selection/volume flow back out through
// DlnaRouteRegistry callbacks (wired to cast_events by MainActivity).

object DlnaRouteRegistry {
    data class Route(val id: String, val name: String)

    private val providers = mutableListOf<DlnaRouteProvider>()
    private val volumes = mutableMapOf<String, Int>()

    @Volatile
    var routes: List<Route> = emptyList()
        private set

    @Volatile
    var selectedId: String? = null

    // Wired by MainActivity; must be safe to call from any thread.
    @Volatile var onRouteSelected: ((String) -> Unit)? = null
    @Volatile var onRouteUnselected: ((String) -> Unit)? = null
    @Volatile var onVolumeSet: ((String, Int) -> Unit)? = null

    fun register(provider: DlnaRouteProvider) {
        synchronized(providers) { providers.add(provider) }
    }

    fun publish(newRoutes: List<Route>) {
        routes = newRoutes
        refreshAll()
    }

    fun setVolume(id: String, volume: Int) {
        synchronized(volumes) { volumes[id] = volume.coerceIn(0, 100) }
        refreshAll()
    }

    fun volumeOf(id: String): Int = synchronized(volumes) { volumes[id] } ?: 40

    private fun refreshAll() {
        val snapshot = synchronized(providers) { providers.toList() }
        for (p in snapshot) {
            try {
                p.refresh()
            } catch (e: Exception) {
                Log.w("DlnaRoute", "provider refresh failed: ${e.message}")
            }
        }
    }
}

class DlnaRouteProvider(context: Context) : MediaRouteProvider(context) {

    init {
        DlnaRouteRegistry.register(this)
        refresh()
    }

    fun refresh() {
        val builder = MediaRouteProviderDescriptor.Builder()
        for (r in DlnaRouteRegistry.routes) {
            val descriptor = MediaRouteDescriptor.Builder(r.id, r.name)
                .setDescription("DLNA Media Renderer")
                .setPlaybackType(MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE)
                .setVolumeHandling(MediaRouter.RouteInfo.PLAYBACK_VOLUME_VARIABLE)
                .setVolumeMax(100)
                .setVolume(DlnaRouteRegistry.volumeOf(r.id))
                .setCanDisconnect(true)
                .setEnabled(true)
            for (f in controlFilters) descriptor.addControlFilter(f)
            builder.addRoute(descriptor.build())
        }
        setDescriptor(builder.build())
    }

    override fun onCreateRouteController(routeId: String): RouteController? {
        return object : RouteController() {
            override fun onSelect() {
                DlnaRouteRegistry.selectedId = routeId
                DlnaRouteRegistry.onRouteSelected?.invoke(routeId)
            }

            override fun onUnselect() {
                if (DlnaRouteRegistry.selectedId == routeId) {
                    DlnaRouteRegistry.selectedId = null
                }
                DlnaRouteRegistry.onRouteUnselected?.invoke(routeId)
            }

            override fun onSetVolume(volume: Int) {
                DlnaRouteRegistry.setVolume(routeId, volume)
                DlnaRouteRegistry.onVolumeSet?.invoke(routeId, volume)
            }

            override fun onUpdateVolume(delta: Int) {
                val next = DlnaRouteRegistry.volumeOf(routeId) + delta
                onSetVolume(next.coerceIn(0, 100))
            }
        }
    }

    companion object {
        private val controlFilters = listOf(
            IntentFilter().apply {
                addCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
            }
        )
    }
}

// Declared in the manifest so other apps / system UI can also discover the
// routes; our own process registers the provider directly via addProvider.
class DlnaRouteProviderService : MediaRouteProviderService() {
    override fun onCreateMediaRouteProvider(): MediaRouteProvider {
        return DlnaRouteProvider(this)
    }
}
