package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import com.mossapps.flick.R
import kotlin.math.roundToInt

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
    const val KEY_TEXT_SCALE = "flick_widget_text_scale"
    const val KEY_POSITION_MS = "flick_widget_position_ms"
    const val KEY_DURATION_MS = "flick_widget_duration_ms"
    const val KEY_QUEUE_COUNT = "flick_widget_queue_count"

    private val BG_OPACITY_MAP = mapOf(
        0 to 0x00, 1 to 0x40, 2 to 0x80, 3 to 0xC0, 4 to 0xFF
    )

    // home_widget encodes Dart doubles as Long bits with a companion flag;
    // decode that here instead of a raw getFloat which would ClassCast.
    private const val DOUBLE_PREFIX = "home_widget.double."
    private fun getWidgetDouble(context: Context, key: String, default: Float): Float {
        val prefs = get(context)
        return if (prefs.getBoolean("$DOUBLE_PREFIX$key", false)) {
            Double.fromBits(prefs.getLong(key, default.toDouble().toBits())).toFloat()
        } else {
            default
        }
    }

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ponytail: rebuild all three home widgets from current prefs; used when the
    // app process is about to die so the play/pause state can't drift stale.
    fun updateAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        listOf(
            MiniPlayerWidgetProvider::class.java,
            FlagshipWidgetProvider::class.java,
            CompactWidgetProvider::class.java,
        ).forEach { cls ->
            val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isNotEmpty()) {
                cls.getDeclaredConstructor().newInstance().onUpdate(context, mgr, ids)
            }
        }
    }

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

    fun getMiniTextScale(context: Context): Float =
        getWidgetDouble(context, KEY_TEXT_SCALE, 1.0f)

    // ponytail: clamp bounds keep text sane across dp sizes; baseline per-widget
    fun scaledSp(baseSp: Int, widgetWidthDp: Int, baselineDp: Float, manualScale: Float): Int {
        val widthDp = if (widgetWidthDp > 0) widgetWidthDp else baselineDp.toInt()
        val auto = (widthDp / baselineDp).coerceIn(0.85f, 1.3f)
        return (baseSp * auto * manualScale).roundToInt().coerceIn(9, 22)
    }

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
    private const val KEY_FLAGSHIP_TEXT_SCALE = "flick_widget_flagship_text_scale"

    fun getFlagshipShowArtist(context: Context): Boolean =
        get(context).getBoolean(KEY_FLAGSHIP_SHOW_ARTIST, true)

    fun getFlagshipAccentName(context: Context): String =
        get(context).getString(KEY_FLAGSHIP_ACCENT, "white") ?: "white"

    fun getFlagshipTextScale(context: Context): Float =
        getWidgetDouble(context, KEY_FLAGSHIP_TEXT_SCALE, 1.0f)

    fun getFlagshipAccentColor(context: Context): Int {
        return when (getFlagshipAccentName(context)) {
            "amber" -> 0xFFFFB300.toInt()
            "blue" -> 0xFF64B5F6.toInt()
            "green" -> 0xFF81C784.toInt()
            "purple" -> 0xFFCE93D8.toInt()
            else -> 0xFFFFFFFF.toInt()
        }
    }

    // --- Compact widget preferences ---

    private const val KEY_COMPACT_BG_OPACITY = "flick_widget_compact_bg_opacity"
    private const val KEY_COMPACT_SHOW_ALBUM_ART = "flick_widget_compact_show_album_art"
    private const val KEY_COMPACT_SHOW_ARTIST = "flick_widget_compact_show_artist"
    private const val KEY_COMPACT_ACCENT = "flick_widget_compact_accent"
    private const val KEY_COMPACT_TEXT_SCALE = "flick_widget_compact_text_scale"

    fun getCompactBgOpacityAlpha(context: Context): Int {
        val level = get(context).getInt(KEY_COMPACT_BG_OPACITY, 3)
        return BG_OPACITY_MAP[level] ?: 0xC0
    }

    fun getCompactBackgroundDrawableRes(context: Context): Int {
        val level = get(context).getInt(KEY_COMPACT_BG_OPACITY, 3)
        return when (level) {
            0 -> R.drawable.widget_bg_0
            1 -> R.drawable.widget_bg_1
            2 -> R.drawable.widget_bg_2
            4 -> R.drawable.widget_bg_4
            else -> R.drawable.widget_bg_3
        }
    }

    fun getCompactShowAlbumArt(context: Context): Boolean =
        get(context).getBoolean(KEY_COMPACT_SHOW_ALBUM_ART, true)

    fun getCompactShowArtist(context: Context): Boolean =
        get(context).getBoolean(KEY_COMPACT_SHOW_ARTIST, true)

    fun getCompactAccentName(context: Context): String =
        get(context).getString(KEY_COMPACT_ACCENT, "white") ?: "white"

    fun getCompactTextScale(context: Context): Float =
        getWidgetDouble(context, KEY_COMPACT_TEXT_SCALE, 1.0f)

    fun getCompactAccentColor(context: Context): Int {
        return when (getCompactAccentName(context)) {
            "amber" -> 0xFFFFB300.toInt()
            "blue" -> 0xFF64B5F6.toInt()
            "green" -> 0xFF81C784.toInt()
            "purple" -> 0xFFCE93D8.toInt()
            else -> 0xFFFFFFFF.toInt()
        }
    }

}
