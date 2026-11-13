package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.exp

class VisualizerMotionTest {
    private val start = 1_000_000_000L
    private fun frame(value: Float) = List(48) { value }

    @Test
    fun liveFramesInterpolateOnVsyncInsteadOfJumpingAtCaptureRate() {
        val motion = VisualizerMotion()
        motion.configure("bars", "full", "smooth")
        motion.retarget(frame(.8f), start)
        motion.advance(start)
        assertEquals(.04f, motion.heights[0], .0001f)
        motion.advance(start + 8_333_333)
        val first = motion.heights[0]
        motion.advance(start + 16_666_666)
        val second = motion.heights[0]
        motion.advance(start + 25_000_000)
        assertTrue(first > .04f && second > first && motion.heights[0] > second)
        assertTrue(motion.heights[0] < .8f)
        assertTrue(motion.opacity > 0f && motion.opacity < 1f)
    }

    @Test
    fun usesThePlayerMovementDurationsAndCubicCurves() {
        for ((movement, duration) in listOf("snappy" to 70L, "smooth" to 100L, "bouncy" to 130L)) {
            val motion = VisualizerMotion()
            motion.configure("bars", "full", movement)
            motion.retarget(frame(.8f), start)
            motion.advance(start + duration * 1_000_000)
            assertEquals(.8f, motion.heights[0], .0001f)
        }
        assertEquals(0.0, VisualizerMotion.cubic(0.0, .215, .61, .355, 1.0), 0.0)
        assertEquals(1.0, VisualizerMotion.cubic(1.0, .215, .61, .355, 1.0), 0.0)
        assertTrue(VisualizerMotion.cubic(.7, .175, .885, .32, 1.275) > 1.0)
    }

    @Test
    fun captureFasterThanDisplayNeverResetsTheVsyncClock() {
        val motion = VisualizerMotion()
        motion.configure("bars", "full", "smooth")
        for (i in 0..20) {
            motion.retarget(frame(.5f + i / 100f), start + i * 16_666_666L)
            motion.advance(start + i * 16_666_666L + 8_333_333L)
        }
        assertTrue(motion.heights[0] > .5f)
    }

    @Test
    fun captureAfterDelayedVsyncTimestampDoesNotFreezeMovement() {
        val motion = VisualizerMotion()
        motion.configure("bars", "full", "smooth")
        motion.retarget(frame(.5f), start)
        motion.advance(start)
        for (i in 1..20) {
            val vsync = start + i * 16_666_666L
            // UI thread processes capture before the callback, but after the
            // timestamp Choreographer will supply for that callback.
            motion.retarget(frame(.5f + i / 100f), vsync + 1_000_000)
            motion.advance(vsync)
        }
        assertTrue(motion.heights[0] > .5f)
        assertEquals(1f, motion.opacity, .0001f)
    }

    @Test
    fun pauseEasesLastRealFrameToPureBlackAndStops() {
        val motion = VisualizerMotion()
        motion.configure("blocks", "full", "smooth")
        motion.retarget(frame(.8f), start)
        motion.advance(start + 300_000_000)
        motion.retarget(null, start + 300_000_000)
        assertTrue(motion.advance(start + 400_000_000))
        assertTrue(motion.opacity > 0f && motion.opacity < 1f)
        assertTrue(motion.heights[0] > .04f && motion.heights[0] < .8f)
        assertFalse(motion.advance(start + 660_000_000))
        assertEquals(0f, motion.opacity, 0f)
        assertTrue(motion.trails.all { it == 0f })
    }

    @Test
    fun blockTrailsDecayByElapsedTimeAtAnyDisplayRate() {
        val motion = VisualizerMotion()
        motion.configure("blocks", "full", "smooth")
        motion.retarget(frame(.9f), start)
        motion.advance(start + 300_000_000)
        motion.retarget(frame(.1f), start + 300_000_000)
        motion.advance(start + 400_000_000)
        val before = motion.trails[15]
        motion.advance(start + 500_000_000)
        assertEquals(before * exp(-.6).toFloat(), motion.trails[15], .0001f)
    }

    @Test
    fun frequencyMasksMatchThePlayerBandBoundaries() {
        assertTrue(VisualizerMotion.frequencyMask("full").all { it == 1f })
        val bass = VisualizerMotion.frequencyMask("bass")
        assertEquals(1f, bass[12], 0f)
        assertEquals(.05f, bass[17], .0001f)
        assertEquals(.05f, bass[47], 0f)
        val mid = VisualizerMotion.frequencyMask("mid")
        assertEquals(.05f, mid[0], 0f)
        assertEquals(1f, mid[11], 0f)
        assertEquals(1f, mid[36], 0f)
        assertEquals(.05f, mid[42], 0f)
        val treble = VisualizerMotion.frequencyMask("treble")
        assertEquals(.05f, treble[35], 0f)
        assertEquals(1f, treble[41], 0f)
        val both = VisualizerMotion.frequencyMask("bass_treble")
        assertEquals(1f, both[12], 0f)
        assertEquals(.05f, both[24], 0f)
        assertEquals(1f, both[41], 0f)
    }

    @Test
    fun invalidFramesAndNonfiniteValuesNeverGenerateMovement() {
        val motion = VisualizerMotion()
        motion.retarget(List(47) { .8f }, start)
        assertFalse(motion.advance(start + 500_000_000))
        assertEquals(0f, motion.opacity, 0f)
        motion.retarget(List(48) { if (it == 0) Float.NaN else 2f }, start + 500_000_000)
        motion.advance(start + 800_000_000)
        assertEquals(.04f, motion.heights[0], 0f)
        assertEquals(1f, motion.heights[1], 0f)
    }

    @Test
    fun resetClearsAllTrailsAndNoIdleSimulationRuns() {
        val motion = VisualizerMotion()
        motion.configure("blocks", "full", "bouncy")
        motion.retarget(frame(.8f), start)
        motion.advance(start + 300_000_000)
        motion.reset()
        assertEquals(0f, motion.opacity, 0f)
        assertTrue(motion.heights.all { it == .04f })
        assertTrue(motion.trails.all { it == 0f })
        assertFalse(motion.advance(start + 500_000_000))
        assertTrue(motion.trails.all { it == 0f })
    }
}
