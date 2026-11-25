package com.mossapps.flick.car

import com.mossapps.flick.car.model.CarLoop
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.ui.BannerSectionSpec
import com.mossapps.flick.car.ui.CarIntent
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.CarPalette
import com.mossapps.flick.car.ui.ChipSectionSpec
import com.mossapps.flick.car.ui.CollectionTarget
import com.mossapps.flick.car.ui.CondensedSectionSpec
import com.mossapps.flick.car.ui.EngineState
import com.mossapps.flick.car.ui.GridSectionSpec
import com.mossapps.flick.car.ui.IconId
import com.mossapps.flick.car.ui.ListKind
import com.mossapps.flick.car.ui.LoadState
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.QueueVm
import com.mossapps.flick.car.ui.RootTab
import com.mossapps.flick.car.ui.RowImage
import com.mossapps.flick.car.ui.RowSectionSpec
import com.mossapps.flick.car.ui.RowSpec
import com.mossapps.flick.car.ui.SearchListPage
import com.mossapps.flick.car.ui.SearchPhase
import com.mossapps.flick.car.ui.SearchVm
import com.mossapps.flick.car.ui.SectionSpec
import com.mossapps.flick.car.ui.SectionedPage
import com.mossapps.flick.car.ui.SpotlightSectionSpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PagesContentTest {
    // ------------------------------------------------------------------ helpers

    private fun sections(page: PageSpec): List<SectionSpec> = (page as SectionedPage).sections

    /** A short name per section: its type and its title or header. */
    private fun label(section: SectionSpec): String = when (section) {
        is ChipSectionSpec -> "chips"
        is BannerSectionSpec -> "banner:${section.banner.title}"
        is SpotlightSectionSpec -> "spotlight"
        is CondensedSectionSpec -> "condensed:${section.header?.title ?: section.title}"
        is GridSectionSpec -> "grid:${section.header?.title ?: section.title}"
        is RowSectionSpec -> "rows:${section.header?.title ?: section.title}"
    }

    private fun labels(page: PageSpec) = sections(page).map { label(it) }

    private fun rowsOf(section: SectionSpec): List<RowSpec> = (section as RowSectionSpec).rows

    private fun root(api9: Boolean, vm: com.mossapps.flick.car.ui.RootVm = Fixtures.rootVm()) = Pages.root(vm, api9)

    private fun collection(
        api9: Boolean,
        kind: String,
        detail: com.mossapps.flick.car.model.CarCollectionDetail,
        playing: Boolean = false,
    ) = Pages.collection(Fixtures.collectionVm(Fixtures.content(kind), detail, playing = playing), api9) as SectionedPage

    // --------------------------------------------------------------------- root

    @Test
    fun rootLevel8SectionsAreInTheDesignedOrder() {
        assertEquals(
            listOf(
                "rows:Quick play", "grid:Jump back in", "grid:Browse", "grid:Recently added",
                "rows:Most played", "grid:Playlists",
            ),
            labels(root(false)),
        )
    }

    @Test
    fun rootLevel9SectionsAreInTheDesignedOrder() {
        assertEquals(
            listOf(
                "chips", "spotlight", "condensed:Jump back in", "grid:Recently added",
                "rows:Most played", "grid:Playlists", "condensed:Library",
            ),
            labels(root(true)),
        )
    }

    @Test
    fun emptySectionsAreOmitted() {
        val bare = Fixtures.home(resume = null, queueCount = 0, favorites = 0, folders = 0)
            .copy(jumpBackIn = emptyList(), recentlyAdded = emptyList(), mostPlayed = emptyList(), playlists = emptyList())
        val vm = Fixtures.rootVm(home = bare)

        assertEquals(listOf("rows:Quick play", "grid:Browse"), labels(root(false, vm)))
        assertEquals(listOf("chips", "spotlight", "condensed:Library"), labels(root(true, vm)))

        // Browse and Library only list destinations that have something in them.
        val browse = sections(root(false, vm)).filterIsInstance<GridSectionSpec>().single()
        assertEquals(listOf("Albums", "Artists", "Playlists", "Songs"), browse.items.map { it.title })
        val library = sections(root(true, vm)).filterIsInstance<CondensedSectionSpec>().single()
        assertEquals(listOf("Songs"), library.items.map { it.title })
    }

    @Test
    fun theHeroOffersOnlyWhatExists() {
        val level9 = { vm: com.mossapps.flick.car.ui.RootVm ->
            sections(root(true, vm)).filterIsInstance<SpotlightSectionSpec>().single().items.map { it.title }
        }
        assertEquals(
            listOf("Resume · Song 1", "Shuffle all · 4812 songs", "Up next · 14"),
            level9(Fixtures.rootVm()),
        )
        assertEquals(
            listOf("Shuffle all · 4812 songs"),
            level9(Fixtures.rootVm(home = Fixtures.home(resume = null, queueCount = 0))),
        )

        val quick = rowsOf(sections(root(false)).first())
        assertEquals(listOf("Resume · Song 1", "Shuffle all · 4812 songs"), quick.map { it.title })
        assertEquals(CarIntent.Resume, quick[0].onClick)
        assertEquals(CarIntent.Play("songs", "", shuffle = true), quick[1].onClick)
    }

    @Test
    fun homeSectionsAreCapped() {
        val at8 = sections(root(false)).associateBy { label(it) }
        assertEquals(CarLimits.JUMP_BACK_IN, (at8.getValue("grid:Jump back in") as GridSectionSpec).items.size)
        assertEquals(CarLimits.RECENTLY_ADDED, (at8.getValue("grid:Recently added") as GridSectionSpec).items.size)
        assertEquals(CarLimits.MOST_PLAYED, rowsOf(at8.getValue("rows:Most played")).size)
        assertEquals(CarLimits.HOME_PLAYLISTS, (at8.getValue("grid:Playlists") as GridSectionSpec).items.size)

        val at9 = sections(root(true)).associateBy { label(it) }
        assertEquals(8, (at9.getValue("condensed:Jump back in") as CondensedSectionSpec).items.size)
        assertEquals(12, (at9.getValue("grid:Recently added") as GridSectionSpec).items.size)
        assertEquals(5, rowsOf(at9.getValue("rows:Most played")).size)
    }

    @Test
    fun level9SectionsOfHomeOfferSeeAll() {
        val sections = sections(root(true))
        val recent = sections.filterIsInstance<GridSectionSpec>().first { it.header?.title == "Recently added" }
        assertEquals(CarIntent.OpenList(ListKind.RECENTLY_ADDED), recent.header!!.onClick)
        assertEquals("See all", recent.header.subtitle)
        val played = sections.filterIsInstance<RowSectionSpec>().single { it.header?.title == "Most played" }
        assertEquals(CarIntent.OpenCollection("mostPlayed", "", "Most played"), played.header!!.onClick)
        // Level 8 has no section header: a plain title, no See all.
        assertTrue(sections(root(false)).filterIsInstance<GridSectionSpec>().all { it.header == null })
    }

    @Test
    fun level8BrowseGridPushesTheCollectionScreens() {
        val browse = sections(root(false)).filterIsInstance<GridSectionSpec>().first { it.title == "Browse" }
        assertTrue(browse.iconTiles)
        assertEquals(
            listOf(
                CarIntent.OpenList(ListKind.ALBUMS),
                CarIntent.OpenList(ListKind.ARTISTS),
                CarIntent.OpenList(ListKind.PLAYLISTS),
                CarIntent.OpenCollection("songs", "", "Songs"),
                CarIntent.OpenCollection("favorites", "", "Favorites"),
                CarIntent.OpenList(ListKind.FOLDERS),
            ),
            browse.items.map { it.onClick },
        )
        assertEquals(listOf("321", "150", "15", "4812", "22", "3"), browse.items.map { it.text })
    }

    @Test
    fun rootChipsAreSilverWhenSelectedAndOutlinedOtherwise() {
        val chips = (sections(root(true, Fixtures.rootVm(RootTab.ARTISTS, tabList = Fixtures.list("artist", 3)))).first()
            as ChipSectionSpec).chips
        assertEquals(listOf("Home", "Albums", "Artists", "Playlists"), chips.map { it.title })
        assertEquals(listOf(false, false, true, false), chips.map { it.selected })

        val selected = chips[2]
        assertEquals(CarPalette.SILVER, selected.look.fill)
        assertEquals(CarPalette.INK, selected.look.content)
        for (other in chips.filter { !it.selected }) {
            assertNull("unselected chips have no fill", other.look.fill)
            assertEquals(CarPalette.OUTLINE, other.look.outline)
        }
        // Tapping the selected chip returns to Home; the others select themselves.
        assertEquals(CarIntent.SelectTab(RootTab.HOME), selected.onClick)
        assertEquals(CarIntent.SelectTab(RootTab.ALBUMS), chips[1].onClick)
    }

    @Test
    fun chipDestinationsRenderTheirListsInPlace() {
        val albums = root(true, Fixtures.rootVm(RootTab.ALBUMS, tabList = Fixtures.list("album", 300, total = 321)))
        assertEquals(listOf("chips", "grid:null", "rows:null"), labels(albums))
        val grid = sections(albums)[1] as GridSectionSpec
        assertEquals(300, grid.items.size)
        assertFalse(grid.circle)
        // Truncated: the closing row sends the driver to search.
        val closing = rowsOf(sections(albums)[2]).single()
        assertEquals("Search to find more", closing.title)
        assertEquals(CarIntent.OpenSearch, closing.onClick)

        val artists = root(true, Fixtures.rootVm(RootTab.ARTISTS, tabList = Fixtures.list("artist", 40)))
        assertEquals(listOf("chips", "grid:null"), labels(artists))
        assertTrue((sections(artists)[1] as GridSectionSpec).circle)
    }

    @Test
    fun theChipListIsCappedAt300() {
        val page = root(true, Fixtures.rootVm(RootTab.PLAYLISTS, tabList = Fixtures.list("playlist", 450, total = 450)))
        assertEquals(300, (sections(page)[1] as GridSectionSpec).items.size)
    }

    @Test
    fun rootStates() {
        // Starting: the loading template, nothing else.
        val starting = root(true, Fixtures.rootVm(engine = EngineState.STARTING)) as SectionedPage
        assertTrue(starting.loading)
        assertTrue(starting.sections.isEmpty())

        // Still starting: a banner (9) or a row (8) with Retry.
        val still9 = root(true, Fixtures.rootVm(engine = EngineState.STILL_STARTING))
        val banner = (sections(still9).single() as BannerSectionSpec).banner
        assertEquals("Flick is still starting", banner.title)
        assertEquals(CarIntent.Retry, banner.action!!.onClick)
        val still8 = root(false, Fixtures.rootVm(engine = EngineState.STILL_STARTING))
        val row = rowsOf(sections(still8).single()).single()
        assertEquals("Flick is still starting · Retry", row.title)
        assertEquals(CarIntent.Retry, row.onClick)

        // Empty library: acid banner at 9, a plain row at 8, nothing else below it.
        val empty9 = root(true, Fixtures.rootVm(home = Fixtures.emptyHome()))
        assertEquals(listOf("chips", "banner:Your library is empty — add music in Flick on your phone"), labels(empty9))
        assertEquals(CarPalette.ACID, (sections(empty9)[1] as BannerSectionSpec).banner.fill)
        assertEquals(1, sections(root(false, Fixtures.rootVm(home = Fixtures.emptyHome()))).size)

        // A failed refresh keeps the cached content and adds "Couldn't refresh" with Retry.
        val stale9 = root(true, Fixtures.rootVm(homeState = LoadState.FAILED))
        assertEquals("chips", labels(stale9)[0])
        assertEquals("banner:Couldn't refresh", labels(stale9)[1])
        assertTrue(labels(stale9).size > 3)
        val stale8 = root(false, Fixtures.rootVm(homeState = LoadState.FAILED))
        assertEquals("Couldn't refresh · Retry", rowsOf(sections(stale8)[0]).single().title)

        // Never loaded and failed: only the retry state.
        val failed = root(false, Fixtures.rootVm(home = null, homeState = LoadState.FAILED))
        assertEquals("Couldn't load · Retry", rowsOf(sections(failed).single()).single().title)
    }

    @Test
    fun theHeaderOffersUpNextOnlyWhenSomethingIsPlayingOrQueued() {
        fun ends(vm: com.mossapps.flick.car.ui.RootVm) =
            (root(true, vm) as SectionedPage).header!!.end.map { it.title }

        assertEquals(listOf("Search", "Up next"), ends(Fixtures.rootVm()))
        assertEquals(listOf("Search", "Up next"), ends(Fixtures.rootVm(home = Fixtures.home(resume = null, queueCount = 3))))
        assertEquals(listOf("Search", "Up next"), ends(Fixtures.rootVm(home = Fixtures.home(queueCount = 0))))
        assertEquals(listOf("Search"), ends(Fixtures.rootVm(home = Fixtures.home(resume = null, queueCount = 0))))
    }

    @Test
    fun levelEightIgnoresTheSelectedChip() {
        val at8 = root(false, Fixtures.rootVm(RootTab.ALBUMS, tabList = Fixtures.list("album", 5)))
        assertEquals(labels(root(false)), labels(at8))
    }

    // --------------------------------------------------------------- collection

    @Test
    fun albumRowsHaveNoCoverAndShowTrackNumberAndDuration() {
        val page = collection(false, "album", Fixtures.detail(12))
        val rows = rowsOf(page.sections.last())
        assertEquals(12, rows.size)
        assertEquals(RowImage.NONE, rows[0].imageSize)
        assertNull(rows[0].image)
        assertEquals(listOf("1 · 1:01"), rows[0].texts)
        assertEquals(CarIntent.Play("album", "album-id", "t1"), rows[0].onClick)
    }

    @Test
    fun otherCollectionsShowTheCoverAndArtistWithDuration() {
        val page = collection(false, "playlist", Fixtures.detail(5))
        val rows = rowsOf(page.sections.last())
        assertEquals(RowImage.LARGE, rows[0].imageSize)
        assertEquals(listOf("Artist 1 · 1:01"), rows[0].texts)
        assertEquals(CarIntent.Play("playlist", "playlist-id", "t1"), rows[0].onClick)
        // A track without art falls back to the placeholder (a cover spec with no art).
        assertNull(rows[2].image!!.art)
    }

    @Test
    fun level8CollectionHasPlayAndAddRowsThenTheTracks() {
        val page = collection(false, "album", Fixtures.detail(12))
        assertEquals(listOf("rows:null", "rows:null"), labels(page))
        assertEquals(listOf("Play", "Add to Up next"), rowsOf(page.sections[0]).map { it.title })
        assertEquals(
            listOf(CarIntent.Play("album", "album-id"), CarIntent.Enqueue("album", "album-id")),
            rowsOf(page.sections[0]).map { it.onClick },
        )
        assertNull(page.header!!.modern)
        assertEquals(listOf("Shuffle", "Up next"), page.header.end.map { it.title })
    }

    @Test
    fun level9CollectionHasPlayShuffleAddChipsAndAModernHeader() {
        val page = collection(true, "album", Fixtures.detail(12))
        val chips = (page.sections[0] as ChipSectionSpec).chips
        assertEquals(listOf("Play", "Shuffle", "Add to Up next"), chips.map { it.title })

        // Play is the one filled chip: acid with an ink label.
        assertEquals(CarPalette.ACID, chips[0].look.fill)
        assertEquals(CarPalette.INK, chips[0].look.content)
        assertNull(chips[1].look.fill)
        assertNull(chips[2].look.fill)
        assertEquals(CarPalette.OUTLINE, chips[1].look.outline)

        val modern = page.header!!.modern!!
        assertEquals("Miles Davis · 12 songs · 24/192 FLAC", modern.subtitle)
        assertEquals("/data/art/cover.jpg", modern.startImage!!.art)
    }

    @Test
    fun theChipsOfThePlayingAlbumTakeTheAlbumColour() {
        val chips = (collection(true, "album", Fixtures.detail(12), playing = true).sections[0] as ChipSectionSpec).chips
        assertEquals(Fixtures.ALBUM, chips[1].look.outline)
        assertEquals(Fixtures.ALBUM, chips[2].look.outline)
        // Acid stays the one primary action.
        assertEquals(CarPalette.ACID, chips[0].look.fill)
    }

    @Test
    fun artistsHaveAlbumsThenSongs() {
        val detail = Fixtures.detail(40, albums = 6, subtitle = null, quality = null)

        val at8 = collection(false, "artist", detail)
        assertEquals(listOf("rows:null", "grid:Albums", "rows:Songs"), labels(at8))
        assertEquals(6, (at8.sections[1] as GridSectionSpec).items.size)

        // At 9 the spotlight carries Play and Shuffle on top (and Add to Up next).
        val at9 = collection(true, "artist", detail)
        assertEquals(listOf("spotlight", "grid:Albums", "rows:Songs"), labels(at9))
        val spotlight = at9.sections[0] as SpotlightSectionSpec
        assertEquals(listOf("Play", "Shuffle", "Add to Up next"), spotlight.items.map { it.title })
        assertEquals(1, at9.sections.count { it is SpotlightSectionSpec })
        assertTrue(at9.sections.none { it is ChipSectionSpec })
    }

    @Test
    fun longTrackListsAreCappedAndOfferShuffleAllAndSearch() {
        for (api9 in listOf(false, true)) {
            val page = collection(api9, "playlist", Fixtures.detail(300, total = 450))
            val rows = page.sections.filterIsInstance<RowSectionSpec>()

            val tracks = rows.maxByOrNull { it.rows.size }!!
            assertEquals(300, tracks.rows.size)

            // "Shuffle all 450 songs" comes before the tracks, "Search to find more" closes the list.
            val shuffleAll = rows.first { r -> r.rows.any { it.title == "Shuffle all 450 songs" } }
            assertTrue(page.sections.indexOf(shuffleAll) < page.sections.indexOf(tracks))
            assertEquals(CarIntent.Play("playlist", "playlist-id", shuffle = true), shuffleAll.rows.single().onClick)
            val more = page.sections.last() as RowSectionSpec
            assertEquals("Search to find more", more.rows.single().title)
            assertEquals(CarIntent.OpenSearch, more.rows.single().onClick)
            assertEquals("Showing the first 300 of 450", more.rows.single().texts.single())
        }
        // Not truncated: neither row.
        val short = collection(false, "playlist", Fixtures.detail(300, total = 300))
        assertTrue(short.sections.filterIsInstance<RowSectionSpec>().none { s -> s.rows.any { it.title.startsWith("Shuffle all") } })
        assertEquals(CarLimits.LIST, 300)
    }

    @Test
    fun collectionsWithMoreTracksThanTheCapNeverShowMore() {
        val page = collection(false, "songs", Fixtures.detail(500, total = 4812))
        val tracks = page.sections.filterIsInstance<RowSectionSpec>().maxByOrNull { it.rows.size }!!
        assertEquals(300, tracks.rows.size)
    }

    @Test
    fun longListsAreIndexedAlphabetically() {
        for (kind in listOf("songs", "favorites", "folder")) {
            val page = collection(false, kind, Fixtures.detail(50))
            assertTrue("$kind page is indexed", page.indexing)
            val tracks = page.sections.filterIsInstance<RowSectionSpec>().maxByOrNull { it.rows.size }!!
            assertTrue(tracks.rows.all { it.indexable })
        }
        for (kind in listOf("album", "playlist", "mostPlayed")) {
            val page = collection(false, kind, Fixtures.detail(50))
            assertFalse("$kind page is not indexed", page.indexing)
            assertTrue(page.sections.filterIsInstance<RowSectionSpec>().flatMap { it.rows }.none { it.indexable })
        }
    }

    @Test
    fun listsOfCollectionsAreCappedAndClosedWithSearch() {
        for (api9 in listOf(false, true)) {
            val page = Pages.collection(
                Fixtures.collectionVm(Fixtures.listing(ListKind.ALBUMS), list = Fixtures.list("album", 400, total = 400)),
                api9,
            ) as SectionedPage
            assertEquals(300, (page.sections[0] as GridSectionSpec).items.size)
            assertEquals("Search to find more", rowsOf(page.sections[1]).single().title)
        }
        val artists = Pages.collection(
            Fixtures.collectionVm(Fixtures.listing(ListKind.ARTISTS), list = Fixtures.list("artist", 10)),
            true,
        ) as SectionedPage
        assertTrue((artists.sections.single() as GridSectionSpec).circle)

        val folders = Pages.collection(
            Fixtures.collectionVm(Fixtures.listing(ListKind.FOLDERS), list = Fixtures.list("folder", 4)),
            false,
        ) as SectionedPage
        assertEquals(4, rowsOf(folders.sections.single()).size)
        assertTrue(rowsOf(folders.sections.single()).all { it.browsable })
    }

    @Test
    fun collectionStates() {
        val loading = Pages.collection(Fixtures.collectionVm(Fixtures.content("album"), state = LoadState.LOADING), true) as SectionedPage
        assertTrue(loading.loading)
        val failed = Pages.collection(Fixtures.collectionVm(Fixtures.content("album"), state = LoadState.FAILED), true) as SectionedPage
        assertEquals("banner:Couldn't load", labels(failed).single())
        val empty = collection(false, "playlist", Fixtures.detail(0))
        assertEquals("Nothing here yet", rowsOf(empty.sections.single()).single().title)
        // No tracks: no Play and no Shuffle.
        assertEquals(listOf("Up next"), empty.header!!.end.map { it.title })
    }

    // --------------------------------------------------------------------- queue

    private fun queuePage(api9: Boolean, vm: QueueVm) = Pages.queue(vm, api9) as SectionedPage

    private fun queueVm(queue: com.mossapps.flick.car.model.CarQueue) = QueueVm(LoadState.READY, queue, Fixtures.ALBUM)

    @Test
    fun queueIsSplitIntoNowPlayingFromYouAndFromContext() {
        val at9 = queuePage(true, queueVm(Fixtures.queue(you = 3, context = 20)))
        assertEquals(
            listOf("chips", "rows:Now playing", "rows:Next from you", "rows:Next from Kind of Blue"),
            labels(at9),
        )
        val at8 = queuePage(false, queueVm(Fixtures.queue(you = 3, context = 20)))
        assertEquals(
            listOf("rows:Playback", "rows:Now playing", "rows:Next from you", "rows:Next from Kind of Blue"),
            labels(at8),
        )

        // Level 9 uses section headers with a headline; level 8 section titles.
        val header = (at9.sections[2] as RowSectionSpec).header!!
        assertEquals("Next from you", header.title)
        assertEquals("3 songs", header.headline)
        assertNull(header.subtitle)
        assertNull((at9.sections[2] as RowSectionSpec).title)
        assertNull((at8.sections[2] as RowSectionSpec).header)
    }

    @Test
    fun queueOrderIsThePlayOrderAndNowPlayingIsNotClickable() {
        val page = queuePage(false, queueVm(Fixtures.queue(you = 2, context = 3)))
        val nowPlaying = rowsOf(page.sections[1]).single()
        assertEquals("Song 900", nowPlaying.title)
        assertNull(nowPlaying.onClick)

        val you = rowsOf(page.sections[2])
        assertEquals(listOf("Song 1000", "Song 1001"), you.map { it.title })
        assertEquals(listOf(CarIntent.Jump("you", 0), CarIntent.Jump("you", 1)), you.map { it.onClick })

        val context = rowsOf(page.sections[3])
        assertEquals(listOf("Song 2000", "Song 2001", "Song 2002"), context.map { it.title })
        assertEquals((0..2).map { CarIntent.Jump("context", it) }, context.map { it.onClick })
    }

    @Test
    fun clearIsOfferedOnlyWhenTheDriverQueuedSomething() {
        for (api9 in listOf(false, true)) {
            val withYou = queuePage(api9, queueVm(Fixtures.queue(you = 1, context = 5)))
            assertEquals(listOf("Clear"), withYou.header!!.end.map { it.title })
            assertEquals(CarIntent.ClearQueue, withYou.header.end.single().onClick)

            val withoutYou = queuePage(api9, queueVm(Fixtures.queue(you = 0, context = 5)))
            assertTrue(withoutYou.header!!.end.isEmpty())
            assertFalse(labels(withoutYou).any { it.contains("Next from you") })
        }
    }

    @Test
    fun queueRowsAreCappedAt100WithTheDriversQueueFirst() {
        // 3 + 150: the driver's 3 are kept, the context fills the other 97.
        val page = queuePage(false, queueVm(Fixtures.queue(you = 3, context = 150)))
        assertEquals(3, rowsOf(page.sections[2]).size)
        assertEquals(97, rowsOf(page.sections[3]).size)

        // More than 100 of the driver's own: they alone fill the list.
        val many = queuePage(false, queueVm(Fixtures.queue(you = 130, context = 50)))
        assertEquals(100, rowsOf(many.sections[2]).size)
        assertEquals(listOf("rows:Playback", "rows:Now playing", "rows:Next from you"), labels(many))
    }

    @Test
    fun queueModesAreChipsAtLevel9AndRowsAtLevel8() {
        val on = queuePage(true, queueVm(Fixtures.queue(shuffle = true, loop = CarLoop.ALL)))
        val chips = (on.sections[0] as ChipSectionSpec).chips
        assertEquals(listOf("Shuffle on", "Repeat all"), chips.map { it.title })
        assertEquals(listOf(true, true), chips.map { it.selected })
        // Selected = ALBUM fill with a label readable on it.
        assertEquals(Fixtures.ALBUM, chips[0].look.fill)
        assertEquals(CarPalette.contentOn(Fixtures.ALBUM), chips[0].look.content)
        assertEquals(listOf(CarIntent.ToggleShuffle, CarIntent.CycleLoop), chips.map { it.onClick })

        val off = queuePage(true, queueVm(Fixtures.queue(shuffle = false, loop = CarLoop.OFF)))
        val offChips = (off.sections[0] as ChipSectionSpec).chips
        assertEquals(listOf("Shuffle off", "Repeat off"), offChips.map { it.title })
        assertEquals(listOf(false, false), offChips.map { it.selected })
        assertTrue(offChips.all { it.look.fill == null })

        val one = queuePage(false, queueVm(Fixtures.queue(loop = CarLoop.ONE)))
        val rows = rowsOf(one.sections[0])
        assertEquals(listOf("Shuffle on", "Repeat one"), rows.map { it.title })
        assertEquals(IconId.REPEAT_ONE, rows[1].image!!.icon)
    }

    @Test
    fun queueWithoutAContextNameAndEmptyStates() {
        val unnamed = queuePage(false, queueVm(Fixtures.queue(contextName = null)))
        assertEquals("rows:Next up", labels(unnamed).last())

        val empty = queuePage(false, queueVm(Fixtures.queue(you = 0, context = 0, current = null)))
        assertEquals("Nothing queued — pick an album to start", rowsOf(empty.sections.last()).single().title)
        assertFalse(labels(empty).contains("rows:Now playing"))

        val failed = queuePage(true, QueueVm(LoadState.FAILED, null, Fixtures.ALBUM))
        assertEquals("banner:Couldn't load", labels(failed).single())
        assertTrue(queuePage(true, QueueVm(LoadState.LOADING, null, Fixtures.ALBUM)).loading)
    }

    // -------------------------------------------------------------------- search

    @Test
    fun searchSectionsAreCappedAtThirtyPerType() {
        val page = Pages.search(SearchVm("mil", SearchPhase.READY, Fixtures.search(40), 6), true) as SectionedPage
        assertEquals(listOf("rows:Songs", "grid:Albums", "grid:Artists", "grid:Playlists"), labels(page))
        assertEquals(30, rowsOf(page.sections[0]).size)
        assertEquals(listOf(30, 30, 30), page.sections.drop(1).map { (it as GridSectionSpec).items.size })
        assertTrue((page.sections[2] as GridSectionSpec).circle)
        assertEquals("mil", page.search!!.initialText)
        assertNull(page.header)
    }

    @Test
    fun emptySearchSectionsAreOmitted() {
        val results = CarSearchResults(Fixtures.tracks(2), emptyList(), Fixtures.collections("artist", 1), emptyList())
        val page = Pages.search(SearchVm("mil", SearchPhase.READY, results, 6), true) as SectionedPage
        assertEquals(listOf("rows:Songs", "grid:Artists"), labels(page))
    }

    @Test
    fun levelEightSearchIsOneListCutToTheHostLimit() {
        val results = Fixtures.search(40)
        val short = Pages.search(SearchVm("mil", SearchPhase.READY, results, 6), false) as SearchListPage
        assertEquals(6, short.rows.size)
        assertEquals("Song 1", short.rows[0].title)
        assertEquals(listOf("Artist 1", "Song"), short.rows[0].texts)

        val long = Pages.search(SearchVm("mil", SearchPhase.READY, results, 500), false) as SearchListPage
        assertEquals(120, long.rows.size)
        // Order: songs, albums, artists, playlists, with the type on the second line.
        assertEquals(listOf("Song", "Album", "Artist", "Playlist"), listOf(0, 30, 60, 90).map { long.rows[it].texts.last() })
        assertTrue(long.rows.drop(30).all { it.browsable })
    }

    @Test
    fun searchStatesAndPlayIntents() {
        val idle = Pages.search(SearchVm("", SearchPhase.IDLE, null, 6), false) as SearchListPage
        assertEquals("Search songs, albums, artists and playlists", idle.noItemsMessage)
        val none = Pages.search(SearchVm("zzz", SearchPhase.READY, CarSearchResults(emptyList(), emptyList(), emptyList(), emptyList()), 6), false) as SearchListPage
        assertEquals("No results", none.noItemsMessage)
        assertTrue((Pages.search(SearchVm("zz", SearchPhase.LOADING, null, 6), true) as SectionedPage).loading)

        // A tapped song plays the whole result list from itself: the query is the collection id.
        val page = Pages.search(SearchVm("  mil ", SearchPhase.READY, Fixtures.search(3), 6), true) as SectionedPage
        assertEquals(CarIntent.Play("search", "mil", "t1"), rowsOf(page.sections[0])[0].onClick)
        assertEquals(CarIntent.OpenCollection("album", "album1", "Album 1"), (page.sections[1] as GridSectionSpec).items[0].onClick)
    }

    // -------------------------------------------------------------------- player

    @Test
    fun playerNeverSendsTheTemplateBeforeASessionIsRegistered() {
        val notReady = Pages.player(com.mossapps.flick.car.ui.PlayerVm(false, false, Fixtures.ALBUM), true)
        val message = notReady as com.mossapps.flick.car.ui.MessagePage
        assertEquals("Nothing playing yet", message.message)
        assertEquals(CarIntent.Browse, message.actions.single().onClick)
        assertEquals("Browse", message.actions.single().title)

        val starting = Pages.player(com.mossapps.flick.car.ui.PlayerVm(false, true, Fixtures.ALBUM), true)
        assertTrue((starting as com.mossapps.flick.car.ui.MessagePage).loading)
        assertTrue(starting.actions.isEmpty())

        assertNotNull(Pages.player(com.mossapps.flick.car.ui.PlayerVm(true, false, Fixtures.ALBUM), false) as? com.mossapps.flick.car.ui.PlayerPage)
    }
}
