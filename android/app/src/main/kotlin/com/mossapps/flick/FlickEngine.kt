package com.mossapps.flick

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.lang.ref.WeakReference

/**
 * The one place a Flutter engine is created. The activity and the car both come
 * here, so there is exactly one engine (cached as [ENGINE_ID]) and one plugin
 * registration path, whether or not an activity exists.
 *
 * Only handlers that need a [Context] and no activity live here. Everything
 * that needs the activity stays in MainActivity.configureFlutterEngine and has
 * no handler until the user opens the app.
 *
 * Main thread only.
 */
object FlickEngine {
    const val ENGINE_ID = "main_engine"
    private const val PLAYER_CHANNEL = "com.mossapps.flick/player"

    private val lock = Any()
    private var preparedEngine: WeakReference<FlutterEngine>? = null

    /** The cached engine, created, prepared and started on first use. */
    fun ensure(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { cached ->
            prepare(context, cached)
            return cached
        }
        val engine = FlutterEngine(context.applicationContext)
        try {
            prepare(context, engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        } catch (t: Throwable) {
            engine.destroy()
            throw t
        }
        cache.put(ENGINE_ID, engine)
        return engine
    }

    /**
     * Plugins and the context-only channel handlers. Idempotent per engine
     * identity: calling it again for the same engine does nothing.
     */
    fun prepare(context: Context, engine: FlutterEngine) {
        synchronized(lock) {
            if (preparedEngine?.get() === engine) {
                return
            }

            GeneratedPluginRegistrant.registerWith(engine)
            engine.plugins.add(FlickVisualizerPlugin())
            registerPlayerChannel(context.applicationContext, engine)
            CarChannel.attach(engine)
            preparedEngine = WeakReference(engine)
        }
    }

    // Player channel for notification control. It only starts and stops
    // MusicNotificationService.
    private fun registerPlayerChannel(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, PLAYER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val albumArtPath = call.argument<String>("albumArtPath")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    // Handle both Integer and Long types from Flutter
                    val duration = when (val d = call.argument<Any>("duration")) {
                        is Long -> d
                        is Int -> d.toLong()
                        else -> 0L
                    }
                    val position = when (val p = call.argument<Any>("position")) {
                        is Long -> p
                        is Int -> p.toLong()
                        else -> 0L
                    }
                    val isShuffle = call.argument<Boolean>("isShuffle") ?: false
                    val isFavorite = call.argument<Boolean>("isFavorite") ?: false
                    val color = call.argument<Any>("color")?.let { c ->
                        when (c) {
                            is Int -> c
                            is Long -> c.toInt()
                            else -> null
                        }
                    }
                    val isCasting = call.argument<Boolean>("isCasting") ?: false
                    val castDeviceName = call.argument<String>("castDeviceName")
                    val castVolume = call.argument<Int>("castVolume")
                    val loopMode = call.argument<String>("loopMode")
                    val album = call.argument<String>("album")
                    val mediaId = call.argument<String>("mediaId")

                    val intent = Intent(context, MusicNotificationService::class.java).apply {
                        putExtra("title", title)
                        putExtra("artist", artist)
                        putExtra("albumArtPath", albumArtPath)
                        putExtra("isPlaying", isPlaying)
                        putExtra("duration", duration)
                        putExtra("position", position)
                        putExtra("isShuffle", isShuffle)
                        putExtra("isFavorite", isFavorite)
                        putExtra("isCasting", isCasting)
                        castDeviceName?.let { putExtra("castDeviceName", it) }
                        castVolume?.let { putExtra("castVolume", it) }
                        color?.let { putExtra("color", it) }
                        loopMode?.let { putExtra("loopMode", it) }
                        album?.let { putExtra("album", it) }
                        mediaId?.let { putExtra("mediaId", it) }
                    }

                    ContextCompat.startForegroundService(context, intent)
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val albumArtPath = call.argument<String>("albumArtPath")
                    val isPlaying = call.argument<Boolean>("isPlaying")
                    // Handle both Integer and Long types from Flutter
                    val duration = call.argument<Any>("duration")?.let { d ->
                        when (d) {
                            is Long -> d
                            is Int -> d.toLong()
                            else -> null
                        }
                    }
                    val position = call.argument<Any>("position")?.let { p ->
                        when (p) {
                            is Long -> p
                            is Int -> p.toLong()
                            else -> null
                        }
                    }
                    val isShuffle = call.argument<Boolean>("isShuffle")
                    val isFavorite = call.argument<Boolean>("isFavorite")
                    val color = call.argument<Any>("color")?.let { c ->
                        when (c) {
                            is Int -> c
                            is Long -> c.toInt()
                            else -> null
                        }
                    }
                    val isCasting = call.argument<Boolean>("isCasting")
                    val castDeviceName = call.argument<String>("castDeviceName")
                    val castVolume = call.argument<Int>("castVolume")
                    val loopMode = call.argument<String>("loopMode")
                    val album = call.argument<String>("album")
                    val mediaId = call.argument<String>("mediaId")

                    val intent = Intent(context, MusicNotificationService::class.java).apply {
                        title?.let { putExtra("title", it) }
                        artist?.let { putExtra("artist", it) }
                        // A partial update (play/pause, position, cast) carries no
                        // art key; only an explicit key, null included, may clear it.
                        if (call.hasArgument("albumArtPath")) putExtra("albumArtPath", albumArtPath)
                        isPlaying?.let { putExtra("isPlaying", it) }
                        duration?.let { putExtra("duration", it) }
                        position?.let { putExtra("position", it) }
                        isShuffle?.let { putExtra("isShuffle", it) }
                        isFavorite?.let { putExtra("isFavorite", it) }
                        isCasting?.let { putExtra("isCasting", it) }
                        castDeviceName?.let { putExtra("castDeviceName", it) }
                        castVolume?.let { putExtra("castVolume", it) }
                        color?.let { putExtra("color", it) }
                        loopMode?.let { putExtra("loopMode", it) }
                        album?.let { putExtra("album", it) }
                        mediaId?.let { putExtra("mediaId", it) }
                    }
                    ContextCompat.startForegroundService(context, intent)
                    result.success(null)
                }
                "hideNotification" -> {
                    context.stopService(Intent(context, MusicNotificationService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
