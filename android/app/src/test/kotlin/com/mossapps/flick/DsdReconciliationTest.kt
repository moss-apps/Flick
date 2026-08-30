package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class DsdReconciliationTest {

    @get:Rule
    val temp = TemporaryFolder()

    private fun touch(dir: File, name: String): File {
        dir.mkdirs()
        return File(dir, name).apply { writeText("x") }
    }

    @Test
    fun findsDsdFilesAbsentFromMediaStore() {
        val root = temp.newFolder("Music")
        touch(File(root, "Album"), "track.dsf")
        touch(File(root, "Album"), "live.DFF")
        touch(File(root, "Album"), "lossless.wv")
        touch(File(root, "Album"), "song.flac")

        val found = DsdReconciliation.findUnindexedDsdFiles(listOf(root.path), emptySet())
        val names = found.map { it.name.lowercase() }.sorted()
        assertEquals(listOf("live.dff", "lossless.wv", "track.dsf"), names)
    }

    @Test
    fun dedupesPathsAlreadyCoveredByMediaStore() {
        val root = temp.newFolder("Music2")
        val dsf = touch(File(root, "a"), "one.dsf")
        touch(File(root, "a"), "two.dsf")

        val seen = setOf(dsf.canonicalPath)
        val found = DsdReconciliation.findUnindexedDsdFiles(listOf(root.path), seen)
        assertEquals(listOf("two.dsf"), found.map { it.name })
    }

    @Test
    fun skipsNomediaSubtreesAndDotEntries() {
        val root = temp.newFolder("Music3")
        val hidden = File(root, ".hidden")
        touch(hidden, "dotdir.dsf")
        val noMedia = File(root, "private")
        touch(noMedia, "secret.dsf")
        touch(noMedia, ".nomedia")
        touch(root, "ok.dsf")

        val found = DsdReconciliation.findUnindexedDsdFiles(listOf(root.path), emptySet())
        assertEquals(listOf("ok.dsf"), found.map { it.name })
    }

    @Test
    fun nonDsdFoldersYieldNothing() {
        val root = temp.newFolder("Music4")
        touch(root, "cover.jpg")
        touch(root, "meta.txt")
        assertEquals(0, DsdReconciliation.findUnindexedDsdFiles(listOf(root.path), emptySet()).size)
    }

    @Test
    fun nestedRootsDoNotProduceDuplicates() {
        val root = temp.newFolder("Music5")
        touch(File(root, "Album"), "track.dsf")

        val found = DsdReconciliation.findUnindexedDsdFiles(
            listOf(root.path, File(root, "Album").path),
            emptySet(),
        )
        assertEquals(listOf("track.dsf"), found.map { it.name })
    }

    @Test
    fun missingOrUnreadableRootIsIgnored() {
        val found = DsdReconciliation.findUnindexedDsdFiles(
            listOf(File(temp.root, "does-not-exist").path),
            emptySet(),
        )
        assertEquals(0, found.size)
    }
}
