package com.mossapps.flick.car

import com.mossapps.flick.car.model.CarLoop
import com.mossapps.flick.car.model.CarModelException
import com.mossapps.flick.car.model.CarModels
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** The plain maps and lists Dart answers with (docs/ANDROID_AUTO_DESIGN.md, 4.3). */
class CarModelsTest {
    private fun trackMap(id: Any? = "t1", extra: Map<String, Any?> = emptyMap()): Map<String, Any?> =
        mapOf(
            "id" to id,
            "title" to "So What",
            "artist" to "Miles Davis",
            "album" to "Kind of Blue",
            "art" to "/data/art/a.jpg",
            "durationMs" to 562_000,
            "quality" to "24/192 FLAC",
            "trackNo" to 1,
        ) + extra

    @Test
    fun parsesAFullTrack() {
        val track = CarModels.track(trackMap())!!
        assertEquals("t1", track.id)
        assertEquals("So What", track.title)
        assertEquals("Miles Davis", track.artist)
        assertEquals("Kind of Blue", track.album)
        assertEquals("/data/art/a.jpg", track.art)
        assertEquals(562_000L, track.durationMs)
        assertEquals("24/192 FLAC", track.quality)
        assertEquals(1, track.trackNo)
    }

    @Test
    fun dartIntegersArriveAsIntOrLong() {
        val asInt = CarModels.track(trackMap(extra = mapOf("durationMs" to 1_000, "trackNo" to 3)))!!
        val asLong = CarModels.track(trackMap(extra = mapOf("durationMs" to 1_000L, "trackNo" to 3L)))!!
        assertEquals(asInt, asLong)
        assertEquals(1_000L, asLong.durationMs)
        assertEquals(3, asLong.trackNo)

        // Longer than an Int: a duration of more than 24 days is still a duration.
        assertEquals(3_000_000_000L, CarModels.track(trackMap(extra = mapOf("durationMs" to 3_000_000_000L)))!!.durationMs)
    }

    @Test
    fun missingAndOddTypedFieldsAreAbsentNotFatal() {
        val bare = CarModels.track(mapOf("id" to "t9"))!!
        assertEquals("", bare.title)
        assertEquals("", bare.artist)
        assertEquals("", bare.album)
        assertNull(bare.art)
        assertEquals(0L, bare.durationMs)
        assertNull(bare.quality)
        assertNull(bare.trackNo)

        val odd = CarModels.track(
            mapOf(
                "id" to "t9",
                "title" to 42,
                "artist" to listOf("x"),
                "art" to "   ",
                "durationMs" to "soon",
                "quality" to true,
                "trackNo" to 0,
            ),
        )!!
        assertEquals("", odd.title)
        assertEquals("", odd.artist)
        assertNull(odd.art)
        assertEquals(0L, odd.durationMs)
        assertNull(odd.quality)
        // A track number of zero is "no number".
        assertNull(odd.trackNo)

        assertEquals(0L, CarModels.track(trackMap(extra = mapOf("durationMs" to -5)))!!.durationMs)
    }

    @Test
    fun aTrackWithoutAUsableIdIsDropped() {
        assertNull(CarModels.track(mapOf("title" to "x")))
        assertNull(CarModels.track(mapOf("id" to "", "title" to "x")))
        assertNull(CarModels.track(mapOf("id" to null)))
        assertNull(CarModels.track(mapOf("id" to listOf(1))))
        assertNull(CarModels.track("not a map"))
        assertNull(CarModels.track(null))
        // Numeric ids are written out.
        assertEquals("17", CarModels.track(mapOf("id" to 17))!!.id)
    }

    @Test
    fun listsSkipBadEntriesWithoutShiftingTheRest() {
        val tracks = CarModels.tracks(
            listOf(trackMap("a"), "junk", mapOf("title" to "no id"), null, trackMap("b"), 7),
        )
        assertEquals(listOf("a", "b"), tracks.map { it.id })
        assertTrue(CarModels.tracks(null).isEmpty())
        assertTrue(CarModels.tracks("nope").isEmpty())
    }

    @Test
    fun parsesCollections() {
        val map = mapOf(
            "kind" to "album",
            "id" to "al1",
            "title" to "Kind of Blue",
            "subtitle" to "Miles Davis",
            "art" to "/x.jpg",
            "count" to 5L,
            "quality" to "24/192 FLAC",
        )
        val item = CarModels.collectionItem(map)!!
        assertEquals("album", item.kind)
        assertEquals("al1", item.id)
        assertEquals("Miles Davis", item.subtitle)
        assertEquals(5, item.count)
        assertEquals("24/192 FLAC", item.quality)

        val bare = CarModels.collectionItem(mapOf("kind" to "playlist", "id" to "p"))!!
        assertEquals("", bare.title)
        assertNull(bare.subtitle)
        assertNull(bare.count)
        assertNull(CarModels.collectionItem(mapOf("kind" to "album", "count" to -1, "id" to "x"))!!.count)
    }

    @Test
    fun aCollectionNeedsAKindAndAnIdUnlessItIsASingleton() {
        assertNull(CarModels.collectionItem(mapOf("id" to "x")))
        assertNull(CarModels.collectionItem(mapOf("kind" to "album")))
        assertNull(CarModels.collectionItem(mapOf("kind" to "album", "id" to "")))
        assertEquals("", CarModels.collectionItem(mapOf("kind" to "favorites", "id" to ""))!!.id)
    }

    @Test
    fun parsesHome() {
        val home = CarModels.home(
            mapOf(
                "resume" to trackMap("r"),
                "jumpBackIn" to listOf(mapOf("kind" to "album", "id" to "a", "title" to "A")),
                "recentlyAdded" to emptyList<Any>(),
                "mostPlayed" to listOf(trackMap("m1"), trackMap("m2")),
                "playlists" to listOf(mapOf("kind" to "playlist", "id" to "p", "title" to "P")),
                "counts" to mapOf("songs" to 4812L, "albums" to 321, "artists" to 150, "playlists" to 3, "favorites" to 22, "folders" to 4),
                "queueCount" to 14L,
            ),
        )
        assertEquals("r", home.resume!!.id)
        assertEquals(1, home.jumpBackIn.size)
        assertTrue(home.recentlyAdded.isEmpty())
        assertEquals(listOf("m1", "m2"), home.mostPlayed.map { it.id })
        assertEquals(4812, home.counts.songs)
        assertEquals(321, home.counts.albums)
        assertEquals(22, home.counts.favorites)
        assertEquals(14, home.queueCount)
    }

    @Test
    fun homeToleratesNullResumeAndMissingKeys() {
        val home = CarModels.home(mapOf("resume" to null))
        assertNull(home.resume)
        assertTrue(home.jumpBackIn.isEmpty())
        assertEquals(0, home.counts.songs)
        assertEquals(0, home.queueCount)
    }

    @Test
    fun parsesListsAndNeverReportsAFewerTotalThanItems() {
        val items = listOf(mapOf("kind" to "album", "id" to "a"), mapOf("kind" to "album", "id" to "b"))
        assertEquals(2, CarModels.list(mapOf("items" to items, "total" to 2)).total)
        assertEquals(2, CarModels.list(mapOf("items" to items)).total)
        assertEquals(2, CarModels.list(mapOf("items" to items, "total" to 1)).total)
        assertEquals(321, CarModels.list(mapOf("items" to items, "total" to 321L)).total)
    }

    @Test
    fun parsesACollectionDetailWithItsColour() {
        val detail = CarModels.collection(
            mapOf(
                "title" to "Kind of Blue",
                "subtitle" to "Miles Davis",
                "art" to "/c.jpg",
                "quality" to "24/192 FLAC",
                "tracks" to listOf(trackMap("a"), trackMap("b")),
                "albums" to listOf(mapOf("kind" to "album", "id" to "al")),
                "total" to 9,
                // ARGB written by Dart as a positive integer: it arrives as a Long.
                "color" to 0xFF3A7BD5L,
            ),
        )
        assertEquals(2, detail.tracks.size)
        assertEquals(1, detail.albums.size)
        assertEquals(9, detail.total)
        assertEquals(0xFF3A7BD5.toInt(), detail.color)
        assertEquals("Miles Davis", detail.subtitle)

        val bare = CarModels.collection(mapOf("tracks" to listOf(trackMap("a"))))
        assertEquals("", bare.title)
        assertNull(bare.color)
        assertEquals(1, bare.total)
    }

    @Test
    fun parsesSearchAndReportsEmpty() {
        val results = CarModels.search(
            mapOf(
                "tracks" to listOf(trackMap("a")),
                "albums" to listOf(mapOf("kind" to "album", "id" to "x")),
                "artists" to emptyList<Any>(),
                "playlists" to null,
            ),
        )
        assertEquals(1, results.tracks.size)
        assertEquals(1, results.albums.size)
        assertFalse(results.isEmpty)
        assertTrue(CarModels.search(emptyMap<String, Any>()).isEmpty)
    }

    @Test
    fun parsesTheQueue() {
        val queue = CarModels.queue(
            mapOf(
                "current" to trackMap("c"),
                "fromYou" to listOf(trackMap("y1")),
                "fromContext" to listOf(trackMap("x1"), trackMap("x2")),
                "contextName" to "Kind of Blue",
                "shuffle" to true,
                "loop" to "one",
            ),
        )
        assertEquals("c", queue.current!!.id)
        assertEquals(1, queue.fromYou.size)
        assertEquals(2, queue.fromContext.size)
        assertEquals("Kind of Blue", queue.contextName)
        assertTrue(queue.shuffle)
        assertEquals(CarLoop.ONE, queue.loop)

        val idle = CarModels.queue(mapOf("current" to null, "shuffle" to false, "loop" to "mystery"))
        assertNull(idle.current)
        assertNull(idle.contextName)
        assertFalse(idle.shuffle)
        assertEquals(CarLoop.OFF, idle.loop)
        assertEquals(CarLoop.ALL, CarModels.loop("all"))
    }

    @Test
    fun parsesStatus() {
        assertEquals(true, CarModels.status(mapOf("ready" to true, "songCount" to 12L)).ready)
        assertEquals(12, CarModels.status(mapOf("ready" to true, "songCount" to 12L)).songCount)
        assertEquals(false, CarModels.status(mapOf("ready" to "yes")).ready)
        assertEquals(0, CarModels.status(emptyMap<String, Any>()).songCount)
    }

    @Test
    fun anAnswerThatIsNotAMapIsAContractViolation() {
        for (parse in listOf<(Any?) -> Any>(
            CarModels::status, CarModels::home, CarModels::list, CarModels::collection,
            CarModels::search, CarModels::queue,
        )) {
            for (raw in listOf(null, "text", 3, listOf(1))) {
                try {
                    parse(raw)
                    fail("expected CarModelException for $raw")
                } catch (expected: CarModelException) {
                    // The caller renders the retry state.
                }
            }
        }
    }
}
