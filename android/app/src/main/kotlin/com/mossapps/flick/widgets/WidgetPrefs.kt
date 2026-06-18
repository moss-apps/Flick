package com.mossapps.flick.widgets

import android.content.Context
import android.content.SharedPreferences
import com.mossapps.flick.R

internal object WidgetPrefs {
    private const val PREFS_NAME = "HomeWidgetPreferences"

    const val KEY_SONG_ID = "flick_widget_song_id"
    const val KEY_TITLE = "flick_widget_title"
    const val KEY_ARTIST = "flick_widget_artist"
    const val KEY_ALBUM_ART = "flick_widget_album_art"
    const val KEY_IS_PLAYING = "flick_widget_is_playing"
    const val KEY_HAS_SONG = "flick_widget_has_song"
    const val KEY_IS_SHUFFLE = "flick_widget_is_shuffle"
    const val KEY_LOOP_MODE = "flick_widget_loop_mode"

    const val KEY_BG_OPACITY = "flick_widget_bg_opacity"
    const val KEY_SHOW_ALBUM_ART = "flick_widget_show_album_art"
    const val KEY_SHOW_ARTIST = "flick_widget_show_artist"
    const val KEY_ACCENT_COLOR = "flick_widget_accent_color"
    const val KEY_POSITION_MS = "flick_widget_position_ms"
    const val KEY_DURATION_MS = "flick_widget_duration_ms"
    const val KEY_QUEUE_COUNT = "flick_widget_queue_count"

    private val BG_OPACITY_MAP = mapOf(
        0 to 0x00, 1 to 0x40, 2 to 0x80, 3 to 0xC0, 4 to 0xFF
    )

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getBgOpacityAlpha(context: Context): Int {
        val level = get(context).getInt(KEY_BG_OPACITY, 3)
        return BG_OPACITY_MAP[level] ?: 0xC0
    }

    fun getShowAlbumArt(context: Context): Boolean =
        get(context).getBoolean(KEY_SHOW_ALBUM_ART, true)

    fun getShowArtist(context: Context): Boolean =
        get(context).getBoolean(KEY_SHOW_ARTIST, true)

    fun getAccentName(context: Context): String =
        get(context).getString(KEY_ACCENT_COLOR, "white") ?: "white"

    fun getAccentColor(context: Context): Int {
        return when (getAccentName(context)) {
            "amber" -> 0xFFFFB300.toInt()
            "blue" -> 0xFF64B5F6.toInt()
            "green" -> 0xFF81C784.toInt()
            "purple" -> 0xFFCE93D8.toInt()
            else -> 0xFFFFFFFF.toInt()
        }
    }

    fun getProgressDrawableRes(context: Context): Int {
        return when (getAccentName(context)) {
            "amber" -> R.drawable.widget_progress_amber
            "blue" -> R.drawable.widget_progress_blue
            "green" -> R.drawable.widget_progress_green
            "purple" -> R.drawable.widget_progress_purple
            else -> R.drawable.widget_progress_white
        }
    }

    fun getBackgroundDrawableRes(context: Context): Int {
        val level = get(context).getInt(KEY_BG_OPACITY, 3)
        return when (level) {
            0 -> R.drawable.widget_bg_0
            1 -> R.drawable.widget_bg_1
            2 -> R.drawable.widget_bg_2
            4 -> R.drawable.widget_bg_4
            else -> R.drawable.widget_bg_3
        }
    }

    // --- Flagship widget preferences ---

    private const val KEY_FLAGSHIP_ACCENT = "flick_widget_flagship_accent"
    private const val KEY_FLAGSHIP_SHOW_ARTIST = "flick_widget_flagship_show_artist"

    fun getFlagshipShowArtist(context: Context): Boolean =
        get(context).getBoolean(KEY_FLAGSHIP_SHOW_ARTIST, true)

    fun getFlagshipAccentName(context: Context): String =
        get(context).getString(KEY_FLAGSHIP_ACCENT, "white") ?: "white"

    fun getFlagshipAccentColor(context: Context): Int {
        return when (getFlagshipAccentName(context)) {
            "amber" -> 0xFFFFB300.toInt()
            "blue" -> 0xFF64B5F6.toInt()
            "green" -> 0xFF81C784.toInt()
            "purple" -> 0xFFCE93D8.toInt()
            else -> 0xFFFFFFFF.toInt()
        }
    }

}
