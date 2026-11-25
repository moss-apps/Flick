package com.mossapps.flick

import android.support.v4.media.session.PlaybackStateCompat
import org.junit.Assert.assertEquals
import org.junit.Test

class LoopModeTest {
    @Test
    fun mapsLoopModeToRepeatMode() {
        assertEquals(PlaybackStateCompat.REPEAT_MODE_NONE, LoopMode.toRepeatMode("off"))
        assertEquals(PlaybackStateCompat.REPEAT_MODE_ALL, LoopMode.toRepeatMode("all"))
        assertEquals(PlaybackStateCompat.REPEAT_MODE_ONE, LoopMode.toRepeatMode("one"))
    }

    @Test
    fun unknownLoopModesAreOff() {
        for (raw in listOf(null, "", "advanceAlbum", "stopAfterCurrent", "ALL1")) {
            assertEquals(raw, "off", LoopMode.normalize(raw))
            assertEquals(raw, PlaybackStateCompat.REPEAT_MODE_NONE, LoopMode.toRepeatMode(raw))
        }
        assertEquals("all", LoopMode.normalize(" ALL "))
    }

    @Test
    fun mapsRepeatModeBack() {
        assertEquals("off", LoopMode.fromRepeatMode(PlaybackStateCompat.REPEAT_MODE_NONE))
        assertEquals("one", LoopMode.fromRepeatMode(PlaybackStateCompat.REPEAT_MODE_ONE))
        assertEquals("all", LoopMode.fromRepeatMode(PlaybackStateCompat.REPEAT_MODE_ALL))
        assertEquals("all", LoopMode.fromRepeatMode(PlaybackStateCompat.REPEAT_MODE_GROUP))
        assertEquals("off", LoopMode.fromRepeatMode(PlaybackStateCompat.REPEAT_MODE_INVALID))
    }

    @Test
    fun titlesFollowTheMode() {
        assertEquals("Repeat off", LoopMode.title("off"))
        assertEquals("Repeat all", LoopMode.title("all"))
        assertEquals("Repeat one", LoopMode.title("one"))
        assertEquals("Repeat off", LoopMode.title(null))
    }

    @Test
    fun togglesFollowDartsOffAllOneCycle() {
        assertEquals(0, LoopMode.togglesToReach("off", "off"))
        assertEquals(1, LoopMode.togglesToReach("off", "all"))
        assertEquals(2, LoopMode.togglesToReach("off", "one"))
        assertEquals(1, LoopMode.togglesToReach("all", "one"))
        assertEquals(2, LoopMode.togglesToReach("all", "off"))
        assertEquals(1, LoopMode.togglesToReach("one", "off"))
        assertEquals(0, LoopMode.togglesToReach("one", "one"))
        assertEquals(1, LoopMode.togglesToReach("advanceAlbum", "all"))
    }
}
