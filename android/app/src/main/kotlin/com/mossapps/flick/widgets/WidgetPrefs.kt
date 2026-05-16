package com.mossapps.flick.widgets

import android.content.Context
import android.content.SharedPreferences

/**
 * Centralised access to the SharedPreferences file used by the `home_widget`
 * Flutter plugin. The plugin stores data under the `HomeWidgetPreferences`
 * preferences file on Android by default. All widget keys here must match the
 * ones written by `WidgetSyncService` on the Dart side.
 */
internal object WidgetPrefs {
    private const val PREFS_NAME = "HomeWidgetPreferences"

    const val KEY_SONG_ID = "flick_widget_song_id"
    const val KEY_TITLE = "flick_widget_title"
    const val KEY_ARTIST = "flick_widget_artist"
    const val KEY_ALBUM_ART = "flick_widget_album_art"
    const val KEY_IS_PLAYING = "flick_widget_is_playing"
    const val KEY_HAS_SONG = "flick_widget_has_song"
    const val KEY_QUEUE_JSON = "flick_widget_queue_json"
    const val KEY_CURRENT_INDEX = "flick_widget_current_index"

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}

/** A single decoded queue entry. */
internal data class QueueEntry(
    val id: String,
    val title: String,
    val artist: String,
    val albumArtPath: String,
)

/** Decodes the compact CSV-like queue blob produced by `WidgetSyncService`. */
internal fun decodeQueue(raw: String?): List<QueueEntry> {
    if (raw.isNullOrEmpty()) return emptyList()
    return raw.split('\n').mapNotNull { line ->
        if (line.isEmpty()) return@mapNotNull null
        val parts = line.split('\u0001')
        QueueEntry(
            id = parts.getOrElse(0) { "" },
            title = parts.getOrElse(1) { "" },
            artist = parts.getOrElse(2) { "" },
            albumArtPath = parts.getOrElse(3) { "" },
        )
    }
}
