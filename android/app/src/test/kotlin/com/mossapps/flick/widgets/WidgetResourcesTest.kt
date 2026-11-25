package com.mossapps.flick.widgets

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class WidgetResourcesTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    private fun resource(path: String): Element {
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        }
        return factory.newDocumentBuilder().parse(File("src/main/res/$path")).documentElement
    }

    private fun Element.android(name: String): String = getAttributeNS(androidNamespace, name)

    @Test
    fun existingWidgetsKeepTheirResizeRules() {
        for (name in listOf("mini_player", "compact", "flagship", "replay")) {
            val provider = resource("xml/${name}_widget_info.xml")
            val resizable = name == "flagship" || name == "replay"
            assertEquals(if (resizable) "horizontal|vertical" else "none", provider.android("resizeMode"))
            if (resizable) {
                assertTrue(provider.android("minResizeWidth").isNotBlank())
                assertTrue(provider.android("minResizeHeight").isNotBlank())
            } else {
                assertTrue(provider.android("minResizeWidth").isBlank())
                assertTrue(provider.android("minResizeHeight").isBlank())
            }
            assertEquals(provider.android("previewLayout"), provider.android("initialLayout"))
        }
    }

    @Test
    fun nowPlayingHasItsOwnPickerEntryAndPreview() {
        val provider = resource("xml/now_playing_widget_info.xml")
        assertEquals("4", provider.android("targetCellWidth"))
        assertEquals("1", provider.android("targetCellHeight"))
        assertEquals("@layout/widget_now_playing", provider.android("initialLayout"))
        assertEquals("@layout/widget_now_playing_preview", provider.android("previewLayout"))
        assertEquals("@drawable/widget_now_playing_preview", provider.android("previewImage"))
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertTrue(manifest.contains(".widgets.NowPlayingWidgetProvider"))
        assertTrue(manifest.contains("@xml/now_playing_widget_info"))
        assertTrue(manifest.contains("android:label=\"@string/widget_now_playing_name\""))
    }

    @Test
    fun nowPlayingCanResizeHorizontallyWithoutAWidthCap() {
        val provider = resource("xml/now_playing_widget_info.xml")
        assertEquals("horizontal", provider.android("resizeMode"))
        assertTrue(provider.android("minResizeWidth").removeSuffix("dp").toInt() <= 203)
        assertTrue(provider.android("maxResizeWidth").isBlank())
    }

    @Test
    fun compactUsesCompatibleMinimumsWithoutOverridingItsTwoByTwoTarget() {
        val provider = resource("xml/compact_widget_info.xml")
        assertEquals("@dimen/widget_compact_min_width", provider.android("minWidth"))
        assertEquals("@dimen/widget_compact_min_height", provider.android("minHeight"))
        assertEquals("2", provider.android("targetCellWidth"))
        assertEquals("2", provider.android("targetCellHeight"))

        fun dimensions(path: String): Map<String, String> {
            val elements = resource(path).getElementsByTagName("dimen")
            return (0 until elements.length).map { elements.item(it) as Element }
                .associate { it.getAttribute("name") to it.textContent }
        }
        val legacy = dimensions("values/widget_dimens.xml")
        val modern = legacy + dimensions("values-v31/widget_dimens.xml")
        assertEquals("110dp", legacy["widget_compact_min_width"])
        assertEquals("156dp", legacy["widget_compact_min_height"])
        assertEquals("110dp", modern["widget_compact_min_width"])
        assertEquals("110dp", modern["widget_compact_min_height"])
    }

    @Test
    fun replayWidgetKeepsItsStatsInsideTheMinimumSize() {
        val provider = resource("xml/replay_widget_info.xml")
        assertEquals("250dp", provider.android("minWidth"))
        assertEquals("110dp", provider.android("minHeight"))
        assertEquals("4", provider.android("targetCellWidth"))
        assertEquals("2", provider.android("targetCellHeight"))

        val root = resource("layout/widget_replay.xml")
        assertEquals("@+id/replay_root", root.android("id"))
        assertEquals("true", root.android("clipToOutline"))
        assertEquals("background", root.android("outlineProvider"))
        assertEquals("@drawable/widget_replay_background_acid", root.android("background"))
        assertEquals("yes", root.android("importantForAccessibility"))
        val covers = root.getElementsByTagName("ImageView")
        val views = (0 until covers.length).map { covers.item(it) as Element }
        assertFalse(views.any { it.android("id").startsWith("@+id/replay_cover_") })
        val artwork = views.single { it.android("id") == "@+id/replay_artwork" }
        assertEquals("wrap_content", artwork.android("layout_width"))
        assertEquals("wrap_content", artwork.android("layout_height"))
        assertEquals("12dp", artwork.android("layout_marginStart"))
        assertEquals("no", artwork.android("importantForAccessibility"))
        val content = artwork.parentNode.parentNode as Element
        assertEquals("noHideDescendants", content.android("importantForAccessibility"))
        val rule = views.single { it.android("id") == "@+id/replay_rule" }
        assertEquals("1dp", rule.android("layout_width"))
        assertEquals("8dp", rule.android("layout_marginStart"))
        assertEquals("8dp", rule.android("layout_marginEnd"))
        assertEquals("86dp", views.single { it.android("id") == "@+id/replay_date" }.android("layout_width"))
        val brandText = views.first { it.android("id") == "@+id/replay_brand_text" }
        assertEquals("0dp", brandText.android("layout_width"))
        assertEquals("1", brandText.android("layout_weight"))
        val time = views.first { it.android("id") == "@+id/replay_time_value" }.parentNode as Element
        val plays = views.first { it.android("id") == "@+id/replay_plays_value" }.parentNode as Element
        assertEquals("1.5", time.android("layout_weight"))
        assertEquals("1", plays.android("layout_weight"))

        val strings = resource("values/widget_strings.xml").getElementsByTagName("string")
        val names = (0 until strings.length).map { (strings.item(it) as Element).getAttribute("name") }
        for (name in listOf("widget_replay_name", "widget_replay_desc", "widget_replay_brand",
            "widget_replay_time", "widget_replay_plays", "widget_replay_empty",
            "widget_replay_open", "widget_replay_summary", "widget_replay_date",
            "widget_replay_comparison", "widget_replay_time_change", "widget_replay_plays_change")) {
            assertTrue(name, names.contains(name))
        }
    }

    @Test
    fun replayAcidSurfaceMatchesTheReplayPalette() {
        val background = resource("drawable/widget_replay_background_acid.xml")
        val solid = background.getElementsByTagName("solid").item(0) as Element
        assertEquals("#FFE3F369", solid.android("color"))
        for (name in listOf("widget_replay_background", "widget_replay_background_signal", "widget_replay_background_acid")) {
            val corners = resource("drawable/$name.xml").getElementsByTagName("corners").item(0) as Element
            assertEquals("24dp", corners.android("radius"))
        }
    }

    @Test
    fun artworkSurfacesDeclareRoundedOutlineClipping() {
        for (name in listOf("widget_compact", "widget_compact_short", "widget_compact_narrow",
            "widget_flagship_art", "widget_flagship_art_wide", "widget_flagship_art_large", "widget_replay")) {
            val root = resource("layout/$name.xml")
            assertEquals("true", root.android("clipToOutline"))
            assertEquals("background", root.android("outlineProvider"))
            val background = root.android("background").removePrefix("@drawable/")
            val corners = resource("drawable/$background.xml").getElementsByTagName("corners").item(0) as Element
            assertEquals("24dp", corners.android("radius"))
        }
    }

    @Test
    fun miniUsesOnePlainPlayButtonAndFlushLeftArtwork() {
        val root = resource("layout/widget_mini_player.xml")
        val buttons = root.getElementsByTagName("ImageButton")
        assertEquals(1, buttons.length)
        assertEquals("@+id/widget_play_pause", (buttons.item(0) as Element).android("id"))
        assertEquals("@style/WidgetTransportButton", (buttons.item(0) as Element).getAttribute("style"))
        val views = root.getElementsByTagName("ImageView")
        val thumbnail = (0 until views.length).map { views.item(it) as Element }
            .first { it.android("id") == "@+id/widget_thumbnail" }
        assertEquals("56dp", thumbnail.android("layout_width"))
        assertEquals("56dp", thumbnail.android("layout_height"))
        assertTrue(thumbnail.android("layout_marginStart").isBlank())
        val corners = resource("drawable/widget_mini_background.xml").getElementsByTagName("corners").item(0) as Element
        assertEquals("16dp", corners.android("radius"))
    }

    @Test
    fun compactKeepsItsArtworkFreeOfFooterGradients() {
        val root = resource("layout/widget_compact.xml")
        val elements = root.getElementsByTagName("*")
        for (index in 0 until elements.length) {
            val element = elements.item(index) as Element
            assertFalse(element.android("background").contains("scrim"))
            assertFalse(element.android("id").contains("footer"))
        }
        val inset = resource("drawable/widget_button_small_play.xml")
        assertEquals("6dp", inset.android("insetLeft"))
        assertEquals("6dp", inset.android("insetRight"))
        val rows = root.getElementsByTagName("LinearLayout")
        val metadata = (0 until rows.length).map { rows.item(it) as Element }
            .first { it.android("id") == "@+id/compact_metadata" }
        assertEquals("8dp", metadata.android("layout_marginBottom"))

        val views = root.getElementsByTagName("ImageView")
        val progress = (0 until views.length).map { views.item(it) as Element }
            .first { it.android("id") == "@+id/compact_progress" }
        assertEquals("56dp", progress.android("layout_marginStart"))
        assertEquals("56dp", progress.android("layout_marginEnd"))
    }

    @Test
    fun compactSmallLayoutsKeepMetadataAndAllThreeControlsInsideTheirBounds() {
        fun Element.dp(name: String): Int = android(name).ifBlank { "0dp" }.removeSuffix("dp").toInt()
        for (name in listOf("widget_compact_short", "widget_compact_narrow")) {
            val root = resource("layout/$name.xml")
            val elements = root.getElementsByTagName("*")
            val views = (0 until elements.length).map { elements.item(it) as Element }
            fun view(id: String) = views.single { it.android("id") == "@+id/$id" }
            for (id in listOf("compact_art_bg", "compact_title", "compact_artist",
                "compact_play_pause", "compact_prev", "compact_next", "compact_progress")) {
                view(id)
            }
            assertFalse(views.any { it.android("background").contains("scrim") })
            val metadata = view("compact_metadata")
            val play = view("compact_play_pause")
            val controls = view("compact_controls")
            assertEquals(48, controls.dp("layout_height"))
            assertEquals("start", view("compact_prev").android("layout_gravity"))
            assertEquals("end", view("compact_next").android("layout_gravity"))
            assertEquals(56, view("compact_progress").dp("layout_marginStart"))
            assertEquals(56, view("compact_progress").dp("layout_marginEnd"))
            val artistGap = view("compact_artist").dp("layout_marginTop")
            assertTrue(22 + artistGap + 18 <= metadata.dp("layout_height"))

            if (name == "widget_compact_short") {
                assertEquals("top", metadata.android("layout_gravity"))
                assertEquals("bottom", controls.android("layout_gravity"))
                val playBottom = metadata.dp("layout_marginTop") + metadata.dp("layout_height")
                for (height in listOf(110, 128, 144, 155)) {
                    val skipTop = height - controls.dp("layout_marginBottom") - 48
                    assertTrue(playBottom <= skipTop)
                }
                val textWidth = 110 - metadata.dp("layout_marginStart") - metadata.dp("layout_marginEnd") -
                    play.dp("layout_marginStart") - 48
                assertEquals(WidgetLayoutPolicy.compactTextWidth(WidgetSize(110, 110), true), textWidth)
                assertTrue(110 - controls.dp("layout_marginStart") - controls.dp("layout_marginEnd") >= 96)
            } else {
                val column = metadata.parentNode as Element
                assertEquals(column, play.parentNode)
                assertEquals(column, controls.parentNode)
                assertEquals("vertical", column.android("orientation"))
                assertEquals("center_vertical", column.android("layout_gravity"))
                val contentHeight = metadata.dp("layout_height") + play.dp("layout_marginTop") + 48 +
                    play.dp("layout_marginBottom") + 48
                assertTrue(contentHeight + 12 <= 156)
                val contentWidth = 110 - column.dp("layout_marginStart") - column.dp("layout_marginEnd")
                assertTrue(contentWidth >= 96)
                assertEquals(WidgetLayoutPolicy.compactTextWidth(WidgetSize(110, 156), true), contentWidth)
            }
        }
    }

    @Test
    fun compactSquareWrapperUsesHostWidthWithoutDependingOnVisibleAlbumArt() {
        val root = resource("layout/widget_compact_square.xml")
        assertEquals("RelativeLayout", root.tagName)
        assertEquals("match_parent", root.android("layout_width"))
        assertEquals("match_parent", root.android("layout_height"))
        assertTrue(root.android("background").isBlank())

        val bounds = root.getElementsByTagName("ImageView").item(0) as Element
        assertEquals("@+id/compact_square_bounds", bounds.android("id"))
        assertEquals("match_parent", bounds.android("layout_width"))
        assertEquals("wrap_content", bounds.android("layout_height"))
        assertEquals("true", bounds.android("adjustViewBounds"))
        assertEquals("invisible", bounds.android("visibility"))
        assertEquals("no", bounds.android("importantForAccessibility"))
        assertEquals("@drawable/widget_compact_square_bounds", bounds.android("src"))

        val content = root.getElementsByTagName("FrameLayout").item(0) as Element
        assertEquals("@+id/compact_square_content", content.android("id"))
        assertEquals("match_parent", content.android("layout_width"))
        assertEquals("wrap_content", content.android("layout_height"))
        assertEquals("@id/compact_square_bounds", content.android("layout_alignTop"))
        assertEquals("@id/compact_square_bounds", content.android("layout_alignBottom"))

        val drawable = resource("drawable/widget_compact_square_bounds.xml")
        val size = drawable.getElementsByTagName("size").item(0) as Element
        assertEquals("1dp", size.android("width"))
        assertEquals(size.android("width"), size.android("height"))
        val solid = drawable.getElementsByTagName("solid").item(0) as Element
        assertEquals("@android:color/transparent", solid.android("color"))
    }

    @Test
    fun flagshipVariantsReserveTheCorrectControlGridWidth() {
        for ((name, width) in listOf("widget_flagship_art" to 104,
            "widget_flagship_art_wide" to 144, "widget_flagship_art_large" to 184)) {
            val includes = resource("layout/$name.xml").getElementsByTagName("include")
            val grid = (0 until includes.length).map { includes.item(it) as Element }
                .first { it.getAttribute("layout") == "@layout/widget_flagship_controls" }
            assertEquals("${width}dp", grid.android("layout_width"))
        }
        assertEquals(4, resource("layout/widget_flagship_controls.xml").getElementsByTagName("ImageButton").length)
    }

    @Test
    fun everyTransportButtonHasAnAccessibleLabelAnd48DpTarget() {
        val styles = resource("values/widget_styles.xml").getElementsByTagName("style")
        val transportStyle = (0 until styles.length).map { styles.item(it) as Element }
            .first { it.getAttribute("name") == "WidgetTransportButton" }
        val items = transportStyle.getElementsByTagName("item")
        val dimensions = (0 until items.length).map { items.item(it) as Element }
            .associate { it.getAttribute("name") to it.textContent }
        assertEquals("48dp", dimensions["android:layout_width"])
        assertEquals("48dp", dimensions["android:layout_height"])

        var count = 0
        for (name in listOf("widget_mini_player", "widget_compact", "widget_compact_short", "widget_compact_narrow",
            "widget_flagship_panel", "widget_flagship_controls", "widget_now_playing_transport")) {
            val buttons = resource("layout/$name.xml").getElementsByTagName("ImageButton")
            for (index in 0 until buttons.length) {
                val button = buttons.item(index) as Element
                assertTrue(button.android("contentDescription").startsWith("@string/widget_"))
                assertTrue(button.getAttribute("style") in listOf("@style/WidgetTransportButton",
                    "@style/WidgetCompactPlayButton", "@style/WidgetTileButton"))
                for (dimension in listOf("layout_width", "layout_height")) {
                    val value = button.android(dimension).ifBlank { "48dp" }
                    if (value == "0dp") assertEquals("1", button.android("layout_weight"))
                    else if (value != "match_parent") assertTrue(value.removeSuffix("dp").toInt() >= 48)
                }
                count++
            }
        }
        assertEquals(19, count)
    }
}
