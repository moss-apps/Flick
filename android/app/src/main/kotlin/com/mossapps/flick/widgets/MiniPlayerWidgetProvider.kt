package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import com.mossapps.flick.R

class MiniPlayerWidgetProvider : AppWidgetProvider() {

    companion object {
        // ponytail: horizontal chrome in dp — paddings + text margins + transport buttons.
        // Art is now full-bleed background, not a thumbnail, so no art dp in the chrome sum.
        // Subtract from widget width to size the text bitmap so Product Sans renders at intended sp.
        private const val CHROME_DP = 148f
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
        val positionMs = readMs(prefs, WidgetPrefs.KEY_POSITION_MS)
        val durationMs = readMs(prefs, WidgetPrefs.KEY_DURATION_MS)
        val showArt = WidgetPrefs.getShowAlbumArt(context)
        val showArtist = WidgetPrefs.getShowArtist(context)
        val accentColor = WidgetPrefs.getAccentColor(context)

        val dm = context.resources.displayMetrics

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_mini_player)
            views.applyBackground(context)

            // ponytail: album art as full-bleed background.
            // showArt toggles it; default art fills in when no song or art not yet loaded.
            if (showArt) {
                val art = if (hasSong) WidgetArtLoader.load(artPath, ART_BG_PX) else null
                if (art != null) {
                    views.setImageViewBitmap(R.id.widget_art_bg, art)
                } else {
                    views.setImageViewResource(R.id.widget_art_bg, R.drawable.widget_default_art)
                }
                views.setViewVisibility(R.id.widget_art_bg, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_art_bg, View.GONE)
            }
            views.setOnClickPendingIntent(R.id.widget_art_bg, WidgetIntents.openApp(context, 10))

            // ponytail: RemoteViews ignores XML fonts on many launchers; render text to bitmaps.
            // Size the bitmap to the actual text column so sp isn't rescaled by fitStart.
            val options = appWidgetManager.getAppWidgetOptions(id)
            val widgetWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val widgetWidthPx =
                if (widgetWidthDp > 0) (widgetWidthDp * dm.density).toInt() else dm.widthPixels
            val textWidthPx = (widgetWidthPx - CHROME_DP * dm.density).toInt().coerceAtLeast(80)

            if (hasSong) {
                views.setImageViewBitmap(
                    R.id.widget_title,
                    WidgetTextRenderer.createTextBitmap(
                        context, title, R.font.product_sans_bold, 13, Color.WHITE, textWidthPx,
                    ),
                )
                views.setContentDescription(R.id.widget_title, title)

                if (showArtist && artist.isNotEmpty()) {
                    views.setImageViewBitmap(
                        R.id.widget_artist,
                        WidgetTextRenderer.createTextBitmap(
                            context, artist, R.font.product_sans_regular, 11, accentColor, textWidthPx,
                        ),
                    )
                    views.setContentDescription(R.id.widget_artist, artist)
                    views.setViewVisibility(R.id.widget_artist, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_artist, View.GONE)
                }

                views.setImageViewResource(
                    R.id.widget_play_pause,
                    if (isPlaying) R.drawable.widget_ic_lucide_pause else R.drawable.widget_ic_lucide_play,
                )

                if (durationMs > 0) {
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    views.setProgressBar(
                        R.id.widget_progress, 1000,
                        (positionMs * 1000L / durationMs).toInt().coerceIn(0, 1000), false,
                    )
                    // ponytail: tint the white base drawable so the bar follows the accent color.
                    // RemoteViews has no setProgressTintList helper, so route via setColorStateList
                    // reflection action calling ProgressBar.setProgressTintList(ColorStateList).
                    views.setColorStateList(
                        R.id.widget_progress, "setProgressTintList",
                        ColorStateList.valueOf(accentColor),
                    )
                    views.setColorStateList(
                        R.id.widget_progress, "setProgressBackgroundTintList",
                        ColorStateList.valueOf(0x33FFFFFF),
                    )
                } else {
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
                }

                views.setOnClickPendingIntent(R.id.widget_title, WidgetIntents.openApp(context, 11))
                views.setOnClickPendingIntent(R.id.widget_artist, WidgetIntents.openApp(context, 12))
                views.setOnClickPendingIntent(R.id.widget_play_pause, WidgetIntents.playerPlayPause(context))
                views.setOnClickPendingIntent(R.id.widget_next, WidgetIntents.playerNext(context))
                views.setOnClickPendingIntent(R.id.widget_prev, WidgetIntents.playerPrevious(context))

                views.setViewVisibility(R.id.widget_prev, View.VISIBLE)
                views.setViewVisibility(R.id.widget_play_pause, View.VISIBLE)
                views.setViewVisibility(R.id.widget_next, View.VISIBLE)
            } else {
                val tapText = context.getString(R.string.widget_tap_to_open)
                views.setImageViewBitmap(
                    R.id.widget_title,
                    WidgetTextRenderer.createTextBitmap(
                        context, tapText, R.font.product_sans_bold, 13, Color.WHITE, textWidthPx,
                    ),
                )
                views.setContentDescription(R.id.widget_title, tapText)
                views.setViewVisibility(R.id.widget_artist, View.GONE)
                views.setViewVisibility(R.id.widget_progress, View.GONE)
                views.setViewVisibility(R.id.widget_prev, View.GONE)
                views.setViewVisibility(R.id.widget_play_pause, View.GONE)
                views.setViewVisibility(R.id.widget_next, View.GONE)

                views.setOnClickPendingIntent(R.id.widget_title, WidgetIntents.openApp(context, 20))
            }

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
