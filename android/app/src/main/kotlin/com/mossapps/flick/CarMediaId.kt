package com.mossapps.flick

import java.net.URLDecoder
import java.net.URLEncoder

/**
 * What a car host hands back to `onPlayFromMediaId`: `kind|id|trackId`, each part
 * URL-encoded, `trackId` optional. Parsed, never executed: an unknown kind or a
 * malformed id is rejected, not guessed at.
 */
data class CarMediaId(
    val kind: String,
    val id: String,
    val trackId: String? = null,
) {
    fun encode(): String {
        val parts = mutableListOf(escape(kind), escape(id))
        trackId?.let { parts += escape(it) }
        return parts.joinToString(SEPARATOR.toString())
    }

    companion object {
        private const val SEPARATOR = '|'
        private const val MAX_LENGTH = 2048

        /** The collection kinds of the `com.mossapps.flick/car` contract. */
        val KINDS = setOf(
            "album", "artist", "playlist", "folder", "songs", "favorites",
            "recentlyAdded", "mostPlayed", "recentlyPlayed", "search",
        )

        // These collections are the whole list, so they carry no id of their own.
        private val SINGLETON_KINDS = setOf(
            "songs", "favorites", "recentlyAdded", "mostPlayed", "recentlyPlayed",
        )

        fun parse(raw: String?): CarMediaId? {
            if (raw.isNullOrEmpty() || raw.length > MAX_LENGTH) return null
            val parts = raw.split(SEPARATOR)
            if (parts.size !in 2..3) return null
            return try {
                val kind = URLDecoder.decode(parts[0], "UTF-8")
                val id = URLDecoder.decode(parts[1], "UTF-8")
                val trackId = parts.getOrNull(2)?.let { URLDecoder.decode(it, "UTF-8") }
                    ?.takeIf { it.isNotEmpty() }
                if (kind !in KINDS) return null
                if (id.isEmpty() && kind !in SINGLETON_KINDS) return null
                CarMediaId(kind, id, trackId)
            } catch (_: IllegalArgumentException) {
                null
            }
        }

        private fun escape(part: String): String = URLEncoder.encode(part, "UTF-8")
    }
}
