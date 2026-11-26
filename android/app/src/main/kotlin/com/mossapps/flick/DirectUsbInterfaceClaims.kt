package com.mossapps.flick

/** Owns only the interfaces acquired on one Android USB connection. */
internal class DirectUsbInterfaceClaims<T>(
    private val forceClaim: (T) -> Unit,
    private val releaseInterface: (T) -> Unit,
    private val closeConnection: () -> Unit,
) {
    private val claimed = mutableListOf<T>()

    fun register(selectInterfaces: () -> List<T>, registerNative: (List<T>) -> Boolean): Boolean {
        var registered = false
        try {
            for (usbInterface in selectInterfaces()) {
                forceClaim(usbInterface)
                claimed += usbInterface
            }
            registered = registerNative(claimed.toList())
            return registered
        } finally {
            if (!registered) release()
        }
    }

    fun release() {
        try {
            claimed.asReversed().forEach(releaseInterface)
        } finally {
            closeConnection()
        }
    }
}
