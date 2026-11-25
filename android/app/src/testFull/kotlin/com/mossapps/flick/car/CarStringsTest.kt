package com.mossapps.flick.car

import org.junit.Assert.assertEquals
import org.junit.Test

class CarStringsTest {
    @Test
    fun durationsAreMinutesAndSecondsThenHours() {
        assertEquals("", CarStrings.duration(0))
        assertEquals("", CarStrings.duration(-1))
        assertEquals("0:59", CarStrings.duration(59_999))
        assertEquals("1:00", CarStrings.duration(60_000))
        assertEquals("9:22", CarStrings.duration(562_000))
        assertEquals("59:59", CarStrings.duration(3_599_000))
        assertEquals("1:00:00", CarStrings.duration(3_600_000))
        assertEquals("2:03:04", CarStrings.duration(7_384_000))
    }

    @Test
    fun linesJoinWithADotAndSkipBlanks() {
        assertEquals("Artist · 24/96 FLAC", CarStrings.dotted("Artist", "24/96 FLAC"))
        assertEquals("Artist", CarStrings.dotted("Artist", null, " "))
        assertEquals("", CarStrings.dotted(null, ""))
    }

    @Test
    fun countsAndLabels() {
        assertEquals("1 song", CarStrings.songCount(1))
        assertEquals("0 songs", CarStrings.songCount(0))
        assertEquals("4812 songs", CarStrings.songCount(4812))
        assertEquals("Shuffle all · 4812 songs", CarStrings.shuffleAll(4812))
        assertEquals("Shuffle all", CarStrings.shuffleAll(null))
        assertEquals("Shuffle all 450 songs", CarStrings.shuffleAllSongs(450))
        assertEquals("Up next · 14", CarStrings.upNextCount(14))
        assertEquals("Next from Kind of Blue", CarStrings.nextFrom("Kind of Blue"))
        assertEquals("Next up", CarStrings.nextFrom(null))
        assertEquals("Next up", CarStrings.nextFrom("  "))
    }
}
