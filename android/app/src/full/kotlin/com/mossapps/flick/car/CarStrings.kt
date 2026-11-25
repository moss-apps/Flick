package com.mossapps.flick.car

import java.util.Locale

/**
 * Every user-visible string of the car UI, English, in one place so it can be
 * localised later. Pure Kotlin on purpose: pages are built and tested on the JVM.
 */
object CarStrings {
    const val APP_NAME = "Flick"

    // Header and navigation
    const val SEARCH = "Search"
    const val UP_NEXT = "Up next"
    const val BROWSE = "Browse"
    const val RETRY = "Retry"
    const val SEE_ALL = "See all"

    // Root: destinations (modern chips)
    const val TAB_HOME = "Home"
    const val TAB_ALBUMS = "Albums"
    const val TAB_ARTISTS = "Artists"
    const val TAB_PLAYLISTS = "Playlists"

    // Root: sections
    const val QUICK_PLAY = "Quick play"
    const val JUMP_BACK_IN = "Jump back in"
    const val RECENTLY_ADDED = "Recently added"
    const val MOST_PLAYED = "Most played"
    const val LIBRARY = "Library"
    const val PLAYLISTS = "Playlists"
    const val SONGS = "Songs"
    const val FAVORITES = "Favorites"
    const val FOLDERS = "Folders"
    const val ALBUMS = "Albums"
    const val ARTISTS = "Artists"

    // Actions
    const val PLAY = "Play"
    const val SHUFFLE = "Shuffle"
    const val ADD_TO_UP_NEXT = "Add to Up next"
    const val CLEAR = "Clear"
    const val RESUME = "Resume"
    const val ADDED_TO_UP_NEXT = "Added to Up next"

    // Up next
    const val NOW_PLAYING = "Now playing"
    const val NEXT_FROM_YOU = "Next from you"
    const val PLAYBACK = "Playback"
    const val QUEUE_EMPTY = "Nothing queued — pick an album to start"

    // States
    const val LOADING = "Loading…"
    const val STILL_STARTING = "Flick is still starting"
    const val STILL_STARTING_DETAIL = "Open Flick on your phone if this takes long"
    const val LIBRARY_EMPTY = "Your library is empty — add music in Flick on your phone"
    const val COULDNT_REFRESH = "Couldn't refresh"
    const val COULDNT_LOAD = "Couldn't load"
    const val COULDNT_PLAY = "Couldn't start playback"
    const val NOTHING_HERE = "Nothing here yet"
    const val NOTHING_PLAYING = "Nothing playing yet"
    const val STARTING_PLAYBACK = "Starting playback…"
    const val SEARCH_TO_FIND_MORE = "Search to find more"
    const val NO_RESULTS = "No results"
    const val SEARCH_HINT = "Search your library"
    const val SEARCH_PROMPT = "Search songs, albums, artists and playlists"
    const val SEARCH_FAILED = "Search failed"
    const val TYPE_SONG = "Song"
    const val TYPE_ALBUM = "Album"
    const val TYPE_ARTIST = "Artist"
    const val TYPE_PLAYLIST = "Playlist"
    const val UNKNOWN_TITLE = "Unknown title"
    const val UNTITLED = "Untitled"

    // Settings of the session
    const val SHUFFLE_ON = "Shuffle on"
    const val SHUFFLE_OFF = "Shuffle off"
    const val REPEAT_OFF = "Repeat off"
    const val REPEAT_ALL = "Repeat all"
    const val REPEAT_ONE = "Repeat one"

    // Classic browse tree
    const val RECENTLY_PLAYED = "Recently played"

    fun songCount(n: Int): String = if (n == 1) "1 song" else "$n songs"

    fun upNextCount(n: Int): String = "$UP_NEXT · $n"

    fun resumeTitle(title: String): String = "$RESUME · $title"

    fun shuffleAll(count: Int?): String =
        if (count == null || count <= 0) "Shuffle all" else "Shuffle all · ${songCount(count)}"

    fun shuffleAllSongs(total: Int): String = "Shuffle all $total songs"

    fun nextFrom(contextName: String?): String =
        if (contextName.isNullOrBlank()) "Next up" else "Next from $contextName"

    fun showingFirst(shown: Int, total: Int): String = "Showing the first $shown of $total"

    /** "Artist · quality" and the other two-part lines; blank parts are skipped. */
    fun dotted(vararg parts: String?): String =
        parts.filter { !it.isNullOrBlank() }.joinToString(" · ")

    /** m:ss, or h:mm:ss from an hour on. Negative or absent durations read as blank. */
    fun duration(ms: Long): String {
        if (ms <= 0) return ""
        val totalSeconds = ms / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format(Locale.ROOT, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.ROOT, "%d:%02d", minutes, seconds)
        }
    }
}
