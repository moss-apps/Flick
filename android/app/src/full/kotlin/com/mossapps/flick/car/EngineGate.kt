package com.mossapps.flick.car

import com.mossapps.flick.CarChannelException
import com.mossapps.flick.car.model.CarStatus

/** What one `status` probe says about the phone side of Flick. */
enum class Probe {
    /** Dart answered and the library can be read. */
    READY,

    /** Dart is still starting (no handler yet, no answer yet): ask again shortly. */
    WAIT,

    /** A real failure: not something polling will fix. */
    FAILED,
}

/**
 * The cold-start rule of docs/ANDROID_AUTO_DESIGN.md, 2.1: a car can connect with the app
 * closed, so the Flutter engine may still be starting. `status` failing with
 * `notImplemented` or `timeout`, or answering `ready: false`, means "not yet": poll every
 * 700 ms with the loading template, and after 12 s show "Flick is still starting" with Retry.
 */
object EngineGate {
    const val POLL_INTERVAL_MS = 700L
    const val GIVE_UP_MS = 12_000L

    fun classify(result: Result<CarStatus>): Probe = result.fold(
        onSuccess = { if (it.ready) Probe.READY else Probe.WAIT },
        onFailure = { if (isStarting(it)) Probe.WAIT else Probe.FAILED },
    )

    fun isStarting(failure: Throwable): Boolean =
        failure is CarChannelException && (failure.code == "notImplemented" || failure.code == "timeout")

    /** Whether to stop polling and show the "still starting" state. */
    fun gaveUp(elapsedMs: Long): Boolean = elapsedMs >= GIVE_UP_MS
}
