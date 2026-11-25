package com.mossapps.flick

/** One upcoming track as the MediaSession queue shows it. */
internal data class SessionQueueEntry(
    /** Position in the combined `fromYou + fromContext` list, which is what `skipToQueueItem` sends back. */
    val id: Long,
    val mediaId: String,
    val title: String,
    val subtitle: String?,
    val artPath: String?,
)

internal data class SessionQueue(
    val title: String,
    val entries: List<SessionQueueEntry>,
)

internal const val SESSION_QUEUE_LIMIT = 100
internal const val SESSION_QUEUE_DEFAULT_TITLE = "Up next"

/**
 * Reads the Dart `queue` answer: `{fromYou: [Track], fromContext: [Track], contextName?}`.
 * Ids are positions in the combined list, so an entry that cannot be read is
 * skipped without shifting the ones after it.
 */
internal fun parseSessionQueue(raw: Any?, limit: Int = SESSION_QUEUE_LIMIT): SessionQueue {
    val map = raw as? Map<*, *> ?: return SessionQueue(SESSION_QUEUE_DEFAULT_TITLE, emptyList())
    val combined = listOf(map["fromYou"], map["fromContext"])
        .flatMap { (it as? List<*>) ?: emptyList() }

    val entries = combined.take(limit).mapIndexedNotNull { index, item ->
        val track = item as? Map<*, *> ?: return@mapIndexedNotNull null
        val id = track["id"]?.toString()?.takeIf { it.isNotEmpty() }
            ?: return@mapIndexedNotNull null
        SessionQueueEntry(
            id = index.toLong(),
            mediaId = id,
            title = (track["title"] as? String)?.takeIf { it.isNotBlank() } ?: "Unknown",
            subtitle = (track["artist"] as? String)?.takeIf { it.isNotBlank() },
            artPath = (track["art"] as? String)?.takeIf { it.isNotBlank() },
        )
    }

    val title = (map["contextName"] as? String)?.takeIf { it.isNotBlank() }
        ?: SESSION_QUEUE_DEFAULT_TITLE
    return SessionQueue(title, entries)
}
