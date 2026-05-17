package com.mossapps.flick.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mossapps.flick.MainActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data?.toString() ?: return
        val engine = FlutterEngineCache.getInstance().get("main_engine")
        if (engine != null) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.mossapps.flick/widget")
                .invokeMethod("dispatch", uri)
        } else {
            // App is killed — launch it so it can handle the action on startup
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.mossapps.flick.WIDGET_LAUNCH"
                data = intent.data
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            context.startActivity(launchIntent)
        }
    }
}
