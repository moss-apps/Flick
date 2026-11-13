package com.mossapps.flick

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.view.Choreographer
import android.view.View
import androidx.core.graphics.ColorUtils
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Matches AudioVisualizer's geometry in logical pixels, driven by display vsync. */
internal class LockScreenSpectrumView(context: Context) : View(context), Choreographer.FrameCallback {
    private val motion = VisualizerMotion()
    private val clock = Choreographer.getInstance()
    private var scheduled = false
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val edgeScrim = Paint()
    private var scrimHeight = -1f
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 5f
    }
    private val line = Path()
    private val fill = Path()
    private var colorMode = "monochrome"
    private var albumColor: Int? = null
    private var trackId: String? = null
    private var waveWidth = -1f
    private var waveHeight = -1f
    private var grid: BlockGrid? = null
    private val stale = Runnable { setBars(null) }
    var active = false
        set(value) {
            if (field == value) return
            field = value
            if (!value) {
                clock.removeFrameCallback(this)
                scheduled = false
                removeCallbacks(stale)
                motion.reset()
                invalidate()
            }
        }

    fun configure(state: Map<String, Any?>) {
        val track = state["trackId"] as? String
        if (trackId != track) {
            trackId = track
            motion.reset()
            removeCallbacks(stale)
        }
        val style = state["animationStyle"] as? String ?: "bars"
        val color = state["colorMode"] as? String ?: "monochrome"
        val album = (state["albumColor"] as? Number)?.toInt()
        if (style != motion.style || colorMode != color || albumColor != album) {
            colorMode = color
            albumColor = album
            waveWidth = -1f
            grid = null
        }
        motion.configure(style, state["frequencyMode"] as? String ?: "full",
            state["movementMode"] as? String ?: "bouncy")
        if (active) schedule()
    }

    fun setBars(frame: List<Float>?) {
        if (!active) return
        removeCallbacks(stale)
        val valid = frame?.takeIf { it.size == VisualizerMotion.BAR_COUNT }
        motion.retarget(valid, System.nanoTime())
        if (valid != null) postDelayed(stale, 300)
        schedule()
    }

    private fun schedule() {
        if (!active || scheduled) return
        scheduled = true
        clock.postFrameCallback(this)
    }

    override fun doFrame(frameTimeNanos: Long) {
        scheduled = false
        if (!active) return
        val running = motion.advance(frameTimeNanos)
        invalidate()
        if (running) schedule()
    }

    override fun onDetachedFromWindow() {
        active = false
        super.onDetachedFromWindow()
    }

    private fun color(t: Float): Int = when {
        colorMode == "rainbow" -> ColorUtils.HSLToColor(floatArrayOf(t * 300f, .8f, .65f))
        colorMode == "album_art" && albumColor != null -> {
            val hsl = FloatArray(3)
            ColorUtils.colorToHSL(albumColor!!, hsl)
            hsl[1] = if (hsl[1] < .05f) 0f else (hsl[1] * 1.35f + .2f).coerceIn(.72f, 1f)
            hsl[2] = .56f + t * .1f
            ColorUtils.HSLToColor(hsl)
        }
        else -> (255 * (1 - t * .4f)).roundToInt().let { Color.rgb(it, it, it) }
    }

    private fun tint(t: Float, alpha: Float) {
        paint.color = color(t)
        paint.alpha = (255 * alpha * motion.opacity).roundToInt().coerceIn(0, 255)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!active || motion.opacity <= 0f || width == 0 || height == 0) return
        val density = resources.displayMetrics.density
        val w = width / density
        val h = height / density
        canvas.save()
        canvas.scale(density, density)
        when (motion.style) {
            "blocks" -> {
                if (grid?.width != w || grid?.height != h) grid = BlockGrid(w, h, ::color)
                grid!!.draw(canvas, motion)
            }
            "wave", "curved_wave" -> drawWave(canvas, w, h, motion.style == "curved_wave")
            "mirrored" -> drawMirrored(canvas, w, h)
            "dots" -> drawDots(canvas, w, h)
            else -> drawBars(canvas, w, h)
        }
        // The immersive player's quiet top/bottom edges, but black (never an
        // album-tinted background), so every unlit pixel remains true black.
        if (scrimHeight != h) {
            scrimHeight = h
            edgeScrim.shader = LinearGradient(0f, 0f, 0f, h,
                intArrayOf(0xb3000000.toInt(), 0x59000000, 0, 0, 0x4d000000, 0xbf000000.toInt()),
                floatArrayOf(0f, .12f, .28f, .62f, .82f, 1f), Shader.TileMode.CLAMP)
        }
        canvas.drawRect(0f, 0f, w, h, edgeScrim)
        canvas.restore()
    }

    private fun bar(canvas: Canvas, x: Float, y: Float, w: Float, h: Float,
                    t: Float, radius: Float, alpha: Float, halo: Float, stroke: Float) {
        tint(t, halo)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = stroke
        canvas.drawRoundRect(x, y, x + w, y + h, radius, radius, paint)
        tint(t, alpha)
        paint.style = Paint.Style.FILL
        canvas.drawRoundRect(x, y, x + w, y + h, radius, radius, paint)
    }

    private fun drawBars(canvas: Canvas, w: Float, h: Float) {
        val spacing = min(2.5f, w / 96)
        val barWidth = (w - 47 * spacing) / 48
        for (i in 0 until 48) {
            val barHeight = motion.heights[i] * h * .88f
            bar(canvas, i * (barWidth + spacing), h - barHeight, barWidth, barHeight,
                i / 47f, 2f, .82f, .10f, 3f)
        }
    }

    private fun drawMirrored(canvas: Canvas, w: Float, h: Float) {
        val spacing = min(2f, w * .48f / 48)
        val barWidth = (w * .48f - 23 * spacing) / 24
        for (i in 0 until 24) {
            val barHeight = (motion.heights[23 - i] + motion.heights[24 + i]) / 2 * h * .42f
            val offset = i * (barWidth + spacing) + barWidth / 2
            val left = w / 2 - offset - barWidth / 2
            val right = w / 2 + offset - barWidth / 2
            bar(canvas, left, h / 2 - barHeight, barWidth, barHeight, i / 23f, 1.5f, .78f, .08f, 2f)
            bar(canvas, right, h / 2 - barHeight, barWidth, barHeight, i / 23f, 1.5f, .78f, .08f, 2f)
            bar(canvas, left, h / 2, barWidth, barHeight, i / 23f, 1.5f, .78f, .08f, 2f)
            bar(canvas, right, h / 2, barWidth, barHeight, i / 23f, 1.5f, .78f, .08f, 2f)
        }
    }

    private fun drawDots(canvas: Canvas, w: Float, h: Float) {
        val maxRadius = h * .38f
        val minRadius = maxRadius * .04f
        paint.style = Paint.Style.FILL
        for (i in 0 until 48) {
            val x = (i + .5f) * w / 48
            val radius = (motion.heights[i] * (maxRadius - minRadius) + minRadius).coerceIn(minRadius, maxRadius)
            tint(i / 47f, .12f)
            canvas.drawCircle(x, h / 2, radius + 1.5f, paint)
            tint(i / 47f, .85f)
            canvas.drawCircle(x, h / 2, radius, paint)
        }
    }

    private fun ensureWaveShaders(w: Float, h: Float, curved: Boolean) {
        if (waveWidth == w && waveHeight == h) return
        waveWidth = w
        waveHeight = h
        fun rainbow(alpha: Float) = LinearGradient(0f, 0f, w, 0f,
            IntArray(7) { ColorUtils.setAlphaComponent(color(it / 6f), (alpha * 255).roundToInt()) },
            null, Shader.TileMode.CLAMP)
        if (colorMode == "rainbow") {
            fillPaint.shader = rainbow(if (curved) .35f else .40f)
            linePaint.shader = rainbow(.95f)
            glowPaint.shader = rainbow(.12f)
            linePaint.color = Color.WHITE
            glowPaint.color = Color.WHITE
        } else {
            val maxHeight = h * if (curved) .50f else .44f
            fillPaint.shader = LinearGradient(0f, h - maxHeight, 0f, h,
                ColorUtils.setAlphaComponent(color(if (curved) .3f else 0f), ((if (curved) .70f else .85f) * 255).roundToInt()),
                ColorUtils.setAlphaComponent(color(if (curved) .7f else 1f), ((if (curved) .08f else .15f) * 255).roundToInt()), Shader.TileMode.CLAMP)
            linePaint.shader = null
            glowPaint.shader = null
            linePaint.color = ColorUtils.setAlphaComponent(color(.5f), (255 * .95f).roundToInt())
            glowPaint.color = ColorUtils.setAlphaComponent(color(.5f), (255 * .12f).roundToInt())
        }
        linePaint.strokeWidth = if (curved) 2.2f else 1.8f
    }

    private fun drawWave(canvas: Canvas, w: Float, h: Float, curved: Boolean) {
        ensureWaveShaders(w, h, curved)
        val maxHeight = h * if (curved) .50f else .44f
        fun y(i: Int) = h - motion.heights[i] * maxHeight
        line.reset()
        if (curved) {
            val spacing = w / 47
            line.moveTo(0f, y(0))
            for (i in 0 until 47) {
                val before = max(0, i - 1)
                val after = min(47, i + 2)
                line.cubicTo(i * spacing + (i + 1 - before) * spacing / 6, y(i) + (y(i + 1) - y(before)) / 6,
                    (i + 1) * spacing - (after - i) * spacing / 6, y(i + 1) - (y(after) - y(i)) / 6,
                    (i + 1) * spacing, y(i + 1))
            }
            fill.set(line)
            fill.lineTo(w, h)
            fill.lineTo(0f, h)
        } else {
            fill.reset()
            fill.moveTo(0f, h)
            for (i in 0 until 48) {
                val x = (i + .5f) * w / 48
                fill.lineTo(x, y(i))
                if (i == 0) line.moveTo(x, y(i)) else line.lineTo(x, y(i))
            }
            fill.lineTo(w, h)
        }
        fill.close()
        fillPaint.alpha = (255 * motion.opacity).roundToInt()
        linePaint.alpha = (255 * motion.opacity * if (colorMode == "rainbow") 1f else .95f).roundToInt()
        glowPaint.alpha = (255 * motion.opacity * if (colorMode == "rainbow") 1f else .12f).roundToInt()
        canvas.drawPath(fill, fillPaint)
        if (curved) canvas.drawPath(line, glowPaint)
        canvas.drawPath(line, linePaint)
        if (!curved) {
            paint.style = Paint.Style.FILL
            for (i in 0 until 48 step 2) {
                tint(i / 47f, .70f)
                canvas.drawCircle((i + .5f) * w / 48, y(i), 1.5f, paint)
            }
        }
    }
}

/** One tiny nearest-neighbor bitmap plus a cached grid, not thousands of draw calls. */
private class BlockGrid(val width: Float, val height: Float, color: (Float) -> Int) {
    private val pitch = min(6f, min(width, height * .88f))
    private val columns = max(1, floor(width / pitch).toInt())
    private val rows = max(1, floor(height * .88f / pitch).toInt())
    private val bitmap = Bitmap.createBitmap(columns, rows, Bitmap.Config.ARGB_8888)
    private val pixels = IntArray(columns * rows)
    private val rgb = IntArray(columns)
    private val destination = RectF((width - columns * pitch) / 2, height - rows * pitch,
        (width + columns * pitch) / 2, height)
    private val paint = Paint().apply { isFilterBitmap = false }
    private val gutters = Path()
    private val gutterPaint = Paint().apply {
        this.color = Color.BLACK
        style = Paint.Style.STROKE
        strokeWidth = min(2f, pitch * .25f)
    }

    init {
        val stops = IntArray(min(7, max(2, columns))) { color(it.toFloat() / (min(7, max(2, columns)) - 1)) }
        for (column in 0 until columns) {
            val t = if (columns > 1) column.toFloat() / (columns - 1) else 0f
            val scaled = t * (stops.size - 1)
            val index = min(scaled.toInt(), stops.size - 2)
            rgb[column] = ColorUtils.blendARGB(stops[index], stops[index + 1], scaled - index) and 0xffffff
        }
        for (column in 0..columns) {
            val x = destination.left + column * pitch
            gutters.moveTo(x, destination.top)
            gutters.lineTo(x, destination.bottom)
        }
        for (row in 0..rows) {
            val y = destination.top + row * pitch
            gutters.moveTo(destination.left, y)
            gutters.lineTo(destination.right, y)
        }
    }

    fun draw(canvas: Canvas, motion: VisualizerMotion) {
        for (column in 0 until columns) {
            val source = column * 48 / columns
            val litRows = ceil(motion.heights[source] * rows).toInt().coerceIn(0, rows)
            for (row in 0 until rows) {
                val intensity = if (row < litRows) 1f else motion.trails[source * 20 + row * 20 / rows]
                val alpha = (intensity * (.88f - row.toFloat() / rows * .30f) * 255 * motion.opacity).roundToInt().coerceIn(0, 255)
                pixels[(rows - 1 - row) * columns + column] = (alpha shl 24) or rgb[column]
            }
        }
        bitmap.setPixels(pixels, 0, columns, 0, 0, columns, rows)
        canvas.drawBitmap(bitmap, null, destination, paint)
        canvas.drawPath(gutters, gutterPaint)
    }
}
