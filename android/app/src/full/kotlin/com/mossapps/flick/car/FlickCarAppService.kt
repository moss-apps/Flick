package com.mossapps.flick.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Flick's templated Android Auto media app (docs/ANDROID_AUTO_DESIGN.md). Any host that
 * speaks the Car App protocol may bind (Android Auto, DriveDeck, others): there is
 * deliberately no allowlist.
 */
class FlickCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator = HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    /** At Car API 9 the manifest theme is ignored unless the app asks for its own. */
    override fun getCarAppThemeSource(): Int = THEME_SOURCE_APP

    override fun onCreateSession(): Session = FlickCarSession()
}
