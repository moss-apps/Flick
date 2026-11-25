package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CarMediaIdTest {
    @Test
    fun roundTripsEveryKind() {
        for (kind in CarMediaId.KINDS) {
            val id = CarMediaId(kind, "id 1|2%3", "track/4&5")
            assertEquals(kind, id, CarMediaId.parse(id.encode()))
        }
    }

    @Test
    fun trackIdIsOptional() {
        val parsed = CarMediaId.parse("album|42")

        assertEquals(CarMediaId("album", "42", null), parsed)
        assertEquals("album|42", parsed?.encode())
        assertEquals(CarMediaId("album", "42", null), CarMediaId.parse("album|42|"))
    }

    @Test
    fun partsAreUrlDecoded() {
        assertEquals(
            CarMediaId("playlist", "Road | Trip", "7"),
            CarMediaId.parse("playlist|Road+%7C+Trip|7"),
        )
        assertEquals("album|a%7Cb|t%7C1", CarMediaId("album", "a|b", "t|1").encode())
    }

    @Test
    fun singletonKindsNeedNoId() {
        assertEquals(CarMediaId("favorites", ""), CarMediaId.parse("favorites|"))
        assertEquals(CarMediaId("songs", "", "9"), CarMediaId.parse("songs||9"))
    }

    @Test
    fun rejectsUnknownKinds() {
        for (raw in listOf("track|1", "Album|1", "|1", "../etc|1", "album%00|1", "file|/sdcard")) {
            assertNull(raw, CarMediaId.parse(raw))
        }
    }

    @Test
    fun rejectsCollectionsThatNeedAnIdButHaveNone() {
        for (kind in listOf("album", "artist", "playlist", "folder", "search")) {
            assertNull(kind, CarMediaId.parse("$kind|"))
        }
    }

    @Test
    fun rejectsMalformedShapes() {
        for (raw in listOf(null, "", "album", "album|1|2|3", "|", "album|%zz", "album|%E0%A4%A")) {
            assertNull(raw, CarMediaId.parse(raw))
        }
        assertNull(CarMediaId.parse("album|" + "x".repeat(3000)))
    }
}
