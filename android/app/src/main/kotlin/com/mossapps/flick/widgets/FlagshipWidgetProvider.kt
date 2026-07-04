package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.text.Layout
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R

class FlagshipWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "FlagshipWidget"
        private const val ART_MAX_PX = 1024
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
            val showArtist = WidgetPrefs.getFlagshipShowArtist(context)
            val accentColor = WidgetPrefs.getFlagshipAccentColor(context)
            val isShuffle = prefs.getBoolean(WidgetPrefs.KEY_IS_SHUFFLE, false)
            val loopMode = prefs.getInt(WidgetPrefs.KEY_LOOP_MODE, 0)
            Log.d(TAG, "hasSong=$hasSong, isPlaying=$isPlaying, title=$title, idsCount=${appWidgetIds.size}")

            val dm = context.resources.displayMetrics
            val marginPadDp = 48f

            for (id in appWidgetIds) {
                Log.d(TAG, "Updating widget id=$id")
                val views = RemoteViews(context.packageName, R.layout.widget_flagship_art)

                val options = appWidgetManager.getAppWidgetOptions(id)
                val widgetWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
                val widgetWidthPx = if (widgetWidthDp > 0) (widgetWidthDp * dm.density).toInt() else dm.widthPixels
                val textWidthPx = (widgetWidthPx - marginPadDp * dm.density).toInt().coerceAtLeast(100)

                if (hasSong) {
                    val art = WidgetArtLoader.load(artPath, ART_MAX_PX)
                    if (art != null) {
                        views.setImageViewBitmap(R.id.flagship_art, art)
                    } else {
                        views.setImageViewResource(R.id.flagship_art, R.drawable.widget_default_art)
                    }
                    views.setViewVisibility(R.id.flagship_art, View.VISIBLE)

                    views.setImageViewBitmap(
                        R.id.flagship_title,
                        WidgetTextRenderer.createTextBitmap(
                            context,
                            title,
                            R.font.product_sans_bold,
                            15,
                            Color.WHITE,
                            textWidthPx,
                            Layout.Alignment.ALIGN_CENTER,
                        ),
                    )
                    views.setContentDescription(R.id.flagship_title, title)

                    if (showArtist && artist.isNotEmpty()) {
                        views.setImageViewBitmap(
                            R.id.flagship_artist,
                            WidgetTextRenderer.createTextBitmap(
                                context,
                                artist,
                                R.font.product_sans_regular,
                                12,
                                accentColor,
                                textWidthPx,
                                Layout.Alignment.ALIGN_CENTER,
                            ),
                        )
                        views.setContentDescription(R.id.flagship_artist, artist)
                        views.setViewVisibility(R.id.flagship_artist, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.flagship_artist, View.GONE)
                    }

                    views.setImageViewResource(
                        R.id.flagship_play_pause,
                        if (isPlaying) R.drawable.widget_ic_lucide_pause else R.drawable.widget_ic_lucide_play,
                    )
                    views.setViewVisibility(R.id.flagship_prev, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_play_pause, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_next, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_shuffle, View.VISIBLE)
                    views.setViewVisibility(R.id.flagship_repeat, View.VISIBLE)

                    val inactiveTint = Color.argb(0x55, 0xFF, 0xFF, 0xFF)
                    val activeBg = R.drawable.widget_button_transport_active_bg
                    val inactiveBg = R.drawable.widget_button_transport_bg
                    views.setInt(
                        R.id.flagship_shuffle,
                        "setBackgroundResource",
                        if (isShuffle) activeBg else inactiveBg,
                    )
                    views.setInt(
                        R.id.flagship_shuffle,
                        "setColorFilter",
                        if (isShuffle) accentColor else inactiveTint,
                    )
                    val repeatActive = loopMode != 0
                    views.setInt(
                        R.id.flagship_repeat,
                        "setBackgroundResource",
                        if (repeatActive) activeBg else inactiveBg,
                    )
                    views.setImageViewResource(
                        R.id.flagship_repeat,
                        if (loopMode == 1) R.drawable.widget_ic_repeat1
                        else R.drawable.widget_ic_lucide_repeat,
                    )
                    views.setInt(
                        R.id.flagship_repeat,
                        "setColorFilter",
                        if (repeatActive) accentColor else inactiveTint,
                    )

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
                    views.setOnClickPendingIntent(
                        R.id.flagship_shuffle,
                        WidgetIntents.playerShuffle(context),
                    )
                    views.setOnClickPendingIntent(
                        R.id.flagship_repeat,
                        WidgetIntents.playerRepeat(context),
                    )
                } else {
                    views.setImageViewResource(R.id.flagship_art, R.drawable.widget_default_art)
                    views.setViewVisibility(R.id.flagship_art, View.VISIBLE)
                    val tapText = context.getString(R.string.widget_tap_to_open)
                    views.setImageViewBitmap(
                        R.id.flagship_title,
                        WidgetTextRenderer.createTextBitmap(
                            context,
                            tapText,
                            R.font.product_sans_bold,
                            15,
                            Color.WHITE,
                            textWidthPx,
                            Layout.Alignment.ALIGN_CENTER,
                        ),
                    )
                    views.setContentDescription(R.id.flagship_title, tapText)
                    views.setViewVisibility(R.id.flagship_artist, View.GONE)
                    views.setViewVisibility(R.id.flagship_prev, View.GONE)
                    views.setViewVisibility(R.id.flagship_play_pause, View.GONE)
                    views.setViewVisibility(R.id.flagship_next, View.GONE)
                    views.setViewVisibility(R.id.flagship_shuffle, View.GONE)
                    views.setViewVisibility(R.id.flagship_repeat, View.GONE)

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
}
