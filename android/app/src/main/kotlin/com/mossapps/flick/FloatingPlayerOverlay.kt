package com.mossapps.flick

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.AnticipateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs

class FloatingPlayerOverlay(private val context: Context) {

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isShowing = false
    private var albumArt: Bitmap? = null
    private var isPlaying: Boolean = false

    private var bubbleView: FrameLayout? = null
    private var artView: ImageView? = null
    private var feedbackContainer: View? = null
    private var feedbackIcon: ImageView? = null

    private var params: WindowManager.LayoutParams = createParams()
    private var snapAnimator: ValueAnimator? = null

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var downTime = 0L
    private var isDragging = false
    private var hasMoved = false

    private var tapCount = 0
    private val tapTimeoutRunnable = Runnable { flushTaps() }
    private val longPressRunnable = Runnable {
        if (!hasMoved) {
            openApp()
            showActionFeedback(R.drawable.ic_notification)
        }
    }

    private val density = context.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()
    private val touchSlop = 8f * density

    companion object {
        private const val BUBBLE_SIZE = 64
        private const val TAP_TIMEOUT = 400L
        private const val LONG_PRESS = 500L
    }

    private fun createParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(120)
        }
    }

    fun show(
        title: String,
        artist: String,
        art: Bitmap?,
        playing: Boolean,
        duration: Long = 0,
        position: Long = 0
    ) {
        this.albumArt = art
        this.isPlaying = playing
        mainHandler.post {
            if (isShowing) {
                refreshViews()
                return@post
            }
            isShowing = true
            val view = buildBubble()
            bubbleView = view
            try {
                windowManager.addView(view, params)
                animateAppear(view)
            } catch (e: Exception) {
                isShowing = false
                bubbleView = null
                artView = null
                feedbackContainer = null
                feedbackIcon = null
            }
        }
    }

    fun update(
        title: String,
        artist: String,
        art: Bitmap?,
        playing: Boolean,
        duration: Long = 0,
        position: Long = 0
    ) {
        this.albumArt = art
        this.isPlaying = playing
        mainHandler.post { refreshViews() }
    }

    fun hide() {
        mainHandler.post {
            val view = bubbleView
            if (view != null) {
                animateDisappear(view) {
                    removeAllViews()
                }
            } else {
                removeAllViews()
            }
        }
    }

    val shown: Boolean get() = isShowing

    private fun removeAllViews() {
        snapAnimator?.cancel()
        bubbleView?.let { removeViewSafe(it) }
        bubbleView = null
        artView = null

        feedbackContainer = null
        feedbackIcon = null
        isShowing = false
    }

    private fun refreshViews() {
        val art = albumArt
        if (art != null) {
            artView?.setImageBitmap(art)
        }
    }

    private fun buildBubble(): FrameLayout {
        val frame = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(dp(BUBBLE_SIZE), dp(BUBBLE_SIZE))
            setCircularOutline()
        }

        val art = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            val b = albumArt
            if (b != null) setImageBitmap(b) else setBackgroundColor(0xFF2D2D3A.toInt())
            setCircularOutline()
            layoutParams = FrameLayout.LayoutParams(dp(BUBBLE_SIZE), dp(BUBBLE_SIZE)).apply {
                gravity = Gravity.CENTER
            }
        }
        artView = art
        frame.addView(art)

        // Action feedback overlay
        val fbContainer = FrameLayout(context).apply {
            visibility = View.GONE
            setCircularOutline()
            layoutParams = FrameLayout.LayoutParams(dp(BUBBLE_SIZE), dp(BUBBLE_SIZE)).apply {
                gravity = Gravity.CENTER
            }
        }
        val fbBg = View(context).apply {
            setBackgroundColor(0xAA000000.toInt())
            setCircularOutline()
            layoutParams = FrameLayout.LayoutParams(dp(BUBBLE_SIZE), dp(BUBBLE_SIZE))
        }
        val fbIcon = ImageView(context).apply {
            setColorFilter(Color.WHITE)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = FrameLayout.LayoutParams(dp(26), dp(26)).apply {
                gravity = Gravity.CENTER
            }
        }
        fbContainer.addView(fbBg)
        fbContainer.addView(fbIcon)
        feedbackContainer = fbContainer
        feedbackIcon = fbIcon
        frame.addView(fbContainer)

        frame.setOnTouchListener(dragTouchListener)
        return frame
    }

    private val dragTouchListener = View.OnTouchListener { v, event ->
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                snapAnimator?.cancel()
                initialX = params.x
                initialY = params.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                downTime = System.currentTimeMillis()
                isDragging = false
                hasMoved = false
                v.animate().scaleX(0.95f).scaleY(0.95f).setDuration(100).start()
                mainHandler.postDelayed(longPressRunnable, LONG_PRESS)
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                if (!hasMoved && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                    isDragging = true
                    hasMoved = true
                    mainHandler.removeCallbacks(longPressRunnable)
                }
                if (isDragging) {
                    params.x = clampX(initialX + dx.toInt())
                    params.y = (initialY + dy.toInt()).coerceIn(
                        0,
                        (getScreenHeight() - dp(BUBBLE_SIZE)).coerceAtLeast(0)
                    )
                    updateLayout(v)
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                v.animate().scaleX(1f).scaleY(1f).setDuration(150).start()
                mainHandler.removeCallbacks(longPressRunnable)

                if (isDragging) {
                    snapToEdge(v)
                } else if (!hasMoved) {
                    handleTap()
                }
            }
        }
        true
    }

    private fun handleTap() {
        tapCount++
        mainHandler.removeCallbacks(tapTimeoutRunnable)
        if (tapCount >= 3) {
            broadcast(MusicNotificationService.ACTION_PREVIOUS)
            showActionFeedback(R.drawable.ic_previous)
            tapCount = 0
        } else {
            mainHandler.postDelayed(tapTimeoutRunnable, TAP_TIMEOUT)
        }
    }

    private fun flushTaps() {
        when (tapCount) {
            1 -> {
                broadcast(MusicNotificationService.ACTION_PLAY_PAUSE)
                val icon = if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
                showActionFeedback(icon)
                isPlaying = !isPlaying
            }
            2 -> {
                broadcast(MusicNotificationService.ACTION_NEXT)
                showActionFeedback(R.drawable.ic_next)
            }
        }
        tapCount = 0
    }

    private fun showActionFeedback(iconRes: Int) {
        feedbackIcon?.setImageResource(iconRes)
        feedbackContainer?.let { overlay ->
            overlay.animate().cancel()
            overlay.alpha = 0f
            overlay.visibility = View.VISIBLE
            overlay.animate()
                .alpha(1f)
                .setDuration(100)
                .withEndAction {
                    overlay.animate()
                        .alpha(0f)
                        .setDuration(200)
                        .setStartDelay(300)
                        .withEndAction {
                            overlay.visibility = View.GONE
                        }
                        .start()
                }
                .start()
        }
    }

    private fun snapToEdge(v: View) {
        val w = getScreenWidth()
        val viewW = dp(BUBBLE_SIZE)
        val center = params.x + viewW / 2
        val target = if (center < w / 2) dp(4) else (w - viewW - dp(4)).coerceAtLeast(dp(4))
        snapAnimator?.cancel()
        ValueAnimator.ofInt(params.x, target).apply {
            duration = 250
            interpolator = OvershootInterpolator(1.2f)
            addUpdateListener {
                params.x = it.animatedValue as Int
                updateLayout(v)
            }
            snapAnimator = this
            start()
        }
    }

    private fun animateAppear(view: View) {
        view.scaleX = 1f
        view.scaleY = 1f
        view.alpha = 1f
    }

    private fun animateDisappear(view: View, onComplete: () -> Unit) {
        view.animate()
            .scaleX(0f)
            .scaleY(0f)
            .alpha(0f)
            .setDuration(200)
            .setInterpolator(AnticipateInterpolator())
            .withEndAction { onComplete() }
            .start()
    }

    private fun updateLayout(v: View) {
        try {
            windowManager.updateViewLayout(v, params)
        } catch (_: Exception) {
        }
    }

    private fun removeViewSafe(v: View) {
        try {
            windowManager.removeView(v)
        } catch (_: Exception) {
        }
    }

    private fun clampX(x: Int): Int {
        val w = getScreenWidth()
        val viewW = dp(BUBBLE_SIZE)
        return x.coerceIn(dp(4), (w - viewW - dp(4)).coerceAtLeast(dp(4)))
    }

    private fun getScreenWidth(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager.maximumWindowMetrics.bounds.width()
        } else {
            val m = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(m)
            m.widthPixels
        }
    }

    private fun getScreenHeight(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager.maximumWindowMetrics.bounds.height()
        } else {
            val m = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(m)
            m.heightPixels
        }
    }

    private fun broadcast(action: String) {
        context.sendBroadcast(Intent(action).apply { setPackage(context.packageName) })
    }

    private fun openApp() {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun View.setCircularOutline() {
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setOval(0, 0, view.width, view.height)
            }
        }
        clipToOutline = true
    }
}
