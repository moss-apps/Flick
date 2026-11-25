package com.mossapps.flick.car

import com.mossapps.flick.CarMediaId
import com.mossapps.flick.car.ClassicTree.Parent
import com.mossapps.flick.car.ui.ListKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The classic browse tree for hosts without templates (docs/ANDROID_AUTO_DESIGN.md, 3). */
class ClassicTreeTest {
    private val all = ClassicTree.window(null, null)

    @Test
    fun theRootIsTheDesignedShallowTree() {
        val root = ClassicTree.root(all)
        assertEquals(
            listOf("Recently played", "Albums", "Artists", "Playlists", "Favorites", "Songs"),
            root.map { it.title },
        )
        val byTitle = root.associateBy { it.title }
        // Recently played is the one playable root item; every root item can be opened.
        assertTrue(byTitle.getValue("Recently played").playable)
        assertTrue(root.all { it.browsable })
        assertEquals(listOf(true, false, false, false, false, false), root.map { it.playable })

        assertEquals(CarMediaId("recentlyPlayed", "").encode(), byTitle.getValue("Recently played").mediaId)
        assertEquals(CarMediaId("favorites", "").encode(), byTitle.getValue("Favorites").mediaId)
        assertEquals(CarMediaId("songs", "").encode(), byTitle.getValue("Songs").mediaId)
        assertEquals(ClassicTree.ALBUMS_ID, byTitle.getValue("Albums").mediaId)
    }

    @Test
    fun everyRootIdParsesBackToWhatItOpens() {
        val parents = ClassicTree.root(all).map { ClassicTree.parent(it.mediaId) }
        assertEquals(
            listOf(
                Parent.Content("recentlyPlayed", ""),
                Parent.Listing(ListKind.ALBUMS),
                Parent.Listing(ListKind.ARTISTS),
                Parent.Listing(ListKind.PLAYLISTS),
                Parent.Content("favorites", ""),
                Parent.Content("songs", ""),
            ),
            parents,
        )
        assertEquals(Parent.Root, ClassicTree.parent(ClassicTree.ROOT_ID))
    }

    @Test
    fun parentIdsFromStrangersAreRejectedNotGuessedAt() {
        assertNull(ClassicTree.parent(null))
        assertNull(ClassicTree.parent(""))
        assertNull(ClassicTree.parent("flick:nothing"))
        assertNull(ClassicTree.parent("album"))
        assertNull(ClassicTree.parent("hack|1"))
        assertNull(ClassicTree.parent("album|"))
        // A track id is a leaf, not a folder.
        assertNull(ClassicTree.parent(CarMediaId("album", "al1", "t1").encode()))
        assertEquals(Parent.Content("album", "al1"), ClassicTree.parent(CarMediaId("album", "al1").encode()))
    }

    @Test
    fun listingsAreFoldersThatOpenOntoTheirTracks() {
        val nodes = ClassicTree.listing(Fixtures.list("album", 3), all)
        assertEquals(3, nodes.size)
        val first = nodes[0]
        assertEquals(CarMediaId("album", "album1").encode(), first.mediaId)
        assertTrue(first.browsable)
        assertFalse(first.playable)
        assertEquals("Artist 1", first.subtitle)
        assertEquals("/data/art/album1.jpg", first.art)
        assertEquals(Parent.Content("album", "album1"), ClassicTree.parent(first.mediaId))

        val artists = ClassicTree.listing(Fixtures.list("artist", 2), all)
        assertEquals(CarMediaId("artist", "artist1").encode(), artists[0].mediaId)
    }

    @Test
    fun trackIdsCarryTheCollectionAndTheTrack() {
        val detail = Fixtures.detail(4)
        val nodes = ClassicTree.tracks(detail, "album", "al 1|x", all)
        assertEquals(4, nodes.size)
        val node = nodes[1]
        assertTrue(node.playable)
        assertFalse(node.browsable)
        assertEquals("Song 2", node.title)
        assertEquals("Artist 2", node.subtitle)

        // The id the session's onPlayFromMediaId parses: collection, then the track to start from.
        val parsed = CarMediaId.parse(node.mediaId)!!
        assertEquals(CarMediaId("album", "al 1|x", "t2"), parsed)
        assertEquals(node.mediaId, parsed.encode())
    }

    @Test
    fun singletonCollectionsBuildAnIdWithNoCollectionId() {
        val nodes = ClassicTree.tracks(Fixtures.detail(2), "favorites", "", all)
        assertEquals(CarMediaId("favorites", "", "t1"), CarMediaId.parse(nodes[0].mediaId))
        assertEquals("favorites||t1", nodes[0].mediaId)
    }

    @Test
    fun listsAreCutToTheRequestedPageSize() {
        val detail = Fixtures.detail(250)
        assertEquals(100, ClassicTree.tracks(detail, "songs", "", ClassicTree.window(null, null)).size)
        assertEquals(100, ClassicTree.tracks(detail, "songs", "", ClassicTree.window(null, -1)).size)
        assertEquals(100, ClassicTree.tracks(detail, "songs", "", ClassicTree.window(null, 0)).size)
        assertEquals(20, ClassicTree.tracks(detail, "songs", "", ClassicTree.window(null, 20)).size)
        assertEquals(250, ClassicTree.tracks(detail, "songs", "", ClassicTree.window(null, 1000)).size)
        // Even a huge request never goes past the channel cap.
        assertEquals(300, ClassicTree.window(null, 100_000).size)
    }

    @Test
    fun pagesAdvanceByPageSize() {
        val detail = Fixtures.detail(60)
        val second = ClassicTree.tracks(detail, "songs", "", ClassicTree.window(1, 25))
        assertEquals(listOf("Song 26", "Song 27"), second.take(2).map { it.title })
        assertEquals(25, second.size)
        val third = ClassicTree.tracks(detail, "songs", "", ClassicTree.window(2, 25))
        assertEquals(10, third.size)
        assertEquals("Song 51", third[0].title)
        assertTrue(ClassicTree.tracks(detail, "songs", "", ClassicTree.window(3, 25)).isEmpty())
        // A negative page is the first page.
        assertEquals("Song 1", ClassicTree.tracks(detail, "songs", "", ClassicTree.window(-1, 25))[0].title)
    }

    @Test
    fun theRequestedLimitCoversTheWindowButNeverTheCap() {
        assertEquals(100, ClassicTree.window(null, null).limit)
        assertEquals(50, ClassicTree.window(1, 25).limit)
        assertEquals(300, ClassicTree.window(5, 100).limit)
        assertEquals(300, ClassicTree.window(200, 300).limit)
    }

    @Test
    fun theRootIsCutToo() {
        assertEquals(2, ClassicTree.root(ClassicTree.window(null, 2)).size)
        // Page 1 of size 3 starts at the fourth item.
        assertEquals(
            listOf("Playlists", "Favorites", "Songs"),
            ClassicTree.root(ClassicTree.window(1, 3)).map { it.title },
        )
    }

    @Test
    fun searchListsSongsFirstThenCollectionsAndPlaysFromTheResultList() {
        val nodes = ClassicTree.search(Fixtures.search(2), "mil", all)
        assertEquals(2 + 2 + 2 + 2, nodes.size)
        assertEquals(listOf(true, true), nodes.take(2).map { it.playable })
        assertEquals(CarMediaId("search", "mil", "t1"), CarMediaId.parse(nodes[0].mediaId))
        assertTrue(nodes.drop(2).all { it.browsable && !it.playable })
        assertEquals(CarMediaId("album", "album1"), CarMediaId.parse(nodes[2].mediaId))
        assertNotNull(ClassicTree.parent(nodes[2].mediaId))

        // 30 per type, then the page cut.
        assertEquals(120, ClassicTree.search(Fixtures.search(40), "mil", ClassicTree.window(null, 1000)).size)
        assertEquals(100, ClassicTree.search(Fixtures.search(40), "mil", all).size)
    }

    @Test
    fun untitledEntriesGetAReadableTitle() {
        val detail = Fixtures.detail(1).copy(tracks = listOf(Fixtures.track(1).copy(title = "", artist = "")))
        val node = ClassicTree.tracks(detail, "album", "x", all).single()
        assertEquals("Unknown title", node.title)
        assertNull(node.subtitle)
    }
}
