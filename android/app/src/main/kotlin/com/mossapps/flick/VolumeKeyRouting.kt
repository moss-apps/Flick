package com.mossapps.flick

import android.media.AudioManager
import android.view.KeyEvent

/** Who the media session's remote volume (system panel, background keys) drives. */
internal enum class SessionVolumeRoute { LOCAL, CAST, DAC }

internal data class DacVolumeState(val generation: Long, val percent: Int)

/** Main-looper state shared by the activity and an already running media session. */
internal object DacVolumeKeys {
    var onChange: (() -> Unit)? = null
    var state: DacVolumeState? = null
        set(value) {
            if (field == value) return
            field = value
            onChange?.invoke()
        }
}

/** Own the whole key sequence, including the release after a DAC has gone away. */
internal class ForegroundVolumeKeys {
    private data class Press(val downTime: Long, val generation: Long)
    private val pressed = mutableMapOf<Pair<Int, Int>, Press>()

    fun down(deviceId: Int, direction: Int, downTime: Long, repeat: Int, generation: Long?): Long? {
        val key = deviceId to direction
        if (repeat == 0) {
            pressed.remove(key)
            if (generation != null) pressed[key] = Press(downTime, generation)
        }
        return pressed[key]?.takeIf { it.downTime == downTime }?.generation
    }

    fun up(deviceId: Int, direction: Int, downTime: Long): Boolean {
        val key = deviceId to direction
        if (pressed[key]?.downTime != downTime) return false
        pressed.remove(key)
        return true
    }
}

/**
 * One MediaSession has one volume provider. Cast wins: while casting the audio
 * is on the cast target, not the DAC. The DAC only takes over when nothing is
 * being cast, and everything else stays on the system (STREAM_MUSIC) volume.
 */
internal fun sessionVolumeRoute(isCasting: Boolean, dacActive: Boolean): SessionVolumeRoute =
    when {
        isCasting -> SessionVolumeRoute.CAST
        dacActive -> SessionVolumeRoute.DAC
        else -> SessionVolumeRoute.LOCAL
    }

/** +1 / -1 for the phone's volume up / down keys, 0 for every other key. */
internal fun volumeKeyDirection(keyCode: Int): Int = when (keyCode) {
    KeyEvent.KEYCODE_VOLUME_UP -> 1
    KeyEvent.KEYCODE_VOLUME_DOWN -> -1
    else -> 0
}

/**
 * Step for a remote-volume adjust request. Mute, unmute, toggle-mute and
 * ADJUST_SAME are not a level change, so the DAC volume is left alone.
 */
internal fun remoteVolumeAdjustStep(direction: Int): Int = when (direction) {
    AudioManager.ADJUST_RAISE -> 1
    AudioManager.ADJUST_LOWER -> -1
    else -> 0
}
