package com.mossapps.flick.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.mossapps.flick.MainActivity

internal object WidgetIntents {

    private val immutableFlags: Int
        get() = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0

    private fun broadcast(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            action = "com.mossapps.flick.WIDGET_ACTION"
            data = uri
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlags,
        )
    }

    private fun activity(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.mossapps.flick.WIDGET_LAUNCH"
            data = uri
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlags,
        )
    }

    fun playerPlayPause(context: Context): PendingIntent =
        broadcast(context, Uri.parse("flickwidget://player/play_pause"), 1)

    fun playerNext(context: Context): PendingIntent =
        broadcast(context, Uri.parse("flickwidget://player/next"), 2)

    fun playerPrevious(context: Context): PendingIntent =
        broadcast(context, Uri.parse("flickwidget://player/previous"), 3)

    fun playerShuffle(context: Context): PendingIntent =
        broadcast(context, Uri.parse("flickwidget://player/shuffle"), 4)

    fun playerRepeat(context: Context): PendingIntent =
        broadcast(context, Uri.parse("flickwidget://player/repeat"), 5)

    fun openApp(context: Context, requestCode: Int): PendingIntent =
        activity(context, Uri.parse("flickwidget://player/open"), requestCode)
}
