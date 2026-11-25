package com.mossapps.flick.widgets

import android.content.Context
import org.json.JSONException
import org.json.JSONObject

internal data class NowPlayingWidgetSettings(
    val useAlbumArtColor: Boolean,
    val fixedColor: Int,
    val roundness: Int,
    val opacity: Int,
    val textScale: Int,
    val showArtwork: Boolean,
    val showArtist: Boolean,
    val showProgress: Boolean,
) {
    companion object {
        const val LEMON = 0xFFF9FD6F.toInt()

        fun read(context: Context): NowPlayingWidgetSettings {
            val raw = WidgetPrefs.get(context).getString(WidgetPrefs.KEY_NOW_PLAYING_SETTINGS, null)
            val data = try {
                JSONObject(raw ?: "{}")
            } catch (_: JSONException) {
                JSONObject()
            }
            return NowPlayingWidgetSettings(
                useAlbumArtColor = data.optBoolean("useAlbumArtColor", true),
                fixedColor = WidgetPrefs.accentColor(data.optString("fixedColor"), fallback = LEMON),
                roundness = data.optInt("roundness", 36).coerceIn(0, 100),
                opacity = data.optInt("opacity", 100).coerceIn(60, 100),
                textScale = data.optInt("textScale", 100).coerceIn(75, 150),
                showArtwork = data.optBoolean("showArtwork", true),
                showArtist = data.optBoolean("showArtist", true),
                showProgress = data.optBoolean("showProgress", true),
            )
        }
    }
}
