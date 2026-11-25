package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.core.graphics.ColorUtils
import com.mossapps.flick.R
import kotlin.math.roundToInt

class NowPlayingWidgetProvider : ResponsiveWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        if (appWidgetIds.isEmpty()) return
        val state = WidgetPlaybackState.read(context)
        val settings = NowPlayingWidgetSettings.read(context)
        val coverColor = if (settings.useAlbumArtColor) WidgetArtLoader.dominantColor(state.artPath) else null
        for (id in appWidgetIds) {
            val views = responsiveViews(appWidgetManager.getAppWidgetOptions(id), WidgetLayoutPolicy.nowPlayingDefault) { size ->
                render(context, size, state, settings, coverColor)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun render(
        context: Context, size: WidgetSize, state: WidgetPlaybackState,
        settings: NowPlayingWidgetSettings, coverColor: Int?,
    ): RemoteViews {
        val fallback = if (settings.useAlbumArtColor) NowPlayingWidgetSettings.LEMON else settings.fixedColor
        val colors = WidgetLayoutPolicy.nowPlayingColors(
            background = coverColor ?: fallback, gradient = coverColor != null, opacity = settings.opacity,
        )
        val geometry = WidgetLayoutPolicy.nowPlaying(size, state.hasSong, settings.showArtwork)
        val layout = if (geometry.controlsBelow) R.layout.widget_now_playing_narrow else R.layout.widget_now_playing
        val views = RemoteViews(context.packageName, layout)
        val padding = WidgetViews.pixels(context, geometry.horizontalPaddingDp)
        views.setViewPadding(R.id.now_playing_content, padding, 0, padding, 0)
        views.setInt(R.id.now_playing_root, "setBackgroundResource", android.R.color.transparent)
        val radius = (minOf(size.widthDp, size.heightDp) * settings.roundness / 200f).roundToInt()
        val alpha = (255 * settings.opacity / 100f).roundToInt()
        views.setImageViewBitmap(R.id.now_playing_surface, WidgetArtLoader.gradientSurface(
            context, size, 768, radius, ColorUtils.setAlphaComponent(colors.start, alpha),
            ColorUtils.setAlphaComponent(colors.end, alpha), Color.TRANSPARENT,
        ))

        val open = if (state.hasSong) WidgetIntents.openFullPlayer(context) else WidgetIntents.openApp(context, 72)
        views.setOnClickPendingIntent(R.id.now_playing_root, open)
        views.setOnClickPendingIntent(R.id.now_playing_metadata, open)

        val title = if (state.hasSong) state.title else context.getString(R.string.widget_open_app)
        val showArtist = settings.showArtist && geometry.showArtist && state.artist.isNotBlank()
        val textScale = settings.textScale / 100f
        views.setTextViewText(R.id.now_playing_title, title)
        views.setTextColor(R.id.now_playing_title, colors.foreground)
        views.setTextViewTextSize(R.id.now_playing_title, TypedValue.COMPLEX_UNIT_SP,
            WidgetPrefs.scaledSp(17, size.widthDp, 320f, textScale).toFloat())
        views.setViewVisibility(R.id.now_playing_artist, if (showArtist) View.VISIBLE else View.GONE)
        if (showArtist) {
            views.setTextViewText(R.id.now_playing_artist, state.artist)
            views.setTextColor(R.id.now_playing_artist, colors.secondary)
            views.setTextViewTextSize(R.id.now_playing_artist, TypedValue.COMPLEX_UNIT_SP,
                WidgetPrefs.scaledSp(13, size.widthDp, 320f, textScale).toFloat())
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
                    context, state.artPath, WidgetSize(art, art), 256, 12,
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
        if (settings.showProgress && geometry.showProgress) {
            WidgetViews.progress(views, R.id.now_playing_progress, state, colors.foreground,
                trackColor = colors.progressTrack)
        } else {
            views.setViewVisibility(R.id.now_playing_progress, View.GONE)
        }
        return views
    }
}
