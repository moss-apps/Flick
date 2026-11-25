package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CarArtCacheTest {
    private fun entries(count: Int) = (1..count).map { "f$it" to it.toLong() }

    @Test
    fun belowTheLimitNothingIsEvicted() {
        assertTrue(CarArtCache.selectEvictions(entries(600), limit = 600, keep = 500).isEmpty())
        assertTrue(CarArtCache.selectEvictions(emptyList(), limit = 600, keep = 500).isEmpty())
    }

    @Test
    fun overTheLimitTheOldestGoDownToKeep() {
        val doomed = CarArtCache.selectEvictions(entries(610), limit = 600, keep = 500)

        assertEquals(110, doomed.size)
        assertEquals((1..110).map { "f$it" }, doomed)
    }

    @Test
    fun ageDecidesNotListOrder() {
        val shuffled = listOf("new" to 30L, "old" to 10L, "mid" to 20L)

        assertEquals(listOf("old", "mid"), CarArtCache.selectEvictions(shuffled, limit = 2, keep = 1))
    }
}
