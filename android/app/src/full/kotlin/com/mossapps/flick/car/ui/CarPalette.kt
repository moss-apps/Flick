package com.mossapps.flick.car.ui

/**
 * The theme of docs/ANDROID_AUTO_DESIGN.md, 2.0: monochrome ink and silver, tinted
 * by the playing album, acid for the one primary action. Plain ARGB ints and no
 * Android types, so page building and its tests stay on the JVM.
 */
object CarPalette {
    /** `AppColors.background`: text on light fills. */
    const val INK = 0xFF0A0A0A.toInt()

    /** `AppColors.accent`: the default accent. */
    const val SILVER = 0xFFE0E0E0.toInt()

    /** The single primary action per screen, and the empty-library banner. */
    const val ACID = 0xFFE3F369.toInt()

    const val WHITE = 0xFFFFFFFF.toInt()

    /** White at 20 %: the outline of an unselected chip. */
    const val OUTLINE = 0x33FFFFFF

    /** Relative luminance at or above which text on a fill is ink. */
    const val LIGHT_FILL_THRESHOLD = 0.5

    /**
     * ALBUM: the colour Flick extracted for the playing album, or [SILVER] when there is
     * none (nothing playing, the album-colour mode is off, or a transparent value). The
     * result is always opaque.
     */
    fun album(albumColor: Int?): Int {
        if (albumColor == null || (albumColor ushr 24) == 0) return SILVER
        return albumColor or 0xFF000000.toInt()
    }

    /** WCAG relative luminance of an sRGB colour, 0.0 (black) to 1.0 (white). Alpha is ignored. */
    fun luminance(argb: Int): Double {
        fun channel(shift: Int): Double {
            val c = ((argb ushr shift) and 0xFF) / 255.0
            return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    /** Text on a filled chip or banner: ink on a light fill, white on a dark one. */
    fun contentOn(fill: Int): Int = if (luminance(fill) >= LIGHT_FILL_THRESHOLD) INK else WHITE
}
