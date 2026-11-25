package com.mossapps.flick.widgets

internal data class WidgetSize(val widthDp: Int, val heightDp: Int)

internal data class NowPlayingGeometry(
    val controlsBelow: Boolean,
    val showPrevious: Boolean,
    val showNext: Boolean,
    val horizontalPaddingDp: Int,
    val artDp: Int,
    val metadataWidthDp: Int,
    val showArtist: Boolean,
    val showProgress: Boolean,
)

internal data class NowPlayingColors(
    val start: Int, val end: Int, val foreground: Int, val secondary: Int,
    val progressTrack: Int, val playIcon: Int, val lightText: Boolean,
)

internal enum class CompactLayout { REGULAR, SHORT, NARROW }

internal data class FlagshipGeometry(
    val gridWidthDp: Int,
    val gapDp: Int,
    val paddingDp: Int,
    val panelWidthDp: Int,
    val panelPaddingDp: Int,
    val coverDp: Int,
    val upcomingSlots: Int,
    val repeatInHeader: Boolean,
) {
    val panelContentWidthDp: Int get() = panelWidthDp - panelPaddingDp * 2
    val textWidthDp: Int get() = panelContentWidthDp - if (repeatInHeader) 0 else 56
}

internal data class ReplayGeometry(
    val covers: Int,
    val coverDp: Int,
    val valueSp: Int,
    val paddingDp: Int,
    val contentHeightDp: Int,
    val valueHeightDp: Int,
    val timeWidthDp: Int,
    val playsWidthDp: Int,
    val brandTextWidthDp: Int,
    val bodyGapDp: Int,
    val artworkWidthDp: Int,
    val artworkHeightDp: Int,
    val coverStepDp: Int,
    val showCaption: Boolean,
    val hasData: Boolean,
) {
    val statsWidthDp: Int get() = timeWidthDp + playsWidthDp + 17
    val metricsHeightDp: Int get() = 14 + valueHeightDp + if (hasData) 14 else 0

    /** Back-to-front order; index zero is always today's top album. */
    fun sleeves(rtl: Boolean = false): List<ReplaySleeve> = (covers - 1 downTo 0).map { index ->
        val side = coverDp * (1f - index * 0.04f)
        val left = 8f + (covers - 1 - index) * coverStepDp + (coverDp - side) / 2f
        ReplaySleeve(index, if (rtl) artworkWidthDp - left - side else left,
            (artworkHeightDp - side) / 2f - index * 0.6f, side,
            index * if (rtl) 3f else -3f)
    }
}

internal data class ReplaySleeve(
    val index: Int, val leftDp: Float, val topDp: Float, val sideDp: Float, val rotation: Float,
)

/** Fit the complete rotated orbit, including contour strokes, inside its bitmap. */
internal data class ReplayOrbitGeometry(
    val radiusXDp: Float, val radiusYDp: Float, val scale: Float,
) {
    companion object {
        const val ROTATION = -24f
        const val STROKE_DP = 3f
        const val CONTOUR_STROKE_DP = 0.8f
        const val PADDING_DP = 2f
        val CONTOUR_INSETS_DP = listOf(4f, 8f)

        fun fit(widthDp: Float, heightDp: Float): ReplayOrbitGeometry {
            val radiusX = widthDp * 0.54f
            val radiusY = heightDp * 0.34f
            val outerX = radiusX + CONTOUR_INSETS_DP.last()
            val outerY = radiusY + CONTOUR_INSETS_DP.last()
            val radians = Math.toRadians(ROTATION.toDouble())
            val cosine = Math.cos(radians)
            val sine = Math.sin(radians)
            val halfWidth = Math.hypot(outerX * cosine, outerY * sine) + CONTOUR_STROKE_DP / 2
            val halfHeight = Math.hypot(outerX * sine, outerY * cosine) + CONTOUR_STROKE_DP / 2
            val padding = minOf(PADDING_DP, widthDp / 4, heightDp / 4)
            val scale = minOf(1f, ((widthDp / 2 - padding) / halfWidth).toFloat(),
                ((heightDp / 2 - padding) / halfHeight).toFloat())
            return ReplayOrbitGeometry(radiusX, radiusY, scale)
        }
    }
}

/** Colors mirroring the in-app Replay card palette (pure math, unit-testable). */
internal data class ReplayColors(
    val background: Int,
    val shaded: Int,
    val foreground: Int,
    val secondary: Int,
    val positive: Int,
    val negative: Int,
    val border: Int,
    val value: Int,
    val accent: Int,
)

internal object ReplayPalette {
    val NIGHT = ReplayColors(
        background = 0xFF0A0A0A.toInt(),
        shaded = 0xFF101010.toInt(),
        foreground = 0xFFF1F0EB.toInt(),
        secondary = 0xFFA4A49F.toInt(),
        positive = 0xFFE3F369.toInt(),
        negative = 0xFFCBCBC6.toInt(),
        border = 0x13FFFFFF,
        value = 0xFFE3F369.toInt(),
        accent = 0xFFFF5636.toInt(),
    )
    val SIGNAL = ReplayColors(
        background = 0xFFFF5636.toInt(),
        shaded = 0xFFF35234.toInt(),
        foreground = 0xFF351009.toInt(),
        secondary = 0xFF351009.toInt(),
        positive = 0xFF351009.toInt(),
        negative = 0xFF351009.toInt(),
        border = 0x13000000,
        value = 0xFF0A0A0A.toInt(),
        accent = 0xFFE3F369.toInt(),
    )
    val ACID = ReplayColors(
        background = 0xFFE3F369.toInt(),
        shaded = 0xFFE3F369.toInt(),
        foreground = 0xFF0A0A0A.toInt(),
        secondary = 0xFF343C0E.toInt(),
        positive = 0xFF343C0E.toInt(),
        negative = 0xFF343C0E.toInt(),
        border = 0x13000000,
        value = 0xFF0A0A0A.toInt(),
        accent = 0xFFFF5636.toInt(),
    )

    fun luminance(color: Int): Float {
        fun channel(value: Int): Float {
            val v = value / 255f
            return if (v <= 0.03928f) v / 12.92f
            else Math.pow(((v + 0.055f) / 1.055f).toDouble(), 2.4).toFloat()
        }
        return 0.2126f * channel(color shr 16 and 0xFF) +
            0.7152f * channel(color shr 8 and 0xFF) +
            0.0722f * channel(color and 0xFF)
    }

    fun lerp(from: Int, to: Int, amount: Float): Int {
        fun mix(shift: Int): Int {
            val a = from shr shift and 0xFF
            val b = to shr shift and 0xFF
            return (a + (b - a) * amount).toInt().coerceIn(0, 255)
        }
        return (from and 0xFF000000.toInt()) or (mix(16) shl 16) or (mix(8) shl 8) or mix(0)
    }

    fun contrast(first: Int, second: Int): Float {
        val a = luminance(first)
        val b = luminance(second)
        return (maxOf(a, b) + 0.05f) / (minOf(a, b) + 0.05f)
    }

    /** Artwork look: tint the surface from today's top cover and pick a readable foreground. */
    fun artwork(base: Int): ReplayColors {
        val lum = luminance(base)
        val darkText = contrast(base, 0xFF000000.toInt()) >= contrast(base, 0xFFFFFFFF.toInt())
        val amount = if (lum < 0.03f) 0.03f else 0.045f
        val toward = if (lum < 0.03f || darkText) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        val shaded = lerp(base, toward, amount)
        val foreground = if (darkText) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        fun readable(candidate: Int, minimum: Float): Int =
            if (contrast(candidate, base) >= minimum && contrast(candidate, shaded) >= minimum) candidate
            else foreground
        val secondary = readable(lerp(base, foreground, 0.82f), 4.5f)
        val positive = readable(lerp(base, NIGHT.foreground, 0.65f), 4.5f)
        return ReplayColors(
            base, shaded, foreground, secondary,
            positive, foreground, if (darkText) 0x13000000 else 0x13FFFFFF,
            foreground, if (contrast(base, ACID.background) >= 2f) ACID.background else SIGNAL.background,
        )
    }
}

/** Geometry shared by rendering and tests; never borrow the phone's screen width. */
internal object WidgetLayoutPolicy {
    const val MINI_HEIGHT_DP = 56
    val miniDefault = WidgetSize(320, MINI_HEIGHT_DP)
    val compactDefault = WidgetSize(168, 168)
    val flagshipDefault = WidgetSize(320, 240)

    val nowPlayingDefault = WidgetSize(320, 80)
    private const val NOW_PLAYING_INK = 0xFF22251B.toInt()
    private const val WHITE = 0xFFFFFFFF.toInt()
    private const val BLACK = 0xFF000000.toInt()

    fun nowPlayingColors(background: Int, gradient: Boolean, opacity: Int): NowPlayingColors {
        val foreground = when {
            ReplayPalette.contrast(background, NOW_PLAYING_INK) >= 4.5 -> NOW_PLAYING_INK
            ReplayPalette.contrast(background, WHITE) >= 4.5 -> WHITE
            else -> BLACK
        }
        val lightText = foreground == WHITE
        val backdrop = if (lightText) WHITE else BLACK
        val tone = if (lightText) BLACK else WHITE
        val alpha = opacity.coerceIn(60, 100) / 100f
        fun worstCase(surface: Int) = ReplayPalette.lerp(backdrop, surface, alpha)

        // At low opacity, keep the artwork hue and move its tone far enough
        // from the foreground to stay readable over either extreme of wallpaper.
        var start = background
        while (ReplayPalette.contrast(worstCase(start), foreground) < 4.5 && start != tone) {
            val adjusted = ReplayPalette.lerp(start, tone, 0.25f)
            start = if (adjusted == start) tone else adjusted
        }
        val end = if (gradient) ReplayPalette.lerp(start, tone, 0.16f) else start
        val secondary = ReplayPalette.lerp(start, foreground, 0.82f)
            .takeIf { ReplayPalette.contrast(it, worstCase(start)) >= 4.5 } ?: foreground
        val playIcon = if (lightText) NOW_PLAYING_INK
            else start.takeIf { ReplayPalette.contrast(it, NOW_PLAYING_INK) >= 4.5 } ?: WHITE
        return NowPlayingColors(start, end, foreground, secondary,
            ReplayPalette.lerp(start, foreground, 0.20f), playIcon, lightText)
    }

    fun nowPlaying(size: WidgetSize, hasSong: Boolean, allowArtwork: Boolean = true): NowPlayingGeometry {
        val (width, height) = size
        val preferredPadding = when {
            width < 200 -> 4
            width < 256 -> 8
            else -> 12
        }
        val controlsBelow = hasSong && width in 160..243 && height >= 96
        val metadataMin = 56
        val fullControlsMin = 144 + metadataMin
        val padding = if (hasSong && !controlsBelow && width >= fullControlsMin) {
            minOf(preferredPadding, (width - fullControlsMin) / 2)
        } else preferredPadding
        val contentWidth = width - 2 * padding
        val previous = hasSong && (controlsBelow || contentWidth >= fullControlsMin)
        val next = hasSong && (controlsBelow || contentWidth >= 96 + metadataMin)
        val controlsWidth = if (hasSong) 48 + (if (previous) 48 else 0) + (if (next) 48 else 0) else 0
        val textAndArtWidth = contentWidth - if (controlsBelow) 0 else controlsWidth
        // Keep 72 dp for a title before adding a cover and its 12 dp gutter.
        val cover = minOf(width * 18 / 100, 80, height, textAndArtWidth - 72 - 12)
        val art = if (allowArtwork && !controlsBelow && cover >= 48) cover else 0
        val textWidth = textAndArtWidth - if (art > 0) art + 12 else 0
        return NowPlayingGeometry(
            controlsBelow, previous, next, padding, art, textWidth,
            showArtist = hasSong && !controlsBelow && height >= 62 && textWidth >= 72,
            showProgress = hasSong && height >= if (controlsBelow) 102 else 56,
        )
    }

    fun miniTextWidth(size: WidgetSize, showArt: Boolean, hasSong: Boolean): Int =
        (size.widthDp - 16 - (if (showArt) MINI_HEIGHT_DP else 0) - (if (hasSong) 48 else 0))
            .coerceAtLeast(1)

    fun compactCardSize(size: WidgetSize, legacySizing: Boolean): WidgetSize =
        // Legacy launchers can give two rows much more height than two columns.
        // Keep their grid allocation, but don't stretch the card through that space.
        if (legacySizing && size.heightDp.toLong() * 2 > size.widthDp.toLong() * 3)
            WidgetSize(size.widthDp, size.widthDp)
        else size

    fun compactLayout(size: WidgetSize): CompactLayout = when {
        size.heightDp < 156 -> CompactLayout.SHORT
        size.widthDp < 156 -> CompactLayout.NARROW
        else -> CompactLayout.REGULAR
    }

    fun compactTextWidth(size: WidgetSize, hasSong: Boolean): Int {
        val layout = compactLayout(size)
        val margins = if (layout == CompactLayout.REGULAR) 32 else 12
        val play = if (hasSong && layout != CompactLayout.NARROW) 56 else 0
        return (size.widthDp - margins - play).coerceAtLeast(1)
    }

    fun compactShowsProgress(size: WidgetSize): Boolean {
        val margins = if (compactLayout(size) == CompactLayout.REGULAR) 16 else 12
        return size.widthDp - margins - 112 >= 24
    }

    fun flagship(size: WidgetSize): FlagshipGeometry {
        val grid = when {
            size.widthDp >= 560 -> 184
            size.widthDp >= 440 -> 144
            else -> 104
        }
        val gap = if (grid == 104) 8 else 12
        val padding = if (size.widthDp < 336 || size.heightDp < 208) 12 else 16
        val panelWidth = size.widthDp - padding * 2 - gap - grid
        val panelPadding = if (panelWidth < 160 || size.heightDp < 208) 8 else 12
        val contentWidth = panelWidth - panelPadding * 2
        val repeatInHeader = contentWidth < 144
        val cover = ((size.heightDp - 112) / 2).coerceIn(48, 88)
            .coerceAtMost(if (repeatInHeader) (contentWidth - 48).coerceAtLeast(48) else contentWidth)
        val slots = if (repeatInHeader) 0 else ((contentWidth - cover) / (cover + 8)).coerceIn(0, 2)
        return FlagshipGeometry(grid, gap, padding, panelWidth, panelPadding, cover, slots, repeatInHeader)
    }

    fun time(milliseconds: Long): String {
        val seconds = milliseconds.coerceAtLeast(0) / 1000
        return if (seconds >= 3600) "%d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60)
        else "%d:%02d".format(seconds / 60, seconds % 60)
    }

    fun progress(positionMs: Long, durationMs: Long): Int =
        if (durationMs > 0) ((positionMs.coerceIn(0, durationMs).toDouble() / durationMs) * 1000).toInt()
        else 0

    val replayDefault = WidgetSize(320, 160)

    fun replay(size: WidgetSize, availableCovers: Int = 3, hasData: Boolean = true): ReplayGeometry {
        val padding = if (size.widthDp < 300 || size.heightDp < 140) 12 else 16
        val bodyGap = if (size.heightDp < 140) 8 else 12
        val contentWidth = (size.widthDp - padding * 2).coerceAtLeast(1)
        val contentHeight = (size.heightDp - padding * 2 - 20 - bodyGap).coerceAtLeast(1)
        val cover = minOf((size.widthDp * 0.22f).toInt(), contentHeight - 16,
            contentWidth - 144 - 12 - 16).coerceIn(1, 132)
        val step = (cover * 0.32f).toInt().coerceAtLeast(1)
        fun artworkWidth(count: Int) = cover + (count.coerceAtLeast(1) - 1) * step + 16
        var covers = if (hasData) availableCovers.coerceIn(0, 3) else 0
        // Lose rear sleeves before sacrificing the two readable metric columns.
        while (covers > 1 && contentWidth - artworkWidth(covers) - 12 < 144) covers--
        val artWidth = artworkWidth(covers)
        val statWidth = (contentWidth - artWidth - 12 - 17).coerceAtLeast(2)
        val timeWidth = statWidth * 3 / 5 // Matches the 1.5:1 column weights in XML.
        val showCaption = !hasData || contentHeight >= 84
        val fixedHeight = 14 + (if (hasData) 14 else 0) + (if (showCaption) 18 else 0)
        val availableValueHeight = (contentHeight - fixedHeight).coerceAtLeast(1)
        val valueSp = minOf((size.widthDp / 8.5f).toInt().coerceIn(24, 60),
            (availableValueHeight * 0.85f).toInt().coerceAtLeast(24))
        return ReplayGeometry(
            covers = covers,
            coverDp = cover,
            valueSp = valueSp,
            paddingDp = padding,
            contentHeightDp = contentHeight,
            valueHeightDp = minOf((valueSp * 1.2f).toInt(), availableValueHeight),
            timeWidthDp = timeWidth,
            playsWidthDp = statWidth - timeWidth,
            brandTextWidthDp = (contentWidth - 22 - 86 - 8).coerceAtLeast(1),
            bodyGapDp = bodyGap,
            artworkWidthDp = artWidth,
            artworkHeightDp = minOf(contentHeight, cover + 18),
            coverStepDp = step,
            showCaption = showCaption,
            hasData = hasData,
        )
    }

    /** Mirrors the in-app Replay duration label ("0m", "48m", "1h", "1h 5m"). */
    fun listeningTime(milliseconds: Long): String {
        val minutes = milliseconds.coerceAtLeast(0) / 60_000
        val hours = minutes / 60
        val remainder = minutes % 60
        return when {
            hours == 0L -> "${remainder}m"
            remainder == 0L -> "${hours}h"
            else -> "${hours}h ${remainder}m"
        }
    }

    /** "+N%"/"0%"/"-N%" for the delta chips; the provider hides unknown and zero deltas. */
    fun percentLabel(delta: Int): String = when {
        delta > 0 -> "+$delta%"
        else -> "$delta%"
    }
}
