package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.mossapps.flick.R

/**
 * Now-playing playlist widget: shows the currently playing queue and lets
 * the user jump to any track. Uses a [RemoteViewsService] to populate the
 * `ListView` from SharedPreferences.
 */
class NowPlayingWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing)

            val intent = Intent(context, NowPlayingRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                // Unique data URI so Android does not cache RemoteViewsFactory
                // across widget IDs / refreshes.
                data = Uri.parse("flick-widget://now-playing/$id/${System.currentTimeMillis()}")
            }
            views.setRemoteAdapter(R.id.widget_queue_list, intent)
            views.setEmptyView(R.id.widget_queue_list, R.id.widget_queue_empty)

            // Header opens the app at the queue screen.
            views.setOnClickPendingIntent(
                R.id.widget_now_playing_header,
                WidgetIntents.openApp(context, id),
            )

            // Each row will be filled in by the RemoteViewsFactory with a
            // fillInIntent carrying the queue index.
            views.setPendingIntentTemplate(
                R.id.widget_queue_list,
                WidgetIntents.queueJumpTemplate(context),
            )

            appWidgetManager.updateAppWidget(id, views)
            // Force the list to re-bind whenever data changes.
            appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.widget_queue_list)
        }
    }
}
