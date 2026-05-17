package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R

class MiniPlayerWidgetProvider : AppWidgetProvider() {

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
        val positionMs = readMs(prefs, WidgetPrefs.KEY_POSITION_MS)
        val durationMs = readMs(prefs, WidgetPrefs.KEY_DURATION_MS)
        val showArt = WidgetPrefs.getShowAlbumArt(context)
        val showArtist = WidgetPrefs.getShowArtist(context)
        val accentColor = WidgetPrefs.getAccentColor(context)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_mini_player)

            views.applyBackground(context)

            views.setTextViewText(R.id.widget_title, title)

            if (hasSong && showArtist && artist.isNotEmpty()) {
                views.setTextViewText(R.id.widget_artist, artist)
                views.setTextColor(R.id.widget_artist, accentColor)
                views.setViewVisibility(R.id.widget_artist, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_artist, View.GONE)
            }

            if (showArt) {
                val art = WidgetArtLoader.load(artPath)
                if (art != null) {
                    views.setImageViewBitmap(R.id.widget_art, art)
                } else {
                    views.setImageViewResource(R.id.widget_art, R.drawable.widget_default_art)
                }
            } else {
                views.setViewVisibility(R.id.widget_art, View.GONE)
            }

            views.setImageViewResource(
                R.id.widget_play_pause,
                if (isPlaying && hasSong) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
            )

            if (durationMs > 0) {
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                views.setProgressBar(
                    R.id.widget_progress,
                    1000,
                    (positionMs * 1000L / durationMs).toInt().coerceIn(0, 1000),
                    false,
                )
            } else {
                views.setViewVisibility(R.id.widget_progress, View.GONE)
            }

            views.setOnClickPendingIntent(
                R.id.widget_art,
                WidgetIntents.openApp(context, 10),
            )
            views.setOnClickPendingIntent(
                R.id.widget_title,
                WidgetIntents.openApp(context, 11),
            )
            views.setOnClickPendingIntent(
                R.id.widget_artist,
                WidgetIntents.openApp(context, 12),
            )
            views.setOnClickPendingIntent(
                R.id.widget_play_pause,
                WidgetIntents.playerPlayPause(context),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                WidgetIntents.playerNext(context),
            )
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                WidgetIntents.playerPrevious(context),
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
    }

    private fun readMs(prefs: SharedPreferences, key: String): Long {
        return try {
            prefs.getLong(key, 0L)
        } catch (_: ClassCastException) {
            prefs.getInt(key, 0).toLong()
        }
    }

    private fun RemoteViews.applyBackground(context: Context) {
        val bgRes = WidgetPrefs.getBackgroundDrawableRes(context)
        setInt(R.id.widget_root, "setBackgroundResource", bgRes)
    }
}
