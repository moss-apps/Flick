package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R
import kotlin.math.ceil
import kotlin.math.roundToInt

class NowPlayingWidgetProvider : ResponsiveWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        if (appWidgetIds.isEmpty()) return
        val state = WidgetPlaybackState.read(context)
        val coverColor = WidgetArtLoader.dominantColor(state.artPath)
        val display = context.resources.displayMetrics
        // Each of the launcher's up to 16 size variants can carry two artwork bitmaps.
        val bitmapSide = (minOf(display.widthPixels, display.heightPixels) / 5).coerceIn(1, 256)
        for (id in appWidgetIds) {
            val views = responsiveViews(appWidgetManager.getAppWidgetOptions(id), WidgetLayoutPolicy.nowPlayingDefault) { size ->
                render(context, size, state, coverColor, bitmapSide)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun render(
        context: Context, size: WidgetSize, state: WidgetPlaybackState,
        coverColor: Int?, bitmapSide: Int,
    ): RemoteViews {
        val colors = WidgetLayoutPolicy.nowPlayingColors(
            background = coverColor ?: 0xFFF9FD6F.toInt(), gradient = coverColor != null,
        )
        val display = context.resources.displayMetrics
        val textWidth = if (size.heightDp < 62) minOf(size.widthDp, 320) else size.widthDp
        val titleSp = WidgetPrefs.scaledSp(17, textWidth, 320f, 1f)
        val artistSp = WidgetPrefs.scaledSp(13, textWidth, 320f, 1f)
        fun lineHeight(font: Int, sp: Int): Int {
            val metrics = Paint().apply {
                typeface = context.resources.getFont(font)
                textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp.toFloat(), display)
            }.fontMetricsInt
            return ceil((metrics.descent - metrics.ascent) / display.density).toInt()
        }
        val geometry = WidgetLayoutPolicy.nowPlaying(size, state.hasSong,
            lineHeight(R.font.product_sans_bold, titleSp), lineHeight(R.font.product_sans_regular, artistSp))
        val layout = if (geometry.controlsBelow) R.layout.widget_now_playing_narrow else R.layout.widget_now_playing
        val views = RemoteViews(context.packageName, layout)
        val padding = WidgetViews.pixels(context, geometry.horizontalPaddingDp)
        views.setViewPadding(R.id.now_playing_content, padding, 0, padding, 0)
        views.setInt(R.id.now_playing_root, "setBackgroundResource", android.R.color.transparent)
        val radius = (minOf(size.widthDp, size.heightDp) * 0.18f).roundToInt()
        views.setImageViewBitmap(R.id.now_playing_surface, WidgetArtLoader.gradientSurface(
            context, size, bitmapSide, radius, colors.start, colors.end, Color.TRANSPARENT,
        ))

        val open = if (state.hasSong) WidgetIntents.openFullPlayer(context) else WidgetIntents.openApp(context, 72)
        views.setOnClickPendingIntent(R.id.now_playing_root, open)
        views.setOnClickPendingIntent(R.id.now_playing_metadata, open)

        val title = if (state.hasSong) state.title else context.getString(R.string.widget_open_app)
        val showArtist = geometry.showArtist && state.artist.isNotBlank()
        views.setTextViewText(R.id.now_playing_title, title)
        views.setTextColor(R.id.now_playing_title, colors.foreground)
        views.setTextViewTextSize(R.id.now_playing_title, TypedValue.COMPLEX_UNIT_SP,
            titleSp.toFloat())
        views.setViewVisibility(R.id.now_playing_artist, if (showArtist) View.VISIBLE else View.GONE)
        if (showArtist) {
            views.setTextViewText(R.id.now_playing_artist, state.artist)
            views.setTextColor(R.id.now_playing_artist, colors.secondary)
            views.setTextViewTextSize(R.id.now_playing_artist, TypedValue.COMPLEX_UNIT_SP,
                artistSp.toFloat())
        }
        val description = if (state.hasSong) {
            listOfNotNull(title, state.artist.takeIf { showArtist }, context.getString(R.string.widget_open_full_player))
                .joinToString(", ")
        } else title
        views.setContentDescription(R.id.now_playing_metadata, description)

        if (!geometry.controlsBelow) {
            val art = geometry.artDp
            views.setViewVisibility(R.id.now_playing_art, if (art > 0) View.VISIBLE else View.GONE)
            if (art > 0) {
                views.setImageViewBitmap(R.id.now_playing_art, WidgetArtLoader.rounded(
                    context, state.artPath, WidgetSize(art, art), bitmapSide, (art * 0.18f).roundToInt(),
                    placeholder = R.drawable.widget_now_playing_placeholder,
                ))
                views.setOnClickPendingIntent(R.id.now_playing_art, open)
            }
        }

        views.setViewVisibility(R.id.now_playing_controls, if (state.hasSong) View.VISIBLE else View.GONE)
        WidgetViews.skipButtons(context, views, state, R.id.now_playing_prev, R.id.now_playing_next, colors.foreground)
        if (!geometry.showPrevious) views.setViewVisibility(R.id.now_playing_prev, View.GONE)
        if (!geometry.showNext) views.setViewVisibility(R.id.now_playing_next, View.GONE)
        WidgetViews.playButton(context, views, state, R.id.now_playing_play,
            if (colors.lightText) R.drawable.widget_now_playing_play_light else R.drawable.widget_now_playing_play_dark,
            colors.playIcon,
            playIcon = R.drawable.widget_ic_play, pauseIcon = R.drawable.widget_ic_pause,
        )
        val progressGap = geometry.progressGapDp
        val showProgress = progressGap != null && state.durationMs > 0
        views.setViewVisibility(R.id.now_playing_progress_region, if (showProgress) View.VISIBLE else View.GONE)
        if (progressGap != null && showProgress) {
            val edge = WidgetViews.pixels(context, 8 - geometry.horizontalPaddingDp)
            views.setViewPadding(R.id.now_playing_progress_region, edge, WidgetViews.pixels(context, progressGap), edge, 0)
            WidgetViews.progress(views, R.id.now_playing_progress, state, colors.foreground,
                trackColor = colors.progressTrack)
        }
        return views
    }
}
