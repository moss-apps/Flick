package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CarSessionQueueTest {
    private fun track(id: Any, title: String = "T$id", artist: String? = "A", art: String? = null) =
        mapOf("id" to id, "title" to title, "artist" to artist, "art" to art)

    @Test
    fun idsArePositionsInTheCombinedList() {
        val queue = parseSessionQueue(
            mapOf(
                "fromYou" to listOf(track(10), track(11)),
                "fromContext" to listOf(track(12, art = "/x/a.jpg")),
                "contextName" to "Kind of Blue",
            )
        )

        assertEquals("Kind of Blue", queue.title)
        assertEquals(listOf(0L, 1L, 2L), queue.entries.map { it.id })
        assertEquals(listOf("10", "11", "12"), queue.entries.map { it.mediaId })
        assertEquals("T12", queue.entries[2].title)
        assertEquals("A", queue.entries[2].subtitle)
        assertEquals("/x/a.jpg", queue.entries[2].artPath)
        assertNull(queue.entries[0].artPath)
    }

    @Test
    fun anUnreadableEntryKeepsItsSlotSoLaterIdsStayAligned() {
        val queue = parseSessionQueue(
            mapOf(
                "fromYou" to listOf(track(1), "junk", mapOf("title" to "no id")),
                "fromContext" to listOf(track(4)),
            )
        )

        assertEquals(listOf(0L, 3L), queue.entries.map { it.id })
        assertEquals(listOf("1", "4"), queue.entries.map { it.mediaId })
    }

    @Test
    fun theLimitCountsPositionsAcrossBothLists() {
        val queue = parseSessionQueue(
            mapOf(
                "fromYou" to (1..3).map { track(it) },
                "fromContext" to (4..9).map { track(it) },
            ),
            limit = 5,
        )

        assertEquals((0L..4L).toList(), queue.entries.map { it.id })
    }

    @Test
    fun missingOrBlankFieldsGetDefaults() {
        val queue = parseSessionQueue(
            mapOf("fromContext" to listOf(track(7, title = " ", artist = "")), "contextName" to " ")
        )

        assertEquals("Up next", queue.title)
        assertEquals("Unknown", queue.entries.single().title)
        assertNull(queue.entries.single().subtitle)
    }

    @Test
    fun anythingButAMapIsAnEmptyQueue() {
        for (raw in listOf(null, "x", 3, listOf(1))) {
            assertEquals(SessionQueue("Up next", emptyList()), parseSessionQueue(raw))
        }
        assertEquals(
            SessionQueue("Up next", emptyList()),
            parseSessionQueue(mapOf("fromYou" to "oops", "fromContext" to null)),
        )
    }

    @Test
    fun numericTrackIdsBecomeStrings() {
        val queue = parseSessionQueue(mapOf("fromContext" to listOf(track(123456789012L))))

        assertEquals("123456789012", queue.entries.single().mediaId)
    }
}
