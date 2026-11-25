package com.mossapps.flick.car

import com.mossapps.flick.car.ui.CarPalette
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Text on a filled chip or banner is ink on a light fill, white on a dark one (design 2.0). */
class CarPaletteTest {
    @Test
    fun theThemeTokensAreTheDesignedValues() {
        assertEquals(0xFF0A0A0A.toInt(), CarPalette.INK)
        assertEquals(0xFFE0E0E0.toInt(), CarPalette.SILVER)
        assertEquals(0xFFE3F369.toInt(), CarPalette.ACID)
    }

    @Test
    fun lightFillsGetInkText() {
        assertEquals(CarPalette.INK, CarPalette.contentOn(CarPalette.SILVER))
        assertEquals(CarPalette.INK, CarPalette.contentOn(CarPalette.ACID))
        assertEquals(CarPalette.INK, CarPalette.contentOn(0xFFFFFFFF.toInt()))
        assertEquals(CarPalette.INK, CarPalette.contentOn(0xFFFFEB3B.toInt()))
    }

    @Test
    fun darkFillsGetWhiteText() {
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF000000.toInt()))
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(CarPalette.INK))
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF1A237E.toInt()))
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF3A7BD5.toInt()))
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF8B0000.toInt()))
    }

    @Test
    fun theThresholdIsRelativeLuminanceOneHalf() {
        assertEquals(0.5, CarPalette.LIGHT_FILL_THRESHOLD, 0.0)
        assertEquals(1.0, CarPalette.luminance(0xFFFFFFFF.toInt()), 1e-9)
        assertEquals(0.0, CarPalette.luminance(0xFF000000.toInt()), 1e-9)
        // Pure green is much brighter than pure blue at the same channel value.
        assertTrue(CarPalette.luminance(0xFF00FF00.toInt()) > 0.7)
        assertTrue(CarPalette.luminance(0xFF0000FF.toInt()) < 0.1)
        assertEquals(CarPalette.INK, CarPalette.contentOn(0xFF00FF00.toInt()))
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF0000FF.toInt()))
        // Mid grey sits below the threshold, so it takes white.
        assertEquals(CarPalette.WHITE, CarPalette.contentOn(0xFF808080.toInt()))
    }

    @Test
    fun alphaDoesNotChangeTheChoice() {
        assertEquals(CarPalette.contentOn(0xFFE0E0E0.toInt()), CarPalette.contentOn(0x30E0E0E0))
        assertEquals(CarPalette.contentOn(0xFF101010.toInt()), CarPalette.contentOn(0x00101010))
    }

    @Test
    fun albumFallsBackToSilverAndIsAlwaysOpaque() {
        assertEquals(CarPalette.SILVER, CarPalette.album(null))
        assertEquals(CarPalette.SILVER, CarPalette.album(0))
        assertEquals(CarPalette.SILVER, CarPalette.album(0x003A7BD5))
        assertEquals(0xFF3A7BD5.toInt(), CarPalette.album(0xFF3A7BD5.toInt()))
        // A translucent colour keeps its hue and becomes opaque.
        assertEquals(0xFF3A7BD5.toInt(), CarPalette.album(0x803A7BD5.toInt()))
    }

    @Test
    fun theOutlineIsWhiteAtTwentyPercent() {
        assertEquals(0x33, CarPalette.OUTLINE ushr 24)
        assertEquals(0xFFFFFF, CarPalette.OUTLINE and 0xFFFFFF)
    }
}
