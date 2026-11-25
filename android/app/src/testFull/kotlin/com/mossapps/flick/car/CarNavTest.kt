package com.mossapps.flick.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CarNavTest {
    @Test
    fun theHostAllowsFiveScreens() {
        assertEquals(5, CarNav.STACK_LIMIT)
    }

    @Test
    fun aSixthPushPopsToTheRootFirst() {
        for (size in 0..4) assertFalse("size $size has room", CarNav.mustResetBeforePush(size))
        assertTrue(CarNav.mustResetBeforePush(5))
        assertTrue(CarNav.mustResetBeforePush(6))
    }

    @Test
    fun aFenceAcceptsOnlyTheLatestRequestUntilClosed() {
        val fence = Fence()
        val first = fence.next()
        assertTrue(fence.accepts(first))

        val second = fence.next()
        assertFalse("a newer request retires the older answer", fence.accepts(first))
        assertTrue(fence.accepts(second))

        fence.close()
        assertTrue(fence.isClosed)
        assertFalse("nothing is accepted after the screen is destroyed", fence.accepts(second))
        assertFalse(fence.accepts(fence.next()))
    }
}
