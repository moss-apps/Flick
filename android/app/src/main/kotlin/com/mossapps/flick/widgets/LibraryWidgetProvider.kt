package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.mossapps.flick.R

/**
 * Library shortcuts widget: a 4x1 row of buttons that deep-link into the
 * various sections of the app (Songs, Albums, Artists, Playlists, Favorites).
 */
class LibraryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_library)

            views.setOnClickPendingIntent(
                R.id.widget_lib_songs,
                WidgetIntents.openLibrarySection(context, "songs", id * 10 + 1),
            )
            views.setOnClickPendingIntent(
                R.id.widget_lib_albums,
                WidgetIntents.openLibrarySection(context, "albums", id * 10 + 2),
            )
            views.setOnClickPendingIntent(
                R.id.widget_lib_artists,
                WidgetIntents.openLibrarySection(context, "artists", id * 10 + 3),
            )
            views.setOnClickPendingIntent(
                R.id.widget_lib_playlists,
                WidgetIntents.openLibrarySection(context, "playlists", id * 10 + 4),
            )
            views.setOnClickPendingIntent(
                R.id.widget_lib_favorites,
                WidgetIntents.openLibrarySection(context, "favorites", id * 10 + 5),
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
