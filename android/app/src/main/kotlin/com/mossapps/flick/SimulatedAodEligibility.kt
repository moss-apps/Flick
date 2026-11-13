package com.mossapps.flick

/**
 * Pure launch gate for the opt-in simulated AOD. The overlay permission is
 * Android's documented background-activity-start exemption; without it the
 * launch would be blocked or unreliable. Motion is also required because the
 * viewer would otherwise hold a static display awake for no benefit.
 */
internal fun canLaunchSimulatedAod(
    enabled: Boolean,
    simulatedAod: Boolean,
    armed: Boolean,
    viewerOpen: Boolean,
    recentlyFinished: Boolean,
    overlayAllowed: Boolean,
    animatorsEnabled: Boolean,
): Boolean = enabled && simulatedAod && armed && !viewerOpen &&
    !recentlyFinished && overlayAllowed && animatorsEnabled
