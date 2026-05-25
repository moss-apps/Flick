package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R

class FlagshipWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "FlagshipWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(TAG, "onUpdate called for ids=${appWidgetIds.contentToString()}")
        try {
            val prefs = WidgetPrefs.get(context)
            val hasSong = prefs.getBoolean(WidgetPrefs.KEY_HAS_SONG, false)
            val isPlaying = prefs.getBoolean(WidgetPrefs.KEY_IS_PLAYING, false)
            val title = prefs.getString(WidgetPrefs.KEY_TITLE, "")?.takeIf { it.isNotEmpty() }
                ?: context.getString(R.string.widget_nothing_playing)
            val artist = prefs.getString(WidgetPrefs.KEY_ARTIST, "") ?: ""
            val artPath = prefs.getString(WidgetPrefs.KEY_ALBUM_ART, "") ?: ""
            val positionMs = readMs(prefs, WidgetPrefs.KEY_POSITION_MS)
            val durationMs = readMs(prefs, WidgetPrefs.KEY_DURATION_MS)
            val showArtist = WidgetPrefs.getFlagshipShowArtist(context)
            val accentColor = WidgetPrefs.getFlagshipAccentColor(context)
            val theme = WidgetPrefs.getFlagshipTheme(context)
            Log.d(TAG, "hasSong=$hasSong, isPlaying=$isPlaying, title=$title, theme=$theme, idsCount=${appWidgetIds.size}")

            for (id in appWidgetIds) {
                Log.d(TAG, "Updating widget id=$id with theme=$theme")
                val layoutId = when (theme) {
                    "card" -> R.layout.widget_flagship_card
                    "split" -> R.layout.widget_flagship_split
                    else -> R.layout.widget_flagship_art
                }
                val views = RemoteViews(context.packageName, layoutId)

                if (hasSong) {
                    val art = WidgetArtLoader.load(artPath)
                    if (art != null) {
                        views.setImageViewBitmap(R.id.flagship_art, art)
                    } else {
                        views.setImageViewResource(R.id.flagship_art, R.drawable.widget_default_art)
                    }
                    views.setViewVisibility(R.id.flagship_art, View.VISIBLE)

                    views.setTextViewText(R.id.flagship_title, title)
                    views.setTextColor(R.id.flagship_title, Color.WHITE)

                    if (showArtist && artist.isNotEmpty()) {
                        views.setTextViewText(R.id.flagship_artist, artist)
                        views.setTextColor(R.id.flagship_artist, accentColor)
                        views.setViewVisibility(R.id.flagship_artist, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.flagship_artist, View.GONE)
                    }

                    views.setImageViewResource(
                        R.id.flagship_play_pause,
                        if (isPlaying) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
                    )
                    views.setViewVisibility(R.id.flagship_prev, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_play_pause, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_next, View.VISIBLE)

                    if (durationMs > 0) {
                        views.setViewVisibility(R.id.flagship_progress, View.VISIBLE)
                        views.setProgressBar(
                            R.id.flagship_progress,
                            1000,
                            (positionMs * 1000L / durationMs).toInt().coerceIn(0, 1000),
                            false,
                        )
                    } else {
                        views.setViewVisibility(R.id.flagship_progress, View.GONE)
                    }

                    views.setOnClickPendingIntent(
                        R.id.flagship_art,
                        WidgetIntents.openApp(context, 30),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_title,
                        WidgetIntents.openApp(context, 31),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_artist,
                        WidgetIntents.openApp(context, 32),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_play_pause,
                        WidgetIntents.playerPlayPause(context),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_next,
                        WidgetIntents.playerNext(context),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_prev,
                        WidgetIntents.playerPrevious(context),
                    )
                } else {
                    views.setImageViewResource(R.id.flagship_art, R.drawable.widget_default_art)
                    views.setViewVisibility(R.id.flagship_art, View.VISIBLE)
                    views.setTextViewText(
                        R.id.flagship_title,
                        context.getString(R.string.widget_tap_to_open),
                    )
                    views.setTextColor(R.id.flagship_title, Color.WHITE)
                    views.setViewVisibility(R.id.flagship_artist, View.GONE)
                    views.setViewVisibility(R.id.flagship_progress, View.GONE)
                    views.setViewVisibility(R.id.flagship_prev, View.GONE)
                    views.setViewVisibility(R.id.flagship_play_pause, View.GONE)
                    views.setViewVisibility(R.id.flagship_next, View.GONE)

                    val openIntent = WidgetIntents.openApp(context, 40)
                    views.setOnClickPendingIntent(R.id.flagship_art, openIntent)
                    views.setOnClickPendingIntent(R.id.flagship_title, openIntent)
                }

                appWidgetManager.updateAppWidget(id, views)
                Log.d(TAG, "Widget id=$id updated successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating flagship widget", e)
        }
    }

    private fun readMs(prefs: SharedPreferences, key: String): Long {
        return try {
            prefs.getLong(key, 0L)
        } catch (_: ClassCastException) {
            prefs.getInt(key, 0).toLong()
        }
    }
}