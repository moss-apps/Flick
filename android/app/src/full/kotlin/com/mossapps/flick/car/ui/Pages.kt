package com.mossapps.flick.car.ui

import com.mossapps.flick.car.CarStrings
import com.mossapps.flick.car.model.CarCollection
import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarHome
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.model.CarLoop
import com.mossapps.flick.car.model.CarQueue
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.model.CarTrack

/**
 * Every page of the car UI as pure functions `(view model, api9) -> PageSpec`
 * (docs/ANDROID_AUTO_DESIGN.md, sections 2 and 6). No androidx.car import: a JVM test
 * builds each page at level 8 and 9 over rich fixtures. A spec that needs level 9
 * implements [Api9Spec] and is only ever produced when [api9] is true.
 */
object Pages {
    // ------------------------------------------------------------------ root

    fun root(vm: RootVm, api9: Boolean): PageSpec {
        val end = mutableListOf(ActionSpec(CarStrings.SEARCH, CarIntent.OpenSearch))
        if (vm.hasUpNext) end += ActionSpec(CarStrings.UP_NEXT, CarIntent.OpenUpNext)
        val header = HeaderSpec(CarStrings.APP_NAME, StartAction.APP_ICON, end)

        if (vm.engine == EngineState.STARTING) {
            return SectionedPage(header, emptyList(), loading = true, playbackAction = !api9)
        }
        if (vm.engine == EngineState.STILL_STARTING) {
            return SectionedPage(
                header,
                listOf(
                    stateSection(
                        api9,
                        CarStrings.STILL_STARTING,
                        CarStrings.STILL_STARTING_DETAIL,
                        retry = true,
                    ),
                ),
                playbackAction = !api9,
            )
        }

        val home = vm.home
        if (home == null) {
            return when (vm.homeState) {
                LoadState.FAILED -> SectionedPage(
                    header,
                    listOf(stateSection(api9, CarStrings.COULDNT_LOAD, null, retry = true)),
                    playbackAction = !api9,
                )
                else -> SectionedPage(header, emptyList(), loading = true, playbackAction = !api9)
            }
        }

        val sections = mutableListOf<SectionSpec>()
        // The destination chips are the one ChipSection and come first.
        if (api9) sections += destinationChips(vm.tab)
        if (vm.homeState == LoadState.FAILED) {
            sections += stateSection(api9, CarStrings.COULDNT_REFRESH, null, retry = true)
        }

        if (home.counts.songs == 0 && home.resume == null) {
            sections += libraryEmptySection(api9)
        } else if (api9 && vm.tab != RootTab.HOME) {
            sections += tabSections(vm)
        } else if (api9) {
            sections += homeSections9(vm, home)
        } else {
            sections += homeSections8(home)
        }
        return SectionedPage(header, sections, playbackAction = !api9)
    }

    private fun destinationChips(selected: RootTab): ChipSectionSpec {
        val tabs = listOf(
            RootTab.HOME to CarStrings.TAB_HOME,
            RootTab.ALBUMS to CarStrings.TAB_ALBUMS,
            RootTab.ARTISTS to CarStrings.TAB_ARTISTS,
            RootTab.PLAYLISTS to CarStrings.TAB_PLAYLISTS,
        )
        return ChipSectionSpec(
            tabs.map { (tab, title) ->
                val isSelected = tab == selected
                ChipSpec(
                    title = title,
                    selected = isSelected,
                    look = if (isSelected) filledLook(CarPalette.SILVER) else outlinedLook(CarPalette.OUTLINE),
                    // Tapping the selected chip returns to Home.
                    onClick = CarIntent.SelectTab(if (isSelected) RootTab.HOME else tab),
                )
            },
        )
    }

    private fun filledLook(fill: Int) = ChipLook(fill, fill, CarPalette.contentOn(fill))

    private fun outlinedLook(outline: Int) = ChipLook(null, outline, CarPalette.WHITE)

    /** A one-line state: a banner at 9, a row at 8. */
    private fun stateSection(api9: Boolean, message: String, detail: String?, retry: Boolean): SectionSpec {
        return if (api9) {
            BannerSectionSpec(
                BannerSpec(
                    title = message,
                    subtitle = detail,
                    action = if (retry) ActionSpec(CarStrings.RETRY, CarIntent.Retry) else null,
                ),
            )
        } else {
            RowSectionSpec(
                null,
                listOf(
                    RowSpec(
                        title = if (retry) CarStrings.dotted(message, CarStrings.RETRY) else message,
                        texts = listOfNotNull(detail),
                        imageSize = RowImage.NONE,
                        onClick = if (retry) CarIntent.Retry else null,
                    ),
                ),
            )
        }
    }

    private fun libraryEmptySection(api9: Boolean): SectionSpec {
        return if (api9) {
            BannerSectionSpec(BannerSpec(title = CarStrings.LIBRARY_EMPTY, fill = CarPalette.ACID))
        } else {
            RowSectionSpec(
                null,
                listOf(RowSpec(title = CarStrings.LIBRARY_EMPTY, imageSize = RowImage.NONE)),
            )
        }
    }

    // ---- home, level 8

    private fun homeSections8(home: CarHome): List<SectionSpec> {
        val sections = mutableListOf<SectionSpec>()

        val quick = mutableListOf<RowSpec>()
        home.resume?.let { track ->
            quick += RowSpec(
                title = CarStrings.resumeTitle(track.title.ifBlank { CarStrings.UNKNOWN_TITLE }),
                texts = listOfNotNull(track.artist.ifBlank { null }),
                image = ImageSpec.icon(IconId.PLAY),
                imageSize = RowImage.SMALL,
                onClick = CarIntent.Resume,
            )
        }
        if (home.counts.songs > 0) {
            quick += RowSpec(
                title = CarStrings.shuffleAll(home.counts.songs),
                image = ImageSpec.icon(IconId.SHUFFLE),
                imageSize = RowImage.SMALL,
                onClick = CarIntent.Play("songs", "", shuffle = true),
            )
        }
        if (quick.isNotEmpty()) sections += RowSectionSpec(CarStrings.QUICK_PLAY, quick)

        val jump = home.jumpBackIn.take(CarLimits.JUMP_BACK_IN)
        if (jump.isNotEmpty()) {
            sections += GridSectionSpec(
                CarStrings.JUMP_BACK_IN,
                GridSize.SMALL,
                jump.map { coverTile(it) },
            )
        }

        val browse = browseTiles(home)
        if (browse.isNotEmpty()) {
            sections += GridSectionSpec(CarStrings.BROWSE, GridSize.SMALL, browse, iconTiles = true)
        }

        val added = home.recentlyAdded.take(CarLimits.RECENTLY_ADDED)
        if (added.isNotEmpty()) {
            sections += GridSectionSpec(CarStrings.RECENTLY_ADDED, GridSize.LARGE, added.map { coverTile(it) })
        }

        val played = home.mostPlayed.take(CarLimits.MOST_PLAYED)
        if (played.isNotEmpty()) {
            sections += RowSectionSpec(CarStrings.MOST_PLAYED, played.map { mostPlayedRow(it) })
        }

        val playlists = home.playlists.take(CarLimits.HOME_PLAYLISTS)
        if (playlists.isNotEmpty()) {
            sections += GridSectionSpec(CarStrings.PLAYLISTS, GridSize.LARGE, playlists.map { coverTile(it) })
        }
        return sections
    }

    /** The icon tiles of the level 8 Browse grid; a destination with nothing in it is left out. */
    private fun browseTiles(home: CarHome): List<GridItemSpec> {
        val counts = home.counts
        fun tile(title: String, icon: IconId, count: Int, onClick: CarIntent): GridItemSpec? =
            if (count <= 0) null else GridItemSpec(title, count.toString(), ImageSpec.icon(icon), onClick)
        return listOfNotNull(
            tile(CarStrings.ALBUMS, IconId.ALBUMS, counts.albums, CarIntent.OpenList(ListKind.ALBUMS)),
            tile(CarStrings.ARTISTS, IconId.ARTISTS, counts.artists, CarIntent.OpenList(ListKind.ARTISTS)),
            tile(CarStrings.PLAYLISTS, IconId.PLAYLISTS, counts.playlists, CarIntent.OpenList(ListKind.PLAYLISTS)),
            tile(
                CarStrings.SONGS,
                IconId.SONGS,
                counts.songs,
                CarIntent.OpenCollection("songs", "", CarStrings.SONGS),
            ),
            tile(
                CarStrings.FAVORITES,
                IconId.FAVORITES,
                counts.favorites,
                CarIntent.OpenCollection("favorites", "", CarStrings.FAVORITES),
            ),
            tile(CarStrings.FOLDERS, IconId.FOLDERS, counts.folders, CarIntent.OpenList(ListKind.FOLDERS)),
        )
    }

    // ---- home, level 9

    private fun homeSections9(vm: RootVm, home: CarHome): List<SectionSpec> {
        val sections = mutableListOf<SectionSpec>()
        val album = vm.albumColor

        val hero = mutableListOf<CondensedItemSpec>()
        var primaryTaken = false
        fun primaryTint(): IconTint {
            val tint = if (primaryTaken) IconTint(album) else IconTint(CarPalette.ACID)
            primaryTaken = true
            return tint
        }
        home.resume?.let { track ->
            hero += CondensedItemSpec(
                title = CarStrings.resumeTitle(track.title.ifBlank { CarStrings.UNKNOWN_TITLE }),
                leading = ImageSpec.icon(IconId.PLAY, primaryTint()),
                onClick = CarIntent.Resume,
            )
        }
        if (home.counts.songs > 0) {
            hero += CondensedItemSpec(
                title = CarStrings.shuffleAll(home.counts.songs),
                leading = ImageSpec.icon(IconId.SHUFFLE, primaryTint()),
                onClick = CarIntent.Play("songs", "", shuffle = true),
            )
        }
        if (home.queueCount > 0) {
            hero += CondensedItemSpec(
                title = CarStrings.upNextCount(home.queueCount),
                leading = ImageSpec.icon(IconId.QUEUE, IconTint(album)),
                onClick = CarIntent.OpenUpNext,
            )
        }
        if (hero.isNotEmpty()) {
            sections += SpotlightSectionSpec(null, heroCover(home), hero)
        }

        val jump = home.jumpBackIn.take(CarLimits.JUMP_BACK_IN)
        if (jump.isNotEmpty()) {
            sections += CondensedSectionSpec(
                CarStrings.JUMP_BACK_IN,
                jump.map { item ->
                    CondensedItemSpec(
                        title = item.title.ifBlank { CarStrings.UNTITLED },
                        text = collectionText(item),
                        leading = ImageSpec.cover(item.art),
                        onClick = openCollection(item),
                    )
                },
            )
        }

        val added = home.recentlyAdded.take(CarLimits.RECENTLY_ADDED)
        if (added.isNotEmpty()) {
            sections += GridSectionSpec(
                title = null,
                size = GridSize.LARGE,
                items = added.map { coverTile(it) },
                header = SectionHeaderSpec(
                    CarStrings.RECENTLY_ADDED,
                    subtitle = CarStrings.SEE_ALL,
                    onClick = CarIntent.OpenList(ListKind.RECENTLY_ADDED),
                ),
                lastRow = LastRowAsIs,
            )
        }

        val played = home.mostPlayed.take(CarLimits.MOST_PLAYED)
        if (played.isNotEmpty()) {
            sections += RowSectionSpec(
                title = null,
                rows = played.map { mostPlayedRow(it) },
                header = SectionHeaderSpec(
                    CarStrings.MOST_PLAYED,
                    subtitle = CarStrings.SEE_ALL,
                    onClick = CarIntent.OpenCollection("mostPlayed", "", CarStrings.MOST_PLAYED),
                ),
            )
        }

        val playlists = home.playlists.take(CarLimits.HOME_PLAYLISTS)
        if (playlists.isNotEmpty()) {
            sections += GridSectionSpec(
                title = null,
                size = GridSize.LARGE,
                items = playlists.map { coverTile(it) },
                header = SectionHeaderSpec(
                    CarStrings.PLAYLISTS,
                    subtitle = CarStrings.SEE_ALL,
                    onClick = CarIntent.OpenList(ListKind.PLAYLISTS),
                ),
                lastRow = LastRowAsIs,
            )
        }

        val library = libraryItems(home)
        if (library.isNotEmpty()) {
            sections += CondensedSectionSpec(CarStrings.LIBRARY, library)
        }
        return sections
    }

    /** The cover of the current or last song, else any cover on the page. */
    private fun heroCover(home: CarHome): ImageSpec {
        val art = home.resume?.art
            ?: home.mostPlayed.firstNotNullOfOrNull { it.art }
            ?: home.jumpBackIn.firstNotNullOfOrNull { it.art }
            ?: home.recentlyAdded.firstNotNullOfOrNull { it.art }
        return ImageSpec.cover(art)
    }

    /** Songs, Favorites and Folders: the chips already cover the rest. */
    private fun libraryItems(home: CarHome): List<CondensedItemSpec> {
        val tint = IconTint(CarPalette.SILVER)
        val counts = home.counts
        return listOfNotNull(
            if (counts.songs > 0) {
                CondensedItemSpec(
                    CarStrings.SONGS,
                    counts.songs.toString(),
                    ImageSpec.icon(IconId.SONGS, tint),
                    CarIntent.OpenCollection("songs", "", CarStrings.SONGS),
                )
            } else {
                null
            },
            if (counts.favorites > 0) {
                CondensedItemSpec(
                    CarStrings.FAVORITES,
                    counts.favorites.toString(),
                    ImageSpec.icon(IconId.FAVORITES, tint),
                    CarIntent.OpenCollection("favorites", "", CarStrings.FAVORITES),
                )
            } else {
                null
            },
            if (counts.folders > 0) {
                CondensedItemSpec(
                    CarStrings.FOLDERS,
                    counts.folders.toString(),
                    ImageSpec.icon(IconId.FOLDERS, tint),
                    CarIntent.OpenList(ListKind.FOLDERS),
                )
            } else {
                null
            },
        )
    }

    // ---- chip destinations (level 9)

    private fun tabSections(vm: RootVm): List<SectionSpec> {
        val kind = when (vm.tab) {
            RootTab.ALBUMS -> ListKind.ALBUMS
            RootTab.ARTISTS -> ListKind.ARTISTS
            RootTab.PLAYLISTS -> ListKind.PLAYLISTS
            RootTab.HOME -> return emptyList()
        }
        return listBody(kind, vm.tabList, vm.tabState, api9 = true)
    }

    /**
     * The body of a list destination: loading, failed, empty, or the capped items followed
     * by "Search to find more" when the list was cut.
     */
    private fun listBody(kind: ListKind, list: CarList?, state: LoadState, api9: Boolean): List<SectionSpec> {
        if (list == null) {
            return when (state) {
                LoadState.FAILED -> listOf(stateSection(api9, CarStrings.COULDNT_LOAD, null, retry = true))
                else -> listOf(messageSection(CarStrings.LOADING))
            }
        }
        val shown = list.items.take(CarLimits.LIST)
        if (shown.isEmpty()) return listOf(messageSection(CarStrings.NOTHING_HERE))
        val sections = mutableListOf<SectionSpec>()
        if (kind == ListKind.FOLDERS) {
            sections += RowSectionSpec(
                null,
                shown.map { item ->
                    RowSpec(
                        title = item.title.ifBlank { CarStrings.UNTITLED },
                        texts = listOfNotNull(collectionText(item)),
                        image = ImageSpec.cover(item.art),
                        browsable = true,
                        onClick = openCollection(item),
                    )
                },
            )
        } else {
            sections += GridSectionSpec(
                title = null,
                size = GridSize.LARGE,
                items = shown.map { coverTile(it) },
                circle = kind == ListKind.ARTISTS,
                lastRow = if (api9) LastRowAsIs else null,
            )
        }
        if (list.total > shown.size) sections += searchMoreSection(shown.size, list.total)
        return sections
    }

    // ------------------------------------------------------------ collection

    fun collection(vm: CollectionVm, api9: Boolean): PageSpec {
        return when (val target = vm.target) {
            is CollectionTarget.Listing -> listing(vm, target, api9)
            is CollectionTarget.Content -> content(vm, target, api9)
        }
    }

    private fun listing(vm: CollectionVm, target: CollectionTarget.Listing, api9: Boolean): PageSpec {
        val end = mutableListOf<ActionSpec>()
        if (vm.hasUpNext) end += ActionSpec(CarStrings.UP_NEXT, CarIntent.OpenUpNext)
        val header = HeaderSpec(target.title, StartAction.BACK, end)
        if (vm.state == LoadState.LOADING && vm.list == null) {
            return SectionedPage(header, emptyList(), loading = true, playbackAction = !api9)
        }
        return SectionedPage(
            header,
            listBody(target.kind, vm.list, vm.state, api9),
            playbackAction = !api9,
        )
    }

    private val INDEXED_KINDS = setOf("songs", "favorites", "folder")

    private fun content(vm: CollectionVm, target: CollectionTarget.Content, api9: Boolean): PageSpec {
        val detail = vm.detail
        val title = detail?.title?.takeIf { it.isNotBlank() } ?: target.title
        val canPlay = detail != null && (detail.tracks.isNotEmpty())

        val end = mutableListOf<ActionSpec>()
        if (canPlay) {
            end += ActionSpec(CarStrings.SHUFFLE, CarIntent.Play(target.kind, target.id, shuffle = true))
        }
        if (vm.hasUpNext) end += ActionSpec(CarStrings.UP_NEXT, CarIntent.OpenUpNext)
        val modern = if (api9 && detail != null) {
            HeaderModern(
                subtitle = CarStrings.dotted(
                    detail.subtitle,
                    if (detail.total > 0) CarStrings.songCount(detail.total) else null,
                    detail.quality,
                ).ifBlank { null },
                startImage = ImageSpec.cover(detail.art),
            )
        } else {
            null
        }
        val header = HeaderSpec(title, StartAction.BACK, end, modern)

        if (detail == null) {
            return when (vm.state) {
                LoadState.FAILED -> SectionedPage(
                    header,
                    listOf(stateSection(api9, CarStrings.COULDNT_LOAD, null, retry = true)),
                    playbackAction = !api9,
                )
                else -> SectionedPage(header, emptyList(), loading = true, playbackAction = !api9)
            }
        }

        val isAlbum = target.kind == "album"
        val isArtist = target.kind == "artist"
        val tracks = detail.tracks.take(CarLimits.LIST)
        val albums = detail.albums.take(CarLimits.LIST)
        val truncated = detail.total > tracks.size
        val sections = mutableListOf<SectionSpec>()

        if (tracks.isNotEmpty()) {
            sections += playActions(target, vm, isArtist, detail, api9)
            if (truncated) {
                sections += RowSectionSpec(
                    null,
                    listOf(
                        RowSpec(
                            title = CarStrings.shuffleAllSongs(detail.total),
                            image = ImageSpec.icon(IconId.SHUFFLE),
                            imageSize = RowImage.SMALL,
                            onClick = CarIntent.Play(target.kind, target.id, shuffle = true),
                        ),
                    ),
                )
            }
        }
        if (isArtist && albums.isNotEmpty()) {
            sections += GridSectionSpec(
                title = CarStrings.ALBUMS,
                size = GridSize.LARGE,
                items = albums.map { coverTile(it) },
                lastRow = if (api9) LastRowAsIs else null,
            )
        }
        if (tracks.isNotEmpty()) {
            sections += RowSectionSpec(
                title = if (isArtist && albums.isNotEmpty()) CarStrings.SONGS else null,
                rows = tracks.map { trackRow(it, target, isAlbum, indexed = target.kind in INDEXED_KINDS) },
            )
            if (truncated) sections += searchMoreSection(tracks.size, detail.total)
        }
        if (tracks.isEmpty() && albums.isEmpty()) sections += messageSection(CarStrings.NOTHING_HERE)

        return SectionedPage(
            header,
            sections,
            loading = false,
            playbackAction = !api9,
            indexing = target.kind in INDEXED_KINDS && tracks.isNotEmpty(),
        )
    }

    /** Play, Shuffle and Add to Up next: chips at 9 (a spotlight for an artist), two rows at 8. */
    private fun playActions(
        target: CollectionTarget.Content,
        vm: CollectionVm,
        isArtist: Boolean,
        detail: CarCollectionDetail,
        api9: Boolean,
    ): SectionSpec {
        val play = CarIntent.Play(target.kind, target.id)
        val shuffle = CarIntent.Play(target.kind, target.id, shuffle = true)
        val enqueue = CarIntent.Enqueue(target.kind, target.id)
        if (!api9) {
            return RowSectionSpec(
                null,
                listOf(
                    RowSpec(
                        CarStrings.PLAY,
                        image = ImageSpec.icon(IconId.PLAY),
                        imageSize = RowImage.SMALL,
                        onClick = play,
                    ),
                    RowSpec(
                        CarStrings.ADD_TO_UP_NEXT,
                        image = ImageSpec.icon(IconId.ADD_QUEUE),
                        imageSize = RowImage.SMALL,
                        onClick = enqueue,
                    ),
                ),
            )
        }
        if (isArtist) {
            val tint = IconTint(if (vm.playing) vm.albumColor else CarPalette.SILVER)
            return SpotlightSectionSpec(
                title = null,
                cover = ImageSpec.cover(detail.art),
                items = listOf(
                    CondensedItemSpec(
                        CarStrings.PLAY,
                        leading = ImageSpec.icon(IconId.PLAY, IconTint(CarPalette.ACID)),
                        onClick = play,
                    ),
                    CondensedItemSpec(
                        CarStrings.SHUFFLE,
                        leading = ImageSpec.icon(IconId.SHUFFLE, tint),
                        onClick = shuffle,
                    ),
                    CondensedItemSpec(
                        CarStrings.ADD_TO_UP_NEXT,
                        leading = ImageSpec.icon(IconId.ADD_QUEUE, tint),
                        onClick = enqueue,
                    ),
                ),
            )
        }
        // The chips of the playing album's collection take the ALBUM colour.
        val outline = if (vm.playing) vm.albumColor else CarPalette.OUTLINE
        val outlined = outlinedLook(outline)
        val secondaryTint = IconTint(if (vm.playing) vm.albumColor else CarPalette.WHITE)
        return ChipSectionSpec(
            listOf(
                ChipSpec(
                    CarStrings.PLAY,
                    selected = false,
                    look = filledLook(CarPalette.ACID),
                    icon = ImageSpec.icon(IconId.PLAY, IconTint(CarPalette.INK)),
                    onClick = play,
                ),
                ChipSpec(
                    CarStrings.SHUFFLE,
                    selected = false,
                    look = outlined,
                    icon = ImageSpec.icon(IconId.SHUFFLE, secondaryTint),
                    onClick = shuffle,
                ),
                ChipSpec(
                    CarStrings.ADD_TO_UP_NEXT,
                    selected = false,
                    look = outlined,
                    icon = ImageSpec.icon(IconId.ADD_QUEUE, secondaryTint),
                    onClick = enqueue,
                ),
            ),
        )
    }

    /**
     * Tapping a track plays the whole collection from that track, like the phone. An album has
     * no per-row cover: "{track no} . {duration}". Other lists show the cover and "{artist} . {duration}".
     */
    private fun trackRow(
        track: CarTrack,
        target: CollectionTarget.Content,
        isAlbum: Boolean,
        indexed: Boolean,
    ): RowSpec {
        val title = track.title.ifBlank { CarStrings.UNKNOWN_TITLE }
        val duration = CarStrings.duration(track.durationMs)
        val play = CarIntent.Play(target.kind, target.id, track.id)
        return if (isAlbum) {
            RowSpec(
                title = title,
                texts = listOf(CarStrings.dotted(track.trackNo?.toString(), duration)).filter { it.isNotEmpty() },
                imageSize = RowImage.NONE,
                indexable = indexed,
                onClick = play,
            )
        } else {
            RowSpec(
                title = title,
                texts = listOf(CarStrings.dotted(track.artist, duration)).filter { it.isNotEmpty() },
                image = ImageSpec.cover(track.art),
                imageSize = RowImage.LARGE,
                indexable = indexed,
                onClick = play,
            )
        }
    }

    // -------------------------------------------------------------- up next

    fun queue(vm: QueueVm, api9: Boolean): PageSpec {
        val queue = vm.queue
        val end = mutableListOf<ActionSpec>()
        // Clear empties only the driver's own queue, so it is offered only when there is one.
        if (queue != null && queue.fromYou.isNotEmpty()) {
            end += ActionSpec(CarStrings.CLEAR, CarIntent.ClearQueue)
        }
        val header = HeaderSpec(CarStrings.UP_NEXT, StartAction.BACK, end)

        if (queue == null) {
            return when (vm.state) {
                LoadState.FAILED -> SectionedPage(
                    header,
                    listOf(stateSection(api9, CarStrings.COULDNT_LOAD, null, retry = true)),
                    playbackAction = !api9,
                )
                else -> SectionedPage(header, emptyList(), loading = true, playbackAction = !api9)
            }
        }

        val sections = mutableListOf<SectionSpec>()
        sections += modeSections(queue, vm.albumColor, api9)

        queue.current?.let { current ->
            sections += queueRowSection(
                api9,
                CarStrings.NOW_PLAYING,
                null,
                listOf(queueRow(current, null)),
            )
        }

        val you = queue.fromYou.take(CarLimits.QUEUE)
        val context = queue.fromContext.take((CarLimits.QUEUE - you.size).coerceAtLeast(0))
        if (you.isNotEmpty()) {
            sections += queueRowSection(
                api9,
                CarStrings.NEXT_FROM_YOU,
                CarStrings.songCount(you.size),
                you.mapIndexed { index, track -> queueRow(track, CarIntent.Jump("you", index)) },
            )
        }
        if (context.isNotEmpty()) {
            sections += queueRowSection(
                api9,
                CarStrings.nextFrom(queue.contextName),
                CarStrings.songCount(context.size),
                context.mapIndexed { index, track -> queueRow(track, CarIntent.Jump("context", index)) },
            )
        }
        if (you.isEmpty() && context.isEmpty()) sections += messageSection(CarStrings.QUEUE_EMPTY)

        return SectionedPage(header, sections, playbackAction = !api9)
    }

    /** Shuffle and repeat: chips at 9 (selected = active, in the ALBUM colour), a "Playback" list at 8. */
    private fun modeSections(queue: CarQueue, albumColor: Int, api9: Boolean): List<SectionSpec> {
        val repeatTitle = when (queue.loop) {
            CarLoop.OFF -> CarStrings.REPEAT_OFF
            CarLoop.ALL -> CarStrings.REPEAT_ALL
            CarLoop.ONE -> CarStrings.REPEAT_ONE
        }
        val repeatIcon = if (queue.loop == CarLoop.ONE) IconId.REPEAT_ONE else IconId.REPEAT
        val shuffleTitle = if (queue.shuffle) CarStrings.SHUFFLE_ON else CarStrings.SHUFFLE_OFF
        val repeatActive = queue.loop != CarLoop.OFF
        if (!api9) {
            return listOf(
                RowSectionSpec(
                    CarStrings.PLAYBACK,
                    listOf(
                        RowSpec(
                            shuffleTitle,
                            image = ImageSpec.icon(IconId.SHUFFLE),
                            imageSize = RowImage.SMALL,
                            onClick = CarIntent.ToggleShuffle,
                        ),
                        RowSpec(
                            repeatTitle,
                            image = ImageSpec.icon(repeatIcon),
                            imageSize = RowImage.SMALL,
                            onClick = CarIntent.CycleLoop,
                        ),
                    ),
                ),
            )
        }
        fun chip(title: String, active: Boolean, icon: IconId, intent: CarIntent): ChipSpec {
            val look = if (active) filledLook(albumColor) else outlinedLook(CarPalette.OUTLINE)
            val tint = IconTint(if (active) look.content else CarPalette.WHITE)
            return ChipSpec(title, active, look, ImageSpec.icon(icon, tint), intent)
        }
        return listOf(
            ChipSectionSpec(
                listOf(
                    chip(shuffleTitle, queue.shuffle, IconId.SHUFFLE, CarIntent.ToggleShuffle),
                    chip(repeatTitle, repeatActive, repeatIcon, CarIntent.CycleLoop),
                ),
            ),
        )
    }

    private fun queueRow(track: CarTrack, onClick: CarIntent?): RowSpec = RowSpec(
        title = track.title.ifBlank { CarStrings.UNKNOWN_TITLE },
        texts = listOfNotNull(track.artist.ifBlank { null }),
        image = ImageSpec.cover(track.art),
        imageSize = RowImage.LARGE,
        onClick = onClick,
    )

    /** A boundary header: a section header with a headline at 9, a section title at 8. */
    private fun queueRowSection(api9: Boolean, title: String, headline: String?, rows: List<RowSpec>): RowSectionSpec {
        return if (api9) {
            RowSectionSpec(null, rows, SectionHeaderSpec(title, headline = headline))
        } else {
            RowSectionSpec(title, rows)
        }
    }

    // --------------------------------------------------------------- search

    fun search(vm: SearchVm, api9: Boolean): PageSpec {
        val loading = vm.phase == SearchPhase.LOADING
        if (!api9) return search8(vm, loading)

        val sections = mutableListOf<SectionSpec>()
        val results = vm.results
        when {
            loading -> Unit
            vm.phase == SearchPhase.FAILED -> sections += RowSectionSpec(
                null,
                listOf(
                    RowSpec(
                        CarStrings.dotted(CarStrings.SEARCH_FAILED, CarStrings.RETRY),
                        imageSize = RowImage.NONE,
                        onClick = CarIntent.Retry,
                    ),
                ),
            )
            results == null || vm.query.isBlank() -> sections += messageSection(CarStrings.SEARCH_PROMPT)
            results.isEmpty -> sections += messageSection(CarStrings.NO_RESULTS)
            else -> sections += searchSections(results, vm.query.trim())
        }
        return SectionedPage(
            header = null,
            sections = sections,
            search = SearchHeaderSpec(vm.query, CarStrings.SEARCH_HINT),
            loading = loading,
        )
    }

    private fun searchSections(results: CarSearchResults, query: String): List<SectionSpec> {
        val cap = CarLimits.SEARCH_PER_TYPE
        val sections = mutableListOf<SectionSpec>()
        if (results.tracks.isNotEmpty()) {
            sections += RowSectionSpec(CarStrings.SONGS, results.tracks.take(cap).map { searchTrackRow(it, query) })
        }
        if (results.albums.isNotEmpty()) {
            sections += GridSectionSpec(
                CarStrings.ALBUMS,
                GridSize.LARGE,
                results.albums.take(cap).map { coverTile(it) },
                lastRow = LastRowAsIs,
            )
        }
        if (results.artists.isNotEmpty()) {
            sections += GridSectionSpec(
                CarStrings.ARTISTS,
                GridSize.LARGE,
                results.artists.take(cap).map { coverTile(it) },
                circle = true,
                lastRow = LastRowAsIs,
            )
        }
        if (results.playlists.isNotEmpty()) {
            sections += GridSectionSpec(
                CarStrings.PLAYLISTS,
                GridSize.LARGE,
                results.playlists.take(cap).map { coverTile(it) },
                lastRow = LastRowAsIs,
            )
        }
        return sections
    }

    private fun searchTrackRow(track: CarTrack, query: String): RowSpec = RowSpec(
        title = track.title.ifBlank { CarStrings.UNKNOWN_TITLE },
        texts = listOfNotNull(track.artist.ifBlank { null }),
        image = ImageSpec.cover(track.art),
        imageSize = RowImage.LARGE,
        // A search result plays like a collection: the whole result list, from the tapped song.
        onClick = CarIntent.Play("search", query, track.id),
    )

    private fun search8(vm: SearchVm, loading: Boolean): PageSpec {
        val results = vm.results
        val rows = mutableListOf<RowSpec>()
        if (!loading && vm.phase == SearchPhase.READY && results != null) {
            val cap = CarLimits.SEARCH_PER_TYPE
            for (track in results.tracks.take(cap)) {
                rows += searchTrackRow(track, vm.query.trim()).copy(
                    texts = listOfNotNull(track.artist.ifBlank { null }, CarStrings.TYPE_SONG),
                )
            }
            for (item in results.albums.take(cap)) rows += searchCollectionRow(item, CarStrings.TYPE_ALBUM)
            for (item in results.artists.take(cap)) rows += searchCollectionRow(item, CarStrings.TYPE_ARTIST)
            for (item in results.playlists.take(cap)) rows += searchCollectionRow(item, CarStrings.TYPE_PLAYLIST)
        }
        val message = when {
            vm.phase == SearchPhase.FAILED -> CarStrings.SEARCH_FAILED
            vm.query.isBlank() || vm.phase == SearchPhase.IDLE -> CarStrings.SEARCH_PROMPT
            else -> CarStrings.NO_RESULTS
        }
        return SearchListPage(
            initialText = vm.query,
            hint = CarStrings.SEARCH_HINT,
            // A SearchTemplate list is cut to the host's limit.
            rows = rows.take(vm.listLimit.coerceAtLeast(1)),
            noItemsMessage = message,
            loading = loading,
        )
    }

    private fun searchCollectionRow(item: CarCollection, type: String): RowSpec = RowSpec(
        title = item.title.ifBlank { CarStrings.UNTITLED },
        texts = listOfNotNull(collectionText(item), type),
        image = ImageSpec.cover(item.art),
        imageSize = RowImage.LARGE,
        browsable = true,
        onClick = openCollection(item),
    )

    // --------------------------------------------------------------- player

    fun player(vm: PlayerVm, api9: Boolean): PageSpec {
        if (!vm.ready) {
            return if (vm.starting) {
                MessagePage(CarStrings.STARTING_PLAYBACK, loading = true)
            } else {
                MessagePage(
                    CarStrings.NOTHING_PLAYING,
                    actions = listOf(ActionSpec(CarStrings.BROWSE, CarIntent.Browse)),
                )
            }
        }
        val header = HeaderSpec(
            CarStrings.APP_NAME,
            StartAction.BACK,
            listOf(ActionSpec(CarStrings.UP_NEXT, CarIntent.OpenUpNext)),
        )
        return PlayerPage(header, if (api9) PlayerStyle9(vm.albumColor) else null)
    }

    // -------------------------------------------------------------- shared

    private fun openCollection(item: CarCollection): CarIntent =
        CarIntent.OpenCollection(item.kind, item.id, item.title.ifBlank { CarStrings.UNTITLED })

    /** The second line of a collection tile: "Artist . quality" for an album, "{n} songs" otherwise. */
    fun collectionText(item: CarCollection): String? {
        val text = when (item.kind) {
            "album" -> CarStrings.dotted(item.subtitle, item.quality)
            else -> CarStrings.dotted(item.subtitle, item.count?.let { CarStrings.songCount(it) })
        }
        return text.ifBlank { null }
    }

    private fun coverTile(item: CarCollection): GridItemSpec = GridItemSpec(
        title = item.title.ifBlank { CarStrings.UNTITLED },
        text = collectionText(item),
        image = ImageSpec.cover(item.art),
        onClick = openCollection(item),
    )

    private fun mostPlayedRow(track: CarTrack): RowSpec = RowSpec(
        title = track.title.ifBlank { CarStrings.UNKNOWN_TITLE },
        texts = listOf(CarStrings.dotted(track.artist, track.quality)).filter { it.isNotEmpty() },
        image = ImageSpec.cover(track.art),
        imageSize = RowImage.LARGE,
        onClick = CarIntent.Play("mostPlayed", "", track.id),
    )

    private fun messageSection(message: String, detail: String? = null, onClick: CarIntent? = null): SectionSpec =
        RowSectionSpec(
            null,
            listOf(
                RowSpec(
                    title = message,
                    texts = listOfNotNull(detail),
                    imageSize = RowImage.NONE,
                    onClick = onClick,
                ),
            ),
        )

    private fun searchMoreSection(shown: Int, total: Int): SectionSpec = messageSection(
        CarStrings.SEARCH_TO_FIND_MORE,
        CarStrings.showingFirst(shown, total),
        CarIntent.OpenSearch,
    )
}
