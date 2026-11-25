package com.mossapps.flick

import android.support.v4.media.session.PlaybackStateCompat

/** The loop modes the session shows: Dart's quick cycle, `off`, `all`, `one`. */
internal object LoopMode {
    const val OFF = "off"
    const val ALL = "all"
    const val ONE = "one"

    // The order Dart's `toggleLoop` steps through.
    private val cycle = listOf(OFF, ALL, ONE)

    /** Anything unknown is `off`, like a Dart loop mode outside the quick cycle. */
    fun normalize(raw: String?): String = when (raw?.trim()?.lowercase()) {
        ALL -> ALL
        ONE -> ONE
        else -> OFF
    }

    fun toRepeatMode(loopMode: String?): Int = when (normalize(loopMode)) {
        ALL -> PlaybackStateCompat.REPEAT_MODE_ALL
        ONE -> PlaybackStateCompat.REPEAT_MODE_ONE
        else -> PlaybackStateCompat.REPEAT_MODE_NONE
    }

    fun fromRepeatMode(repeatMode: Int): String = when (repeatMode) {
        PlaybackStateCompat.REPEAT_MODE_ONE -> ONE
        PlaybackStateCompat.REPEAT_MODE_ALL,
        PlaybackStateCompat.REPEAT_MODE_GROUP -> ALL
        else -> OFF
    }

    fun title(loopMode: String?): String = when (normalize(loopMode)) {
        ALL -> "Repeat all"
        ONE -> "Repeat one"
        else -> "Repeat off"
    }

    /** How many `toggleLoop` commands move [current] to [target]. */
    fun togglesToReach(current: String?, target: String?): Int {
        val from = cycle.indexOf(normalize(current))
        val to = cycle.indexOf(normalize(target))
        return (to - from + cycle.size) % cycle.size
    }
}
