package com.mossapps.flick

import android.animation.ValueAnimator
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat.AccessibilityActionCompat

/** Visualizer only, like the immersive player. Never exposes unlocked app navigation. */
class LockScreenVisualizerActivity : Activity() {
    private var bridge: FlickVisualizerPlugin? = null
    private var resumed = false
    private var visible = false
    private var motionAllowed = false
    private var animate = false
    private var simulatedAod = false
    private var playing = true
    private var supported = true
    private var finishRunnable: Runnable? = null
    private var batteryLowRegistered = false
    private lateinit var spectrum: LockScreenSpectrumView
    private val mainHandler = Handler(Looper.getMainLooper())

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { syncVisibility() }
    }
    private val motionObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) { syncVisibility() }
    }
    private val batteryLowReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (simulatedAod) finish()
        }
    }
    private val simulatedTimeout = Runnable { if (simulatedAod) finish() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        simulatedAod = intent.getBooleanExtra(EXTRA_SIMULATED_AOD, false)
        bridge = FlickVisualizerPlugin.instance
        if (bridge == null) {
            finish() // No engine/session after process death: fail closed.
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
        // Explicit mode is AOD-style only: no wakeup, screen-on hold or keyguard
        // dismissal. The opt-in simulated mode is the one that wakes the display.
        if (simulatedAod) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.attributes = window.attributes.apply {
                // A simulated AOD is a full-on display, so keep it dim to reduce
                // glare and burn-in. System brightness is restored on finish.
                screenBrightness = 0.08f
            }
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        spectrum = LockScreenSpectrumView(this).apply {
            setBackgroundColor(Color.BLACK)
            isFocusable = true
            setOnClickListener { finish() }
        }
        setContentView(spectrum)
        hideSystemBars()
        if (bridge?.connect(this) != true) {
            finish()
        } else if (simulatedAod) {
            mainHandler.postDelayed(simulatedTimeout, MAX_SIMULATED_DURATION_MS)
        }
    }

    private fun hideSystemBars() {
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemBars()
    }

    override fun onStart() {
        super.onStart()
        if (!::spectrum.isInitialized) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, filter)
        }
        contentResolver.registerContentObserver(
            Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, motionObserver,
        )
        if (simulatedAod && !batteryLowRegistered) {
            ContextCompat.registerReceiver(
                this,
                batteryLowReceiver,
                IntentFilter(Intent.ACTION_BATTERY_LOW),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            batteryLowRegistered = true
        }
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        syncVisibility()
    }

    override fun onPause() {
        resumed = false
        syncVisibility()
        super.onPause()
    }

    override fun onStop() {
        if (::spectrum.isInitialized) {
            unregisterReceiver(screenReceiver)
            contentResolver.unregisterContentObserver(motionObserver)
        }
        if (batteryLowRegistered) {
            unregisterReceiver(batteryLowReceiver)
            batteryLowRegistered = false
        }
        super.onStop()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(simulatedTimeout)
        finishRunnable?.let { mainHandler.removeCallbacks(it) }
        finishRunnable = null
        if (batteryLowRegistered) {
            unregisterReceiver(batteryLowReceiver)
            batteryLowRegistered = false
        }
        bridge?.disconnect(this)
        bridge = null
        super.onDestroy()
    }

    private fun syncVisibility() {
        if (!::spectrum.isInitialized) return
        val interactive = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
        val nextVisible = resumed && interactive && !isFinishing
        val nextMotion = ValueAnimator.areAnimatorsEnabled()
        if (visible == nextVisible && motionAllowed == nextMotion) return
        visible = nextVisible
        motionAllowed = nextMotion
        spectrum.active = visible && motionAllowed && animate
        bridge?.visibility(this, visible, motionAllowed)
    }

    fun renderState(state: Map<String, Any?>) {
        if (!::spectrum.isInitialized) return
        animate = state["animate"] == true
        playing = state["playing"] != false
        supported = state["supported"] != false
        spectrum.active = visible && motionAllowed && animate
        spectrum.configure(state)
        // Available to TalkBack, never painted over the spectrum.
        spectrum.contentDescription = state["contentDescription"] as? String ?: ""
        ViewCompat.replaceAccessibilityAction(spectrum, AccessibilityActionCompat.ACTION_CLICK,
            state["closeLabel"] as? String) { view, _ -> view.performClick() }
        if (state["live"] != true) spectrum.setBars(null)
        if (simulatedAod) {
            if (playing && supported && animate) {
                finishRunnable?.let { mainHandler.removeCallbacks(it) }
                finishRunnable = null
            } else {
                // Let the last real frame fade to black before releasing the
                // display; pause state can arrive while the viewer is stopped.
                if (finishRunnable == null) {
                    finishRunnable = Runnable { finish() }
                    mainHandler.postDelayed(finishRunnable!!, 500L)
                }
            }
        }
    }

    fun isSimulatedAod(): Boolean = simulatedAod

    fun renderBars(bars: List<Float>?) {
        if (::spectrum.isInitialized) spectrum.setBars(bars)
    }

    companion object {
        const val EXTRA_SIMULATED_AOD = "simulated_aod"

        /** Hard cap while the display is held awake; low battery also closes. */
        private const val MAX_SIMULATED_DURATION_MS = 30 * 60 * 1000L
    }
}
