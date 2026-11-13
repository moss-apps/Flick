package com.mossapps.flick

import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.max

/** Native counterpart of AudioVisualizer's live-frame interpolation, not an audio generator. */
internal class VisualizerMotion {
    val heights = FloatArray(BAR_COUNT) { MIN_HEIGHT }
    val trails = FloatArray(BAR_COUNT * BLOCK_ROWS)
    var opacity = 0f
        private set
    var style = "bars"
        private set
    private val current = FloatArray(BAR_COUNT) { MIN_HEIGHT }
    private val start = FloatArray(BAR_COUNT) { MIN_HEIGHT }
    private val target = FloatArray(BAR_COUNT) { MIN_HEIGHT }
    private var weights = frequencyMask("full")
    private var frequency = "full"
    private var movement = "bouncy"
    private var startedAt = 0L
    private var duration = 130_000_000L
    private var settling = true
    private var alphaStart = 0f
    private var alphaTarget = 0f
    private var alphaStartedAt = 0L
    private var lastFrame: Long? = null

    fun configure(style: String, frequency: String, movement: String) {
        if (this.style != style || this.frequency != frequency) trails.fill(0f)
        this.style = style
        this.movement = movement
        if (this.frequency != frequency) {
            this.frequency = frequency
            weights = frequencyMask(frequency)
        }
    }

    fun retarget(frame: List<Float>?, now: Long) {
        // Like Flutter's continuous controller clock, anchor to the last vsync
        // while running. A capture handled just after a delayed vsync timestamp
        // must not turn every display frame into a zero-time first tick.
        val anchor = lastFrame ?: now
        val valid = frame?.size == BAR_COUNT
        var changed = false
        for (i in 0 until BAR_COUNT) {
            val raw = if (valid) frame!![i] else MIN_HEIGHT
            val value = if (raw.isFinite()) raw.coerceIn(MIN_HEIGHT, 1f) else MIN_HEIGHT
            if (target[i] != value) changed = true
            target[i] = value
        }
        if (changed) {
            current.copyInto(start)
            startedAt = anchor
            settling = !valid
            duration = if (settling) 360_000_000L else when (movement) {
                "snappy" -> 70_000_000L
                "smooth" -> 100_000_000L
                else -> 130_000_000L
            }
        }
        val nextAlpha = if (valid) 1f else 0f
        if (alphaTarget != nextAlpha) {
            alphaStart = opacity
            alphaTarget = nextAlpha
            alphaStartedAt = anchor
        }
    }

    /** Returns false once heights, trails and the entrance/exit fade have settled. */
    fun advance(now: Long): Boolean {
        val delta = lastFrame?.let { max(0.0, (now - it) / 1e9) } ?: 0.0
        lastFrame = now
        val fraction = ((now - startedAt).toDouble() / duration).coerceIn(0.0, 1.0)
        val progress = when {
            settling || movement == "smooth" -> cubic(fraction, .215, .61, .355, 1.0)
            movement == "snappy" -> cubic(fraction, .25, .46, .45, .94)
            else -> cubic(fraction, .175, .885, .32, 1.275)
        }
        for (i in 0 until BAR_COUNT) {
            current[i] = (start[i] + (target[i] - start[i]) * progress).toFloat().coerceIn(MIN_HEIGHT, 1f)
            val masked = (current[i] * weights[i]).coerceIn(MIN_HEIGHT, 1f)
            heights[i] = if (masked < .06f) MIN_HEIGHT else masked
        }
        var trailsSettled = true
        if (style == "blocks") {
            val decay = exp(-delta * 6.0).toFloat()
            for (i in 0 until BAR_COUNT) {
                val litRows = ceil(heights[i] * BLOCK_ROWS).toInt()
                for (row in 0 until BLOCK_ROWS) {
                    val index = i * BLOCK_ROWS + row
                    val alpha = if (row < litRows) 1f else trails[index] * decay
                    trails[index] = if (alpha < .01f) 0f else alpha
                    if (row >= litRows && alpha >= .01f) trailsSettled = false
                }
            }
        }
        val alphaDuration = if (alphaTarget == 1f) 300_000_000.0 else 360_000_000.0
        val alphaFraction = ((now - alphaStartedAt) / alphaDuration).coerceIn(0.0, 1.0)
        opacity = (alphaStart + (alphaTarget - alphaStart) * cubic(alphaFraction, .215, .61, .355, 1.0)).toFloat()
        if (alphaTarget == 0f && alphaFraction >= 1.0) {
            trails.fill(0f)
            lastFrame = null
            return false // Fully black: no idle vsync loop, even for block trails.
        }
        val running = fraction < 1.0 || !trailsSettled || alphaFraction < 1.0
        if (!running) lastFrame = null
        return running
    }

    fun reset() {
        heights.fill(MIN_HEIGHT)
        current.fill(MIN_HEIGHT)
        start.fill(MIN_HEIGHT)
        target.fill(MIN_HEIGHT)
        trails.fill(0f)
        opacity = 0f
        alphaStart = 0f
        alphaTarget = 0f
        lastFrame = null
        startedAt = 0L
        alphaStartedAt = 0L
        settling = true
    }

    companion object {
        const val BAR_COUNT = 48
        const val BLOCK_ROWS = 20
        const val MIN_HEIGHT = .04f

        // Flutter's Cubic curves invert x before evaluating y (not a polynomial approximation).
        internal fun cubic(t: Double, x1: Double, y1: Double, x2: Double, y2: Double): Double {
            if (t <= 0.0 || t >= 1.0) return t.coerceIn(0.0, 1.0)
            fun axis(u: Double, a: Double, b: Double) = 3 * a * (1 - u) * (1 - u) * u + 3 * b * (1 - u) * u * u + u * u * u
            var low = 0.0
            var high = 1.0
            repeat(20) {
                val middle = (low + high) / 2
                if (axis(middle, x1, x2) < t) low = middle else high = middle
            }
            return axis((low + high) / 2, y1, y2)
        }

        internal fun frequencyMask(mode: String): FloatArray {
            val weights = FloatArray(BAR_COUNT) { 1f }
            fun ramp(start: Int, end: Int, up: Boolean) {
                for (i in start..end) {
                    val t = (i - start).toFloat() / (end - start)
                    weights[i] = if (up) .05f + t * .95f else 1f - t * .95f
                }
            }
            when (mode) {
                "bass" -> { ramp(12, 17, false); weights.fill(.05f, 18) }
                "mid" -> { ramp(0, 11, true); ramp(36, 41, false); weights.fill(.05f, 42) }
                "treble" -> { weights.fill(.05f, 0, 36); ramp(36, 41, true) }
                "bass_treble" -> { ramp(12, 23, false); weights.fill(.05f, 24, 36); ramp(36, 41, true) }
            }
            return weights
        }
    }
}
