package com.mossapps.flick.car

import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import com.mossapps.flick.car.ui.CarLimits

/**
 * Navigation within the host's screen stack. The host allows five screens: root,
 * collection, collection (an album from an artist), Up next and the player fill it, so a
 * sixth push first pops back to the root (docs/ANDROID_AUTO_DESIGN.md, 2.0).
 */
object CarNav {
    const val STACK_LIMIT = CarLimits.STACK

    /** True when pushing one more screen would exceed the host's limit. */
    fun mustResetBeforePush(stackSize: Int): Boolean = stackSize >= STACK_LIMIT

    fun push(screens: ScreenManager, next: Screen) {
        if (mustResetBeforePush(screens.stackSize)) screens.popToRoot()
        screens.push(next)
    }
}

/**
 * Fences asynchronous answers. Every request takes a generation with [next]; an answer
 * is used only while [accepts] its generation, so a newer request, or the owner being
 * destroyed ([close]), drops the late one.
 */
class Fence {
    private var generation = 0
    private var closed = false

    /** Starts a new request and retires every earlier one. */
    fun next(): Int = ++generation

    fun accepts(token: Int): Boolean = !closed && token == generation

    /** Retires everything, for good. */
    fun close() {
        closed = true
    }

    val isClosed: Boolean
        get() = closed
}
