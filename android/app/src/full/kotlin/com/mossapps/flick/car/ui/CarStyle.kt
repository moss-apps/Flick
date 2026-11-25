package com.mossapps.flick.car.ui

import android.content.Context
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.model.CarIcon
import androidx.car.app.versioning.CarAppApiLevels
import androidx.core.graphics.drawable.IconCompat
import com.mossapps.flick.CarArtProvider
import com.mossapps.flick.R

/**
 * Icons and covers for the car, and the one place the negotiated level is read
 * (docs/ANDROID_AUTO_DESIGN.md, 6).
 *
 * Covers are only ever `content://` URIs from [CarArtProvider]; a missing or unreadable
 * cover falls back to the bundled placeholder. No bitmap crosses the binder.
 */
class CarStyle(private val context: Context) {
    private val icons = HashMap<IconId, CarIcon>()
    private val compat = HashMap<IconId, IconCompat>()
    private val covers = HashMap<String, CarIcon>()

    /** A bundled icon in the host's default tint; the placeholder keeps its own colours. */
    fun icon(id: IconId): CarIcon = icons.getOrPut(id) {
        try {
            val vector = iconCompat(id)
            if (id == IconId.PLACEHOLDER) CarIcon.createOriginalIcon(vector) else CarIcon.createTintedIcon(vector)
        } catch (t: RuntimeException) {
            // A usable fallback keeps the row clickable.
            Log.w(TAG, "icon $id unavailable: ${t.message}")
            CarIcon.ALERT
        }
    }

    /** The raw vector, for tinting with a colour at level 9. */
    fun iconCompat(id: IconId): IconCompat = compat.getOrPut(id) {
        IconCompat.createWithResource(context, resourceOf(id))
    }

    /** The cover for [art], or the placeholder when there is none or it cannot be addressed. */
    fun art(art: String?): CarIcon {
        if (art.isNullOrEmpty()) return icon(IconId.PLACEHOLDER)
        covers[art]?.let { return it }
        val built = try {
            CarArtProvider.uriFor(context, art)?.let { uri ->
                CarIcon.Builder(IconCompat.createWithContentUri(uri)).build()
            }
        } catch (t: RuntimeException) {
            Log.w(TAG, "cover unavailable: ${t.message}")
            null
        } ?: return icon(IconId.PLACEHOLDER)
        // Bounded: a long session over a big library must not grow without limit.
        if (covers.size >= MAX_COVERS) covers.clear()
        covers[art] = built
        return built
    }

    private fun resourceOf(id: IconId): Int = when (id) {
        IconId.ALBUMS -> R.drawable.ic_car_albums
        IconId.ARTISTS -> R.drawable.ic_car_artists
        IconId.PLAYLISTS -> R.drawable.ic_car_playlists
        IconId.SONGS -> R.drawable.ic_car_songs
        IconId.FAVORITES -> R.drawable.ic_car_favorites
        IconId.FOLDERS -> R.drawable.ic_car_folders
        IconId.SEARCH -> R.drawable.ic_car_search
        IconId.QUEUE -> R.drawable.ic_car_queue
        IconId.SHUFFLE -> R.drawable.ic_car_shuffle
        IconId.REPEAT -> R.drawable.ic_car_repeat
        IconId.REPEAT_ONE -> R.drawable.ic_car_repeat_one
        IconId.PLAY -> R.drawable.ic_car_play
        IconId.ADD_QUEUE -> R.drawable.ic_car_add_queue
        IconId.PLACEHOLDER -> R.drawable.ic_car_placeholder
    }

    companion object {
        private const val TAG = "CarStyle"
        private const val MAX_COVERS = 512

        /** The only level read in the car module: true when the host negotiated Car API 9 or higher. */
        fun api9(carContext: CarContext): Boolean = carContext.carAppApiLevel >= CarAppApiLevels.LEVEL_9
    }
}
