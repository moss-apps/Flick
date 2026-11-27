package com.mossapps.flick

import android.media.AudioManager
import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VolumeKeyRoutingTest {
    @Test
    fun castWinsOverTheDacWhenBothWantTheSessionVolume() {
        assertEquals(SessionVolumeRoute.CAST, sessionVolumeRoute(isCasting = true, dacActive = true))
        assertEquals(SessionVolumeRoute.CAST, sessionVolumeRoute(isCasting = true, dacActive = false))
    }

    @Test
    fun dacTakesTheSessionOnlyWhenNothingIsBeingCast() {
        assertEquals(SessionVolumeRoute.DAC, sessionVolumeRoute(isCasting = false, dacActive = true))
    }

    @Test
    fun everythingElseStaysOnTheSystemVolume() {
        assertEquals(SessionVolumeRoute.LOCAL, sessionVolumeRoute(isCasting = false, dacActive = false))
    }

    @Test
    fun onlyTheVolumeUpAndDownKeysHaveADirection() {
        assertEquals(1, volumeKeyDirection(KeyEvent.KEYCODE_VOLUME_UP))
        assertEquals(-1, volumeKeyDirection(KeyEvent.KEYCODE_VOLUME_DOWN))
        assertEquals(0, volumeKeyDirection(KeyEvent.KEYCODE_VOLUME_MUTE))
        assertEquals(0, volumeKeyDirection(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        assertEquals(0, volumeKeyDirection(KeyEvent.KEYCODE_BACK))
    }

    @Test
    fun aHeldKeyKeepsItsOriginalClaimThroughRepeatsAndRelease() {
        val keys = ForegroundVolumeKeys()
        assertEquals(41L, keys.down(0, 1, 100, 0, 41L))
        assertEquals(41L, keys.down(0, 1, 100, 1, 41L))
        assertEquals(41L, keys.down(0, 1, 100, 2, null))
        // The activity only sends when this captured generation is still current.
        assertEquals(41L, keys.down(0, 1, 100, 3, 42L))
        assertTrue(keys.up(0, 1, 100))
        assertEquals(42L, keys.down(0, 1, 200, 0, 42L))
    }

    @Test
    fun aKeyThatStartedOnTheSystemIsNotCapturedMidPress() {
        val keys = ForegroundVolumeKeys()
        assertNull(keys.down(0, -1, 100, 0, null))
        assertNull(keys.down(0, -1, 100, 1, 42L))
        assertFalse(keys.up(0, -1, 100))
        assertEquals(42L, keys.down(0, -1, 200, 0, 42L))
        assertNull(keys.down(1, -1, 200, 1, 42L))
        assertFalse(keys.up(0, -1, 100))
        assertTrue(keys.up(0, -1, 200))
    }

    @Test
    fun remoteAdjustRaisesAndLowersByOneStep() {
        assertEquals(1, remoteVolumeAdjustStep(AudioManager.ADJUST_RAISE))
        assertEquals(-1, remoteVolumeAdjustStep(AudioManager.ADJUST_LOWER))
    }

    @Test
    fun remoteMuteAndSameRequestsDoNotMoveTheDacVolume() {
        assertEquals(0, remoteVolumeAdjustStep(AudioManager.ADJUST_SAME))
        assertEquals(0, remoteVolumeAdjustStep(AudioManager.ADJUST_MUTE))
        assertEquals(0, remoteVolumeAdjustStep(AudioManager.ADJUST_UNMUTE))
        assertEquals(0, remoteVolumeAdjustStep(AudioManager.ADJUST_TOGGLE_MUTE))
    }
}
