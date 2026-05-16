package com.mossapps.flick.widgets

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.mossapps.flick.R
import java.io.File

/**
 * RemoteViewsService backing the [NowPlayingWidgetProvider] queue ListView.
 * Each call to [onDataSetChanged] reloads the queue snapshot from the shared
 * preferences populated by Flutter via `WidgetSyncService`.
 */
class NowPlayingRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        QueueViewsFactory(applicationContext)
}

private class QueueViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<QueueEntry> = emptyList()
    private var currentIndex: Int = -1

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val prefs = WidgetPrefs.get(context)
        items = decodeQueue(prefs.getString(WidgetPrefs.KEY_QUEUE_JSON, ""))
        currentIndex = prefs.getInt(WidgetPrefs.KEY_CURRENT_INDEX, -1)
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val entry = items.getOrNull(position) ?: return RemoteViews(
            context.packageName,
            R.layout.widget_queue_row,
        )
        val row = RemoteViews(context.packageName, R.layout.widget_queue_row)
        row.setTextViewText(R.id.queue_row_title, entry.title)
        row.setTextViewText(R.id.queue_row_artist, entry.artist)

        val bitmap = entry.albumArtPath
            .takeIf { it.isNotEmpty() && File(it).exists() }
            ?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
        if (bitmap != null) {
            row.setImageViewBitmap(R.id.queue_row_art, bitmap)
        } else {
            row.setImageViewResource(R.id.queue_row_art, R.drawable.widget_default_art)
        }

        // Highlight the currently playing track.
        row.setViewVisibility(
            R.id.queue_row_indicator,
            if (position == currentIndex) android.view.View.VISIBLE
            else android.view.View.INVISIBLE,
        )

        // Fill-in intent: PendingIntent template was set with
        // `home_widget://player/jump`; we just need to attach the index.
        val fillIn = Intent().apply {
            data = android.net.Uri.parse("home_widget://player/jump?index=$position")
        }
        row.setOnClickFillInIntent(R.id.queue_row_root, fillIn)
        return row
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
