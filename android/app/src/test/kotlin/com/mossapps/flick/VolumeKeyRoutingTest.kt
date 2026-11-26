package com.mossapps.flick

import android.media.AudioManager
import android.view.KeyEvent
import org.junit.Assert.assertEquals
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
