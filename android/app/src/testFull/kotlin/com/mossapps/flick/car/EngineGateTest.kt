package com.mossapps.flick.car

import com.mossapps.flick.CarChannelException
import com.mossapps.flick.car.model.CarStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineGateTest {
    @Test
    fun aReadyAnswerIsReady() {
        assertEquals(Probe.READY, EngineGate.classify(Result.success(CarStatus(true, 10))))
    }

    @Test
    fun anAnswerThatIsNotReadyYetWaits() {
        assertEquals(Probe.WAIT, EngineGate.classify(Result.success(CarStatus(false, 0))))
    }

    @Test
    fun notImplementedAndTimeoutMeanDartIsStillStarting() {
        for (code in listOf("notImplemented", "timeout")) {
            val failure = Result.failure<CarStatus>(CarChannelException(code, "x"))
            assertEquals(code, Probe.WAIT, EngineGate.classify(failure))
        }
    }

    @Test
    fun anyOtherFailureIsNotSomethingPollingFixes() {
        assertEquals(Probe.FAILED, EngineGate.classify(Result.failure(CarChannelException("car_error", "boom"))))
        assertEquals(Probe.FAILED, EngineGate.classify(Result.failure(IllegalStateException("engine"))))
        assertFalse(EngineGate.isStarting(RuntimeException("timeout")))
        assertTrue(EngineGate.isStarting(CarChannelException("timeout", null)))
    }

    @Test
    fun pollsEvery700msAndGivesUpAfter12s() {
        assertEquals(700L, EngineGate.POLL_INTERVAL_MS)
        assertEquals(12_000L, EngineGate.GIVE_UP_MS)
        assertFalse(EngineGate.gaveUp(0))
        assertFalse(EngineGate.gaveUp(11_999))
        assertTrue(EngineGate.gaveUp(12_000))
        assertTrue(EngineGate.gaveUp(30_000))
    }
}
