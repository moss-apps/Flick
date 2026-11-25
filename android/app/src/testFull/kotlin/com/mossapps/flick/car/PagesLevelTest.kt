package com.mossapps.flick.car

import com.mossapps.flick.car.ui.Api9Spec
import com.mossapps.flick.car.ui.ChipSectionSpec
import com.mossapps.flick.car.ui.MessagePage
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.PlayerPage
import com.mossapps.flick.car.ui.SearchListPage
import com.mossapps.flick.car.ui.SectionedPage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** A level 9 spec never reaches a level 8 host (docs/ANDROID_AUTO_DESIGN.md, 5 and 6). */
class PagesLevelTest {
    @Test
    fun noPageAtLevel8ContainsALevel9Spec() {
        val pages = Fixtures.allPages(api9 = false)
        assertTrue("fixtures must cover every page state, got ${pages.size}", pages.size >= 65)
        for ((name, page) in pages) {
            val offenders = SpecWalker.api9Specs(page)
            assertTrue("$name at level 8 contains $offenders", offenders.isEmpty())
        }
    }

    @Test
    fun theWalkerReallyFindsLevel9SpecsAtLevel9() {
        // Guards the test above against passing because the walker sees nothing.
        val pages = Fixtures.allPages(api9 = true)
        val withApi9 = pages.filter { SpecWalker.api9Specs(it.value).isNotEmpty() }.keys
        for (name in listOf("root home", "album", "artist", "queue", "search results", "player ready")) {
            assertTrue("$name should use level 9 specs: ${withApi9}", name in withApi9)
        }
        val kinds = pages.values.flatMap { SpecWalker.api9Specs(it) }.map { it.javaClass.simpleName }.toSet()
        for (expected in listOf(
            "ChipSectionSpec", "BannerSectionSpec", "SpotlightSectionSpec", "CondensedSectionSpec",
            "SectionHeaderSpec", "SearchHeaderSpec", "HeaderModern", "IconTint", "PlayerStyle9", "LastRowAsIs",
        )) {
            assertTrue("level 9 should produce $expected, got $kinds", expected in kinds)
        }
    }

    @Test
    fun atLevel9TheChipSectionIsSingleAndFirst() {
        for ((name, page) in Fixtures.allPages(api9 = true)) {
            val sections = (page as? SectionedPage)?.sections ?: continue
            val chipIndexes = sections.indices.filter { sections[it] is ChipSectionSpec }
            assertTrue("$name has ${chipIndexes.size} chip sections", chipIndexes.size <= 1)
            if (chipIndexes.isNotEmpty()) assertEquals("$name: ChipSection must be first", 0, chipIndexes.single())
        }
    }

    @Test
    fun theMediaPlaybackActionIsBelowLevel9Only() {
        for ((name, page) in Fixtures.allPages(api9 = true)) {
            if (page is SectionedPage) assertFalse("$name draws Action.MEDIA_PLAYBACK at 9", page.playbackAction)
        }
        val at8 = Fixtures.allPages(api9 = false)
        for ((name, page) in at8) {
            if (page is SectionedPage && page.header != null) {
                assertTrue("$name lacks Action.MEDIA_PLAYBACK at 8", page.playbackAction)
            }
        }
    }

    @Test
    fun searchUsesTheLevel8TemplateBelow9AndASearchHeaderAt9() {
        val at8 = Fixtures.allPages(api9 = false)
        val at9 = Fixtures.allPages(api9 = true)
        for (name in at8.keys.filter { it.startsWith("search") }) {
            assertTrue("$name at 8 is a SearchTemplate list", at8.getValue(name) is SearchListPage)
            val page = at9.getValue(name) as SectionedPage
            assertTrue("$name at 9 has a SearchHeader", page.search != null && page.header == null)
        }
    }

    @Test
    fun playerPageStyleExistsAt9Only() {
        val at8 = Fixtures.allPages(api9 = false).getValue("player ready") as PlayerPage
        val at9 = Fixtures.allPages(api9 = true).getValue("player ready") as PlayerPage
        assertEquals(null, at8.style)
        assertEquals(Fixtures.ALBUM, at9.style!!.accent)
        // Both levels: Back and Up next.
        for (page in listOf(at8, at9)) {
            assertEquals(listOf("Up next"), page.header.end.map { it.title })
        }
    }

    @Test
    fun theStateAndMessagePagesAreTheSameAtBothLevels() {
        for (name in listOf("player starting", "player not ready")) {
            val at8: PageSpec = Fixtures.allPages(false).getValue(name)
            val at9: PageSpec = Fixtures.allPages(true).getValue(name)
            assertTrue(at8 is MessagePage)
            assertEquals(at8, at9)
        }
    }

    @Test
    fun everySpecAtEveryLevelHasWhatTheHostRequires() {
        for (api9 in listOf(false, true)) {
            for ((name, page) in Fixtures.allPages(api9)) {
                for (spec in SpecWalker.walk(page)) {
                    when (spec) {
                        is com.mossapps.flick.car.ui.RowSpec ->
                            assertTrue("$name: row without a title", spec.title.isNotBlank())
                        is com.mossapps.flick.car.ui.GridItemSpec ->
                            assertTrue("$name: grid item without a title", spec.title.isNotBlank())
                        is com.mossapps.flick.car.ui.CondensedItemSpec ->
                            assertTrue("$name: condensed item without a title", spec.title.isNotBlank())
                        is com.mossapps.flick.car.ui.HeaderSpec ->
                            assertTrue("$name: header without a title", spec.title.isNotBlank())
                        is com.mossapps.flick.car.ui.ChipSpec ->
                            assertTrue("$name: chip without a title", spec.title.isNotBlank())
                        is com.mossapps.flick.car.ui.RowSectionSpec ->
                            assertTrue("$name: row section without rows", spec.rows.isNotEmpty())
                        is com.mossapps.flick.car.ui.GridSectionSpec ->
                            assertTrue("$name: grid section without items", spec.items.isNotEmpty())
                    }
                }
            }
        }
    }
}
