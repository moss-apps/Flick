package com.mossapps.flick.car.screens

import androidx.car.app.CarContext
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.Pages
import com.mossapps.flick.car.ui.PlayerVm

/**
 * Now Playing: the host's own template. Transport, artwork, progress and the custom actions
 * (shuffle, repeat, favourite) come from Flick's MediaSession, so nothing is redrawn here
 * while a song plays. Until a session token is registered a message is shown instead: the
 * template is never sent before the host has the session.
 */
class PlayerScreen(carContext: CarContext, host: CarHost) : FlickScreen(carContext, host) {
    init {
        setMarker(MARKER)
    }

    override fun page(): PageSpec = Pages.player(
        PlayerVm(
            ready = host.playerReady,
            starting = host.playerStarting,
            albumColor = host.albumColor,
        ),
        host.api9,
    )

    override fun reload() {
        // Nothing to fetch: the session redraws this screen when the token or the colour changes.
    }

    override fun onAlbumColorChanged() {
        // ALBUM is the accent of the level 9 playback style.
        if (host.api9 && host.playerReady && isTop()) redraw()
    }

    companion object {
        /** The marker `popTo` uses to return to an existing player instead of stacking a second. */
        const val MARKER = "flick-player"
    }
}
