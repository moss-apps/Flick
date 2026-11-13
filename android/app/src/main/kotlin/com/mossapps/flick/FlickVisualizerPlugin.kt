package com.mossapps.flick

import android.animation.ValueAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Engine-owned capture: never retains the Flutter Activity in channel closures. */
class FlickVisualizerPlugin : FlutterPlugin, ActivityAware {
    private lateinit var context: Context
    private lateinit var captureChannel: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var viewerChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var effect: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var captureGeneration = 0
    private var enabled = false
    private var simulatedAod = false
    private var simulatedAodArmed = false
    private var viewer: LockScreenVisualizerActivity? = null
    private var state: Map<String, Any?> = emptyMap()
    private var screenReceiverRegistered = false
    private var lastViewerClosedAt = 0L
    private var lastSimulatedLaunchAt = 0L

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) maybeLaunchSimulatedAod()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        instance = this
        captureChannel = MethodChannel(binding.binaryMessenger, "com.mossapps.flick/visualizer")
        events = EventChannel(binding.binaryMessenger, "com.mossapps.flick/visualizer_events")
        viewerChannel = MethodChannel(binding.binaryMessenger, "com.mossapps.flick/lock_screen_visualizer")
        registerScreenReceiver()
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                // Dart may replace its subscription after attaching a new
                // session. Only detachVisualizer/engine teardown owns release.
            }
        })
        captureChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "attachVisualizer" -> result.success(attachCapture(call.argument<Int>("sessionId") ?: 0))
                "detachVisualizer" -> {
                    detachCapture()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        viewerChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    enabled = call.argument<Boolean>("enabled") == true
                    simulatedAod = call.argument<Boolean>("simulatedAod") == true
                    simulatedAodArmed = call.argument<Boolean>("armed") == true
                    if (!enabled || (!simulatedAod && viewer?.isSimulatedAod() == true)) {
                        viewer?.finish()
                    }
                    result.success(null)
                }
                "canOpen" -> result.success(canOpen())
                "open" -> {
                    // Permission dialogs can return before window focus does.
                    // Still require a resumed, unlocked host, but do not make
                    // the user tap Open again after granting microphone access.
                    if (!canOpen(requireFocus = false) || state.isEmpty()) {
                        result.success(false)
                    } else {
                        try {
                            activity?.startActivity(
                                Intent(activity, LockScreenVisualizerActivity::class.java)
                                    .addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS),
                            )
                            result.success(true)
                        } catch (error: Exception) {
                            Log.w("Visualizer", "Cannot open lock-screen viewer", error)
                            result.success(false)
                        }
                    }
                }
                "state" -> {
                    @Suppress("UNCHECKED_CAST")
                    state = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                    viewer?.renderState(state)
                    result.success(null)
                }
                "bars" -> {
                    val bars = (call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
                    viewer?.renderBars(bars)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canOpen(requireFocus: Boolean = true): Boolean {
        val host = activity ?: return false
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        // Only an explicit action in an unlocked, foreground Flick window may
        // launch this Activity. Never wake the phone or request keyguard dismissal.
        return enabled && !host.isFinishing && !host.isDestroyed &&
            (host as? LifecycleOwner)?.lifecycle?.currentState == Lifecycle.State.RESUMED &&
            (!requireFocus || host.hasWindowFocus()) && power.isInteractive && !keyguard.isKeyguardLocked
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        try {
            ContextCompat.registerReceiver(
                context,
                screenOffReceiver,
                IntentFilter(Intent.ACTION_SCREEN_OFF),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            screenReceiverRegistered = true
        } catch (error: Exception) {
            Log.w("Visualizer", "Cannot register screen-off receiver", error)
        }
    }

    private fun maybeLaunchSimulatedAod() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastSimulatedLaunchAt < 1_000L) return
        val overlayAllowed = Settings.canDrawOverlays(context)
        val animatorsEnabled = ValueAnimator.areAnimatorsEnabled()
        val eligible = canLaunchSimulatedAod(
            enabled = enabled,
            simulatedAod = simulatedAod,
            armed = simulatedAodArmed,
            viewerOpen = viewer != null,
            recentlyFinished = now - lastViewerClosedAt < 3_000L,
            overlayAllowed = overlayAllowed,
            animatorsEnabled = animatorsEnabled,
        )
        if (!eligible || state.isEmpty()) return
        lastSimulatedLaunchAt = now
        val intent = Intent(context, LockScreenVisualizerActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
            putExtra(LockScreenVisualizerActivity.EXTRA_SIMULATED_AOD, true)
        }
        try {
            context.startActivity(intent)
        } catch (error: Exception) {
            // Do not fall back to an overlay or try to wake the screen another way.
            Log.w("Visualizer", "Cannot launch simulated AOD", error)
        }
    }

    fun connect(view: LockScreenVisualizerActivity): Boolean {
        if (!enabled || state.isEmpty()) return false
        viewer?.takeIf { it !== view }?.finish()
        viewer = view
        view.renderState(state)
        return true
    }

    fun visibility(view: LockScreenVisualizerActivity, visible: Boolean, motionAllowed: Boolean) {
        if (viewer !== view) return
        viewerChannel.invokeMethod("visibility", mapOf("visible" to visible, "motionAllowed" to motionAllowed))
    }

    fun disconnect(view: LockScreenVisualizerActivity) {
        if (viewer !== view) return
        visibility(view, false, false)
        viewer = null
        lastViewerClosedAt = SystemClock.elapsedRealtime()
    }

    private fun attachCapture(sessionId: Int): Boolean {
        detachCapture()
        if (sessionId <= 0) return false // Never capture the global output mix.
        val generation = captureGeneration
        return try {
            val capture = Visualizer(sessionId)
            effect = capture // Also release partially configured effects on failure.
            capture.captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(512)
            capture.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}
                override fun onFftDataCapture(v: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                    val bytes = fft?.clone() ?: return
                    mainHandler.post {
                        if (generation == captureGeneration) {
                            eventSink?.success(mapOf("fft" to bytes, "samplingRate" to samplingRate))
                        }
                    }
                }
            }, visualizerCaptureRateMilliHz(Visualizer.getMaxCaptureRate()), false, true)
            capture.enabled = true
            true
        } catch (error: Exception) {
            Log.w("Visualizer", "Cannot attach to session $sessionId", error)
            detachCapture()
            false
        }
    }

    private fun detachCapture() {
        captureGeneration++
        val capture = effect
        effect = null
        try {
            capture?.enabled = false
        } catch (error: Exception) {
            Log.w("Visualizer", "Cannot disable capture", error)
        } finally {
            try {
                capture?.release()
            } catch (error: Exception) {
                Log.w("Visualizer", "Cannot release capture", error)
            }
        }
        // The EventChannel subscription survives session switches and pauses.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        viewer?.finish()
        viewer = null
        enabled = false
        simulatedAod = false
        simulatedAodArmed = false
        if (screenReceiverRegistered) {
            try {
                context.unregisterReceiver(screenOffReceiver)
            } catch (error: Exception) {
                Log.w("Visualizer", "Cannot unregister screen-off receiver", error)
            }
            screenReceiverRegistered = false
        }
        detachCapture()
        eventSink = null
        captureChannel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        viewerChannel.setMethodCallHandler(null)
        activity = null
        if (instance === this) instance = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    companion object {
        var instance: FlickVisualizerPlugin? = null
            private set
    }
}
