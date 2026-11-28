package com.mossapps.flick.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.util.LruCache
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R
import kotlin.math.roundToInt

internal data class WidgetPlaybackState(
    val hasSong: Boolean,
    val isPlaying: Boolean,
    val title: String,
    val artist: String,
    val artPath: String?,
    val positionMs: Long,
    val durationMs: Long,
    val shuffle: Boolean,
    val loopMode: Int,
) {
    companion object {
        fun read(context: Context): WidgetPlaybackState {
            val prefs = WidgetPrefs.get(context)
            val hasSong = prefs.getBoolean(WidgetPrefs.KEY_HAS_SONG, false)
            fun milliseconds(key: String): Long = try {
                prefs.getLong(key, 0L)
            } catch (_: ClassCastException) {
                prefs.getInt(key, 0).toLong()
            }
            return WidgetPlaybackState(
                hasSong,
                prefs.getBoolean(WidgetPrefs.KEY_IS_PLAYING, false),
                if (hasSong) prefs.getString(WidgetPrefs.KEY_TITLE, "")?.takeIf { it.isNotBlank() }
                    ?: context.getString(R.string.widget_unknown_track)
                else context.getString(R.string.widget_tap_to_open),
                prefs.getString(WidgetPrefs.KEY_ARTIST, "") ?: "",
                if (hasSong) prefs.getString(WidgetPrefs.KEY_ALBUM_ART, null) else null,
                milliseconds(WidgetPrefs.KEY_POSITION_MS),
                milliseconds(WidgetPrefs.KEY_DURATION_MS),
                prefs.getBoolean(WidgetPrefs.KEY_IS_SHUFFLE, false),
                prefs.getInt(WidgetPrefs.KEY_LOOP_MODE, 0),
            )
        }
    }
}

internal data class WidgetUpcomingTrack(val title: String, val artPath: String?) {
    companion object {
        fun read(context: Context): List<WidgetUpcomingTrack> {
            val prefs = WidgetPrefs.get(context)
            if (!prefs.getBoolean(WidgetPrefs.KEY_HAS_SONG, false)) return emptyList()
            return listOf(
                Triple(WidgetPrefs.KEY_NEXT_1_ID, WidgetPrefs.KEY_NEXT_1_TITLE, WidgetPrefs.KEY_NEXT_1_ART),
                Triple(WidgetPrefs.KEY_NEXT_2_ID, WidgetPrefs.KEY_NEXT_2_TITLE, WidgetPrefs.KEY_NEXT_2_ART),
            ).mapNotNull { (id, title, art) ->
                if (prefs.getString(id, "").isNullOrEmpty()) null
                else WidgetUpcomingTrack(
                    prefs.getString(title, "")?.takeIf { it.isNotBlank() }
                        ?: context.getString(R.string.widget_unknown_track),
                    prefs.getString(art, null),
                )
            }
        }
    }
}

internal object WidgetViews {
    const val SECONDARY_TEXT = 0xD6FFFFFF.toInt()
    private data class ProgressKey(val progress: Int, val accent: Int, val track: Int,
        val size: WidgetSize?, val radius: Int)
    private val progressCache = LruCache<ProgressKey, Bitmap>(8)

    fun pixels(context: Context, dp: Int): Int =
        (dp * context.resources.displayMetrics.density).roundToInt().coerceAtLeast(0)

    fun text(
        context: Context, views: RemoteViews, viewId: Int, text: String,
        sp: Int, widthDp: Int, heightDp: Int, bold: Boolean,
        color: Int = if (bold) Color.WHITE else SECONDARY_TEXT,
        weight: Int = if (bold) 600 else 400,
        shadowColor: Int = 0,
        alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
        fakeBold: Boolean = false,
        fitWidth: Boolean = false,
        fillHeight: Boolean = false,
    ) {
        views.setImageViewBitmap(viewId, WidgetTextRenderer.createTextBitmap(
            context, text, if (bold) R.font.product_sans_bold else R.font.product_sans_regular,
            sp, color, pixels(context, widthDp), alignment,
            maxHeightPx = pixels(context, heightDp),
            fontWeight = weight, shadowColor = shadowColor, fakeBold = fakeBold, fitWidth = fitWidth,
            fillHeight = fillHeight,
        ))
        views.setContentDescription(viewId, text)
    }

    fun art(
        context: Context, views: RemoteViews, viewId: Int, state: WidgetPlaybackState,
        size: WidgetSize, maxPx: Int, radiusDp: Int = 24,
    ) {
        views.setImageViewBitmap(viewId, WidgetArtLoader.rounded(context, state.artPath, size, maxPx, radiusDp))
        views.setOnClickPendingIntent(viewId, WidgetIntents.openApp(context, viewId))
    }

    fun playBackground(accent: Int, compact: Boolean = false): Int = when (accent) {
        0xFFFFB300.toInt() -> if (compact) R.drawable.widget_button_small_play_amber else R.drawable.widget_button_play_bg_amber
        0xFF64B5F6.toInt() -> if (compact) R.drawable.widget_button_small_play_blue else R.drawable.widget_button_play_bg_blue
        0xFF81C784.toInt() -> if (compact) R.drawable.widget_button_small_play_green else R.drawable.widget_button_play_bg_green
        0xFFCE93D8.toInt() -> if (compact) R.drawable.widget_button_small_play_purple else R.drawable.widget_button_play_bg_purple
        else -> if (compact) R.drawable.widget_button_small_play else R.drawable.widget_button_play_bg
    }

    fun playButton(
        context: Context, views: RemoteViews, state: WidgetPlaybackState,
        playId: Int, backgroundRes: Int, foreground: Int,
        playIcon: Int = R.drawable.widget_ic_lucide_play, pauseIcon: Int = R.drawable.widget_ic_lucide_pause,
    ) {
        views.setViewVisibility(playId, if (state.hasSong) View.VISIBLE else View.GONE)
        views.setImageViewResource(playId, if (state.isPlaying) pauseIcon else playIcon)
        // Background tint setters are not remotely callable on Android 8.
        views.setInt(playId, "setBackgroundResource", backgroundRes)
        views.setInt(playId, "setColorFilter", foreground)
        views.setContentDescription(playId, context.getString(
            if (state.isPlaying) R.string.widget_pause else R.string.widget_play))
        views.setOnClickPendingIntent(playId, WidgetIntents.playerPlayPause(context))
    }

    fun skipButtons(
        context: Context, views: RemoteViews, state: WidgetPlaybackState,
        prevId: Int, nextId: Int, foreground: Int,
    ) {
        for (id in listOf(prevId, nextId)) {
            views.setViewVisibility(id, if (state.hasSong) View.VISIBLE else View.GONE)
            views.setInt(id, "setColorFilter", foreground)
        }
        views.setOnClickPendingIntent(prevId, WidgetIntents.playerPrevious(context))
        views.setOnClickPendingIntent(nextId, WidgetIntents.playerNext(context))
    }

    fun repeatDescription(mode: Int): Int = when (mode) {
        0 -> R.string.widget_repeat_off
        1 -> R.string.widget_repeat_one
        2 -> R.string.widget_repeat_all
        else -> R.string.widget_repeat_special
    }

    fun progress(
        views: RemoteViews, viewId: Int, state: WidgetPlaybackState, accent: Int,
        trackColor: Int = 0x33FFFFFF, barSize: WidgetSize? = null, radiusDp: Int = 0,
    ) {
        val progress = WidgetLayoutPolicy.progress(state.positionMs, state.durationMs)
        val visible = state.hasSong && state.durationMs > 0 && (trackColor != 0 || progress > 0)
        views.setViewVisibility(viewId, if (visible) View.VISIBLE else View.GONE)
        if (!visible) return
        val key = ProgressKey(progress, accent, trackColor, barSize, radiusDp)
        val width = if (barSize == null) 1000 else 384
        val scale = if (barSize == null) 1f else width.toFloat() / barSize.widthDp.coerceAtLeast(1)
        val height = if (barSize == null) 4 else (barSize.heightDp * scale).roundToInt().coerceAtLeast(1)
        val lineHeight = if (barSize == null) 4f else 2f * scale
        val bitmap = progressCache.get(key) ?: Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
            // RemoteViews.setColorStateList is API 31+. A small, cached strip
            // preserves the selected accent on every supported Android version.
            val canvas = Canvas(it)
            if (radiusDp > 0) canvas.clipPath(Path().apply {
                addRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()),
                    radiusDp * scale, radiusDp * scale, Path.Direction.CW)
            })
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = trackColor
            canvas.drawRoundRect(0f, height - lineHeight, width.toFloat(), height.toFloat(), 2f, 2f, paint)
            paint.color = accent
            if (progress > 0) canvas.drawRoundRect(0f, height - lineHeight, width * progress / 1000f,
                height.toFloat(), 2f, 2f, paint)
            progressCache.put(key, it)
        }
        views.setImageViewBitmap(viewId, bitmap)
    }
}
