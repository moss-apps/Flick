package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.text.Layout
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R

class CompactWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val MARGIN_PAD_DP = 40f
        private const val ART_BG_PX = 512
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = WidgetPrefs.get(context)
        val hasSong = prefs.getBoolean(WidgetPrefs.KEY_HAS_SONG, false)
        val isPlaying = prefs.getBoolean(WidgetPrefs.KEY_IS_PLAYING, false)
        val title = prefs.getString(WidgetPrefs.KEY_TITLE, "")?.takeIf { it.isNotEmpty() }
            ?: context.getString(R.string.widget_nothing_playing)
        val artist = prefs.getString(WidgetPrefs.KEY_ARTIST, "") ?: ""
        val artPath = prefs.getString(WidgetPrefs.KEY_ALBUM_ART, "") ?: ""
        val showArt = WidgetPrefs.getCompactShowAlbumArt(context)
        val showArtist = WidgetPrefs.getCompactShowArtist(context)
        val accentColor = WidgetPrefs.getCompactAccentColor(context)

        val dm = context.resources.displayMetrics

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_compact)
            views.applyBackground(context)
            views.applyArt(context, hasSong, showArt, artPath)

            val options = appWidgetManager.getAppWidgetOptions(id)
            val widgetWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val widgetWidthPx =
                if (widgetWidthDp > 0) (widgetWidthDp * dm.density).toInt() else dm.widthPixels
            val textWidthPx = (widgetWidthPx - MARGIN_PAD_DP * dm.density).toInt().coerceAtLeast(100)

            if (hasSong) {
                views.setImageViewBitmap(
                    R.id.compact_title,
                    WidgetTextRenderer.createTextBitmap(
                        context, title, R.font.product_sans_bold, 15, Color.WHITE,
                        textWidthPx, Layout.Alignment.ALIGN_CENTER,
                    ),
                )
                views.setContentDescription(R.id.compact_title, title)

                if (showArtist && artist.isNotEmpty()) {
                    views.setImageViewBitmap(
                        R.id.compact_artist,
                        WidgetTextRenderer.createTextBitmap(
                            context, artist, R.font.product_sans_regular, 12, accentColor,
                            textWidthPx, Layout.Alignment.ALIGN_CENTER,
                        ),
                    )
                    views.setContentDescription(R.id.compact_artist, artist)
                    views.setViewVisibility(R.id.compact_artist, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.compact_artist, View.GONE)
                }

                views.setImageViewResource(
                    R.id.compact_play_pause,
                    if (isPlaying) R.drawable.widget_ic_lucide_pause else R.drawable.widget_ic_lucide_play,
                )
                views.setViewVisibility(R.id.compact_controls, View.VISIBLE)

                views.setOnClickPendingIntent(R.id.compact_title, WidgetIntents.openApp(context, 50))
                views.setOnClickPendingIntent(R.id.compact_artist, WidgetIntents.openApp(context, 51))
                views.setOnClickPendingIntent(R.id.compact_play_pause, WidgetIntents.playerPlayPause(context))
                views.setOnClickPendingIntent(R.id.compact_next, WidgetIntents.playerNext(context))
                views.setOnClickPendingIntent(R.id.compact_prev, WidgetIntents.playerPrevious(context))
            } else {
                val tapText = context.getString(R.string.widget_tap_to_open)
                views.setImageViewBitmap(
                    R.id.compact_title,
                    WidgetTextRenderer.createTextBitmap(
                        context, tapText, R.font.product_sans_bold, 15, Color.WHITE,
                        textWidthPx, Layout.Alignment.ALIGN_CENTER,
                    ),
                )
                views.setContentDescription(R.id.compact_title, tapText)
                views.setViewVisibility(R.id.compact_artist, View.GONE)
                views.setViewVisibility(R.id.compact_controls, View.GONE)
                views.setOnClickPendingIntent(R.id.compact_title, WidgetIntents.openApp(context, 60))
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun RemoteViews.applyBackground(context: Context) {
        val bgRes = WidgetPrefs.getCompactBackgroundDrawableRes(context)
        setInt(R.id.compact_root, "setBackgroundResource", bgRes)
    }

    private fun RemoteViews.applyArt(
        context: Context,
        hasSong: Boolean,
        showArt: Boolean,
        artPath: String,
    ) {
        if (!showArt) {
            setViewVisibility(R.id.compact_art_bg, View.GONE)
            setViewVisibility(R.id.compact_scrim, View.GONE)
            return
        }
        val art = if (hasSong) WidgetArtLoader.load(artPath, ART_BG_PX) else null
        if (art != null) {
            setImageViewBitmap(R.id.compact_art_bg, art)
        } else {
            setImageViewResource(R.id.compact_art_bg, R.drawable.widget_default_art)
        }
        setViewVisibility(R.id.compact_art_bg, View.VISIBLE)
        setViewVisibility(R.id.compact_scrim, View.VISIBLE)
        setOnClickPendingIntent(R.id.compact_art_bg, WidgetIntents.openApp(context, 52))
    }
}