package com.mossapps.flick

import java.io.File

// Pure (no Android deps) so it runs in plain JVM unit tests.
//
// Raw stat-only walk recovering DSD-family files that OEM MediaScanners never
// indexed (MIUI/HyperOS, Vivo/Funtouch, Honor skip .dsf/.dff/.wv entirely,
// so they land in neither Audio.Media nor the Files collection).
internal object DsdReconciliation {

    // Extensions OEM MediaScanners love to skip entirely.
    private val dsdExtensions = setOf("dsf", "dff", "wv")

    private fun isIgnoredByMediaWalk(name: String): Boolean =
        name.startsWith(".")

    /**
     * Collects DSD files under [folderPaths] that are absent from [seenPaths]
     * (MediaStore-covered paths). Skips dotfiles, dot-directories and
     * `.nomedia` subtrees, mirroring MediaStore semantics so reconciliation
     * never resurrects intentionally hidden files.
     */
    fun findUnindexedDsdFiles(
        folderPaths: List<String>,
        seenPaths: Set<String>,
    ): List<File> {
        val missing = mutableListOf<File>()
        val seenNormalized = HashSet<String>(seenPaths.size)
        for (p in seenPaths) {
            seenNormalized.add(runCatching { File(p).canonicalPath }.getOrDefault(p))
        }
        // Nested scan roots can walk the same file twice; canonical dedup keeps
        // the result set unique.
        val foundNormalized = HashSet<String>()
        for (rootPath in folderPaths) {
            val root = File(rootPath)
            if (!root.isDirectory || !root.canRead()) continue
            try {
                root.walkTopDown()
                    .onEnter { dir ->
                        val f = dir.absoluteFile
                        !isIgnoredByMediaWalk(f.name) &&
                            !File(f, ".nomedia").exists()
                    }
                    .forEach { f ->
                        if (!f.isFile) return@forEach
                        if (isIgnoredByMediaWalk(f.name)) return@forEach
                        if (!dsdExtensions.contains(f.extension.lowercase())) return@forEach
                        val canonical = runCatching { f.canonicalPath }.getOrDefault(f.absolutePath)
                        if (seenNormalized.contains(canonical)) return@forEach
                        if (!foundNormalized.add(canonical)) return@forEach
                        missing.add(f)
                    }
            } catch (_: Exception) {
                // Unreadable subtree: MediaStore results still stand.
            }
        }
        return missing
    }
}
