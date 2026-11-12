package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Test

class VisualizerCaptureRateTest {
    @Test
    fun requestsThirtyFramesPerSecondInMilliHertz() {
        val rateMilliHz = visualizerCaptureRateMilliHz(60_000)
        assertEquals(30_000, rateMilliHz)
        // 30 mHz would yield a frame every 33 seconds instead of every 33 ms.
        assertEquals(1000.0 / 30.0, 1_000_000.0 / rateMilliHz, 0.001)
    }

    @Test
    fun respectsLowerDeviceCaptureRateLimits() {
        assertEquals(20_000, visualizerCaptureRateMilliHz(20_000))
    }

    @Test
    fun supportsDevicesWhoseLimitMatchesTheTarget() {
        assertEquals(30_000, visualizerCaptureRateMilliHz(30_000))
    }
}
