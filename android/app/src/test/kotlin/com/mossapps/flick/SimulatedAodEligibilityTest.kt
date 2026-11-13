package com.mossapps.flick

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SimulatedAodEligibilityTest {
    private fun eligible(
        enabled: Boolean = true,
        simulatedAod: Boolean = true,
        armed: Boolean = true,
        viewerOpen: Boolean = false,
        recentlyFinished: Boolean = false,
        overlayAllowed: Boolean = true,
        animatorsEnabled: Boolean = true,
    ) = canLaunchSimulatedAod(
        enabled = enabled,
        simulatedAod = simulatedAod,
        armed = armed,
        viewerOpen = viewerOpen,
        recentlyFinished = recentlyFinished,
        overlayAllowed = overlayAllowed,
        animatorsEnabled = animatorsEnabled,
    )

    @Test
    fun launchesOnlyWhenEveryGatePasses() {
        assertTrue(eligible())
    }

    @Test
    fun requiresBothOptInsAndPlaybackArmedState() {
        assertFalse(eligible(enabled = false))
        assertFalse(eligible(simulatedAod = false))
        assertFalse(eligible(armed = false))
    }

    @Test
    fun neverRelaunchesOverAnOpenOrRecentlyClosedViewer() {
        assertFalse(eligible(viewerOpen = true))
        assertFalse(eligible(recentlyFinished = true))
    }

    @Test
    fun requiresOverlayPermissionAndMotion() {
        assertFalse(eligible(overlayAllowed = false))
        assertFalse(eligible(animatorsEnabled = false))
    }
}
