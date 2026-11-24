package com.mossapps.flick

/** Match descendants of literal directory paths, not arbitrary path prefixes. */
internal class MediaStoreFolderScope(folderPaths: List<String>) {
    private val prefixes = folderPaths.map { it.trimEnd('/') + "/" }

    val args = prefixes.map { prefix ->
        prefix.replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%"
    }

    fun selection(column: String): String? = prefixes.takeIf { it.isNotEmpty() }
        ?.joinToString(" OR ") { "$column LIKE ? ESCAPE '!'" }

    // SQLite LIKE folds ASCII case. Confirm the actual directory boundary and
    // spelling too, so case-sensitive storage can't leak a neighboring folder.
    fun contains(path: String): Boolean = prefixes.isEmpty() ||
        prefixes.any { path.length > it.length && path.startsWith(it) }
}
