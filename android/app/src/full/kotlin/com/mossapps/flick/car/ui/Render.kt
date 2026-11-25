package com.mossapps.flick.car.ui

import android.util.Log
import androidx.car.app.media.model.MediaPlaybackTemplate
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridSection
import androidx.car.app.model.Header
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.RowSection
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Section
import androidx.car.app.model.SectionedItemTemplate
import androidx.car.app.model.Template
import com.mossapps.flick.car.CarStrings

/** Typing in the search page. */
interface SearchSink {
    fun textChanged(text: String)
    fun submitted(text: String)
}

/**
 * Turns page specs into car templates that are safe for a Car API 8 host.
 *
 * This file imports no API 9 class: everything that exists only at level 9 is built by
 * [Render9], and only for an [Api9Spec] when [api9] is true. A level 9 spec reaching
 * this renderer at level 8 is dropped and logged, never sent (docs/ANDROID_AUTO_DESIGN.md, 6).
 */
class Render(
    private val style: CarStyle,
    private val api9: Boolean,
    private val onIntent: (CarIntent) -> Unit,
    private val search: SearchSink? = null,
) {
    fun template(page: PageSpec): Template = when (page) {
        is SectionedPage -> sectioned(page)
        is SearchListPage -> searchList(page)
        is MessagePage -> message(page)
        is PlayerPage -> player(page)
    }

    // -------------------------------------------------------------- templates

    private fun sectioned(page: SectionedPage): Template {
        val template = SectionedItemTemplate.Builder()
        page.header?.let { template.setHeader(header(it)) }
        val searchHeader = page.search
        if (searchHeader != null && usable(searchHeader)) {
            Render9.searchHeader(template, searchHeader, search)
        }
        // At level 9 the host draws its own minimized control panel and ignores this.
        if (page.playbackAction && !api9) template.addAction(Action.MEDIA_PLAYBACK)
        if (page.loading) return template.setLoading(true).build()
        if (page.indexing) {
            // The strategy alone switches indexing on (setAlphabeticalIndexingAllowed is deprecated).
            template.setAlphabeticalIndexingStrategy(
                SectionedItemTemplate.ALPHABETICAL_INDEXING_TITLE_IGNORE_ARTICLES_AND_SYMBOLS,
            ).setScrollStatePersistenceStrategy(SectionedItemTemplate.SCROLL_STATE_PRESERVE_INDEX)
        }
        for (section in page.sections) section(section)?.let { template.addSection(it) }
        return template.build()
    }

    private fun searchList(page: SearchListPage): Template {
        val callback = object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {
                search?.textChanged(searchText)
            }

            override fun onSearchSubmitted(searchText: String) {
                search?.submitted(searchText)
            }
        }
        val template = SearchTemplate.Builder(callback)
            .setHeaderAction(Action.BACK)
            .setInitialSearchText(page.initialText)
            .setSearchHint(page.hint)
            .setShowKeyboardByDefault(true)
        if (page.loading) return template.setLoading(true).build()
        val list = ItemList.Builder().setNoItemsMessage(page.noItemsMessage)
        for (row in page.rows) list.addItem(row(row))
        return template.setItemList(list.build()).build()
    }

    private fun message(page: MessagePage): Template {
        val header = Header.Builder().setTitle(page.title ?: CarStrings.APP_NAME)
        when (page.start) {
            StartAction.BACK -> header.setStartHeaderAction(Action.BACK)
            StartAction.APP_ICON -> header.setStartHeaderAction(Action.APP_ICON)
            StartAction.NONE -> Unit
        }
        val template = MessageTemplate.Builder(page.message).setHeader(header.build())
        if (page.loading) {
            template.setLoading(true)
        } else {
            for (action in page.actions) template.addAction(action(action))
        }
        return template.build()
    }

    private fun player(page: PlayerPage): Template {
        val template = MediaPlaybackTemplate.Builder().setHeader(header(page.header))
        val playerStyle = page.style
        if (playerStyle != null && usable(playerStyle)) Render9.playerStyle(template, playerStyle)
        return template.build()
    }

    // ---------------------------------------------------------------- header

    private fun header(spec: HeaderSpec): Header {
        val header = Header.Builder().setTitle(spec.title)
        when (spec.start) {
            StartAction.BACK -> header.setStartHeaderAction(Action.BACK)
            StartAction.APP_ICON -> header.setStartHeaderAction(Action.APP_ICON)
            StartAction.NONE -> Unit
        }
        for (end in spec.end) header.addEndHeaderAction(action(end))
        val modern = spec.modern
        if (modern != null && usable(modern)) Render9.headerModern(header, modern, ::image)
        return header.build()
    }

    private fun action(spec: ActionSpec): Action =
        Action.Builder().setTitle(spec.title).setOnClickListener { onIntent(spec.onClick) }.build()

    // -------------------------------------------------------------- sections

    private fun section(spec: SectionSpec): Section<*>? {
        if (spec is Api9Spec && !usable(spec)) return null
        return when (spec) {
            is RowSectionSpec -> rowSection(spec)
            is GridSectionSpec -> gridSection(spec)
            is CondensedSectionSpec -> Render9.condensedSection(spec, ::image, onIntent)
            is SpotlightSectionSpec -> Render9.spotlightSection(spec, ::image, onIntent)
            is BannerSectionSpec -> Render9.bannerSection(spec, ::image, onIntent)
            is ChipSectionSpec -> Render9.chipSection(spec, ::image, onIntent)
        }
    }

    private fun rowSection(spec: RowSectionSpec): Section<*> {
        val section = RowSection.Builder()
        titled(spec.title, spec.header, { section.setTitle(it) }, { Render9.sectionHeader(section, it, onIntent) })
        for (row in spec.rows) section.addItem(row(row))
        return section.build()
    }

    private fun gridSection(spec: GridSectionSpec): Section<*> {
        val section = GridSection.Builder().setItemSize(
            when (spec.size) {
                GridSize.SMALL -> GridSection.ITEM_SIZE_SMALL
                GridSize.LARGE -> GridSection.ITEM_SIZE_LARGE
            },
        )
        if (spec.circle) section.setItemImageShape(GridSection.ITEM_IMAGE_SHAPE_CIRCLE)
        titled(spec.title, spec.header, { section.setTitle(it) }, { Render9.sectionHeader(section, it, onIntent) })
        val lastRow = spec.lastRow
        if (lastRow != null && usable(lastRow)) Render9.keepLastRow(section)
        for (item in spec.items) section.addItem(gridItem(item, spec.iconTiles))
        return section.build()
    }

    /** A plain title at every level; a section header only where level 9 allows one. */
    private fun titled(
        title: String?,
        header: SectionHeaderSpec?,
        setTitle: (String) -> Unit,
        setHeader: (SectionHeaderSpec) -> Unit,
    ) {
        if (header != null && usable(header)) {
            setHeader(header)
        } else if (!title.isNullOrEmpty()) {
            setTitle(title)
        }
    }

    // ------------------------------------------------------------------ items

    private fun row(spec: RowSpec): Row {
        val row = Row.Builder().setTitle(spec.title)
        for (text in spec.texts) row.addText(text)
        when (spec.imageSize) {
            RowImage.NONE -> Unit
            RowImage.SMALL -> row.setImage(image(spec.image), Row.IMAGE_TYPE_SMALL)
            RowImage.LARGE -> row.setImage(image(spec.image), Row.IMAGE_TYPE_LARGE)
        }
        if (spec.browsable) row.setBrowsable(true)
        if (spec.indexable) row.setIndexable(true)
        spec.onClick?.let { intent -> row.setOnClickListener { onIntent(intent) } }
        return row.build()
    }

    @Suppress("DEPRECATION")
    private fun gridItem(spec: GridItemSpec, iconTile: Boolean): GridItem {
        val item = GridItem.Builder().setTitle(spec.title)
        spec.text?.let { item.setText(it) }
        // GridItem has no non-deprecated icon image type, and a vector icon stretched to the
        // large cover slot looks wrong. The constant is only the int 1 and works at every level.
        if (iconTile) item.setImage(image(spec.image), GridItem.IMAGE_TYPE_ICON) else item.setImage(image(spec.image))
        spec.onClick?.let { intent -> item.setOnClickListener { onIntent(intent) } }
        return item.build()
    }

    /** A spec's image as a car icon: a cover, or a bundled icon (tinted at level 9 when it asks). */
    private fun image(spec: ImageSpec?): CarIcon {
        if (spec == null) return style.art(null)
        val icon = spec.icon ?: return style.art(spec.art)
        val tint = spec.tint
        return if (tint != null && usable(tint)) {
            Render9.tinted(style.iconCompat(icon), tint)
        } else {
            style.icon(icon)
        }
    }

    /** False for a level 9 spec at a level 8 host: it is dropped and logged, never sent. */
    private fun usable(spec: Api9Spec): Boolean {
        if (api9) return true
        Log.w(TAG, "dropping ${spec.javaClass.simpleName}: Car API 9 only")
        return false
    }

    private companion object {
        const val TAG = "CarRender"
    }
}
