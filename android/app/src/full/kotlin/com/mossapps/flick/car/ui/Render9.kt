@file:androidx.annotation.OptIn(androidx.car.app.annotations.ExperimentalCarApi::class)

package com.mossapps.flick.car.ui

import androidx.car.app.media.model.MediaPlaybackStyle
import androidx.car.app.media.model.MediaPlaybackTemplate
import androidx.car.app.model.Action
import androidx.car.app.model.Background
import androidx.car.app.model.Banner
import androidx.car.app.model.BannerSection
import androidx.car.app.model.BannerStyle
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Chip
import androidx.car.app.model.ChipSection
import androidx.car.app.model.ChipStyle
import androidx.car.app.model.CondensedItem
import androidx.car.app.model.CondensedSection
import androidx.car.app.model.GridSection
import androidx.car.app.model.Header
import androidx.car.app.model.RowSection
import androidx.car.app.model.SearchCallback
import androidx.car.app.model.SearchHeader
import androidx.car.app.model.Section
import androidx.car.app.model.SectionHeader
import androidx.car.app.model.SectionedItemTemplate
import androidx.car.app.model.Shape
import androidx.car.app.model.SpotlightSection
import androidx.car.app.model.StrokeCap
import androidx.core.graphics.drawable.IconCompat

/**
 * Everything that exists only at Car API 9 (docs/ANDROID_AUTO_DESIGN.md, 6). This is the
 * ONLY file that imports those classes, and it is called only for an [Api9Spec] when the
 * host negotiated level 9. The library is an alpha (1.9.0-alpha03): if a later alpha changes
 * a builder, this is the file to touch.
 *
 * A JVM test scans the compiled classes to keep it that way. For the same reason the
 * section builders here return the level 8 type `Section<*>`: a level 9 class in a method
 * descriptor would be a reference from the caller too.
 */
internal object Render9 {
    /** One colour for day and night: the car theme is the app's own. */
    fun color(argb: Int): CarColor = CarColor.createCustom(argb, argb)

    private val TRANSPARENT: CarColor = CarColor.createCustom(0x00000000, 0x00000000)

    fun tinted(icon: IconCompat, tint: IconTint): CarIcon = CarIcon.createTintedIcon(icon, color(tint.color))

    // ---------------------------------------------------------------- headers

    fun headerModern(header: Header.Builder, spec: HeaderModern, image: (ImageSpec?) -> CarIcon) {
        spec.subtitle?.let { header.setSubtitle(it) }
        spec.startImage?.let { header.setStartHeaderImage(image(it)) }
    }

    fun searchHeader(template: SectionedItemTemplate.Builder, spec: SearchHeaderSpec, sink: SearchSink?) {
        val callback = object : SearchCallback {
            override fun onSearchTextChanged(searchText: String) {
                sink?.textChanged(searchText)
            }

            override fun onSearchSubmitted(searchText: String) {
                sink?.submitted(searchText)
            }
        }
        template.setSearchHeader(
            SearchHeader.Builder(callback)
                .setInitialSearchText(spec.initialText)
                .setSearchHint(spec.hint)
                .setShowKeyboardByDefault(true)
                .setStartHeaderAction(Action.BACK)
                .build(),
        )
    }

    fun playerStyle(template: MediaPlaybackTemplate.Builder, spec: PlayerStyle9) {
        template.setStyle(
            MediaPlaybackStyle.Builder()
                .setMediaAccentColor(color(spec.accent))
                .setProgressBarStrokeCap(StrokeCap.ROUND)
                .build(),
        )
    }

    // -------------------------------------------------------- section headers

    private fun sectionHeader(spec: SectionHeaderSpec, onIntent: (CarIntent) -> Unit): SectionHeader {
        val header = SectionHeader.Builder(spec.title)
        spec.headline?.let { header.setHeadline(it) }
        spec.subtitle?.let { header.setSubtitle(it) }
        spec.onClick?.let { intent -> header.setOnClickListener { onIntent(intent) } }
        return header.build()
    }

    fun sectionHeader(section: RowSection.Builder, spec: SectionHeaderSpec, onIntent: (CarIntent) -> Unit) {
        section.setSectionHeader(sectionHeader(spec, onIntent))
    }

    fun sectionHeader(section: GridSection.Builder, spec: SectionHeaderSpec, onIntent: (CarIntent) -> Unit) {
        section.setSectionHeader(sectionHeader(spec, onIntent))
    }

    /** Keeps an incomplete last row of a grid as it is instead of truncating it. */
    fun keepLastRow(section: GridSection.Builder) {
        section.setIncompleteLastRowStrategy(GridSection.INCOMPLETE_LAST_ROW_AS_IS)
    }

    // --------------------------------------------------------------- sections

    fun chipSection(spec: ChipSectionSpec, image: (ImageSpec?) -> CarIcon, onIntent: (CarIntent) -> Unit): Section<*> {
        val section = ChipSection.Builder()
        for (chip in spec.chips) {
            val look = chip.look
            val chipStyle = ChipStyle.Builder()
                .setShape(Shape.CORNER_FULL)
                .setBackgroundColor(look.fill?.let { color(it) } ?: TRANSPARENT)
                .setOutlineColor(color(look.outline ?: look.fill ?: look.content))
                .setContentColor(color(look.content))
                .build()
            val builder = Chip.Builder()
                .setTitle(chip.title)
                .setSelected(chip.selected)
                .setStyle(chipStyle)
                .setOnClickListener { onIntent(chip.onClick) }
            chip.icon?.let { builder.setStartIcon(image(it)) }
            section.addItem(builder.build())
        }
        return section.build()
    }

    fun bannerSection(spec: BannerSectionSpec, image: (ImageSpec?) -> CarIcon, onIntent: (CarIntent) -> Unit): Section<*> {
        val banner = spec.banner
        val bannerStyle = BannerStyle.Builder().setShape(Shape.CORNER_LARGE).apply {
            banner.fill?.let { setBackground(Background.Builder().setColor(color(it)).build()) }
        }.build()
        val builder = Banner.Builder().setTitle(banner.title).setStyle(bannerStyle)
        banner.subtitle?.let { builder.setSubtitle(it) }
        banner.leading?.let { builder.setLeadingImage(image(it)) }
        banner.onClick?.let { intent -> builder.setOnClickListener { onIntent(intent) } }
        banner.action?.let { action ->
            builder.addTrailingAction(
                Action.Builder().setTitle(action.title).setOnClickListener { onIntent(action.onClick) }.build(),
            )
        }
        return BannerSection.Builder().addItem(builder.build()).build()
    }

    fun condensedSection(
        spec: CondensedSectionSpec,
        image: (ImageSpec?) -> CarIcon,
        onIntent: (CarIntent) -> Unit,
    ): Section<*> {
        val section = CondensedSection.Builder()
        if (spec.lastRow != null) section.setIncompleteLastRowStrategy(CondensedSection.INCOMPLETE_LAST_ROW_AS_IS)
        val header = spec.header
        if (header != null) {
            section.setSectionHeader(sectionHeader(header, onIntent))
        } else if (!spec.title.isNullOrEmpty()) {
            section.setTitle(spec.title)
        }
        for (item in spec.items) {
            section.addItem(condensedItem(item, image, onIntent, CondensedItem.IMAGE_TYPE_MEDIUM))
        }
        return section.build()
    }

    fun spotlightSection(
        spec: SpotlightSectionSpec,
        image: (ImageSpec?) -> CarIcon,
        onIntent: (CarIntent) -> Unit,
    ): Section<*> {
        val section = SpotlightSection.Builder(image(spec.cover))
            .setIncompleteLastColumnStrategy(SpotlightSection.INCOMPLETE_LAST_COLUMN_AS_IS)
        if (!spec.title.isNullOrEmpty()) section.setTitle(spec.title)
        for (item in spec.items) {
            section.addItem(condensedItem(item, image, onIntent, CondensedItem.IMAGE_TYPE_SMALL))
        }
        return section.build()
    }

    private fun condensedItem(
        spec: CondensedItemSpec,
        image: (ImageSpec?) -> CarIcon,
        onIntent: (CarIntent) -> Unit,
        imageType: Int,
    ): CondensedItem {
        val item = CondensedItem.Builder().setTitle(spec.title)
        spec.text?.let { item.setText(it) }
        spec.leading?.let { item.setLeadingImage(image(it), imageType) }
        spec.onClick?.let { intent -> item.setOnClickListener { onIntent(intent) } }
        return item.build()
    }
}
