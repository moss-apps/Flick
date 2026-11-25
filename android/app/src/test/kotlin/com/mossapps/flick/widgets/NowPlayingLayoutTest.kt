package com.mossapps.flick.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NowPlayingLayoutTest {
    @Test
    fun narrowTallPlacementKeepsTheTitleAboveThreeControls() {
        val layout = WidgetLayoutPolicy.nowPlaying(WidgetSize(203, 102), hasSong = true)

        assertTrue(layout.controlsBelow)
        assertEquals(0, layout.artDp)
        assertTrue(layout.showPrevious)
        assertTrue(layout.showNext)
    }

    @Test
    fun shortPlacementKeepsTheTitleReadableAlongsideThreeControls() {
        for (size in listOf(WidgetSize(200, 50), WidgetSize(203, 51))) {
            val layout = WidgetLayoutPolicy.nowPlaying(size, hasSong = true)

            assertFalse(layout.controlsBelow)
            assertTrue(layout.metadataWidthDp >= 56)
            assertTrue(layout.showNext)
            assertTrue(layout.showPrevious)
            assertFalse(layout.showProgress)
            assertFalse(layout.showArtist)
        }
    }

    @Test
    fun gradientColorsRemainReadableAtMinimumOpacity() {
        val black = 0xFF000000.toInt()
        val white = 0xFFFFFFFF.toInt()
        for (cover in listOf(black, 0xFF595959.toInt(), 0xFF8D2ADE.toInt(), 0xFFF9FD6F.toInt(), white)) {
            val colors = WidgetLayoutPolicy.nowPlayingColors(cover, gradient = true, opacity = 60)
            for (surface in listOf(colors.start, colors.end)) {
                for (wallpaper in listOf(black, white)) {
                    val composite = ReplayPalette.lerp(wallpaper, surface, 0.6f)
                    assertTrue(ReplayPalette.contrast(composite, colors.foreground) >= 4.5)
                    assertTrue(ReplayPalette.contrast(composite, colors.secondary) >= 4.5)
                }
            }
        }
    }

    @Test
    fun fourAndFiveColumnPlacementsMakeMoreRoomForArt() {
        val four = WidgetLayoutPolicy.nowPlaying(WidgetSize(344, 106), hasSong = true)
        val five = WidgetLayoutPolicy.nowPlaying(WidgetSize(435, 106), hasSong = true)

        assertFalse(four.controlsBelow)
        assertTrue(four.artDp >= 48)
        assertTrue(five.artDp > four.artDp)
        assertTrue(four.showArtist)
        assertTrue(four.showProgress)
    }
}
