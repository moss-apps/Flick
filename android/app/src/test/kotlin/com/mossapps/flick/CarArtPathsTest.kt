package com.mossapps.flick

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CarArtPathsTest {
    @get:Rule
    val tmp = TemporaryFolder()

    private fun dir(vararg parts: String): File =
        File(tmp.root, parts.joinToString(File.separator)).apply { mkdirs() }

    private fun file(parent: File, name: String): File =
        File(parent, name).apply { writeText("x") }

    @Test
    fun acceptsFilesInsideARoot() {
        val root = dir("data", "app")
        val art = file(dir("data", "app", "files", "covers"), "a.jpg")

        assertTrue(CarArtPaths.isAllowed(art.path, listOf(root)))
        assertEquals(art.canonicalFile, CarArtPaths.resolve(art.path, listOf(root)))
    }

    @Test
    fun acceptsAnyOfSeveralRoots() {
        val internal = dir("data", "app")
        val external = dir("sdcard", "Android", "data", "app", "files")
        val art = file(external, "b.jpg")

        assertTrue(CarArtPaths.isAllowed(art.path, listOf(internal, external)))
    }

    @Test
    fun rejectsASiblingThatSharesTheRootsPrefix() {
        val root = dir("data", "app")
        val sibling = file(dir("data", "app2"), "a.jpg")

        assertFalse(CarArtPaths.isAllowed(sibling.path, listOf(root)))
        assertFalse(CarArtPaths.isAllowed(root.path + "2/a.jpg", listOf(root)))
    }

    @Test
    fun rejectsTheRootItself() {
        val root = dir("data", "app")

        assertFalse(CarArtPaths.isAllowed(root.path, listOf(root)))
        assertFalse(CarArtPaths.isAllowed(root.path + File.separator, listOf(root)))
    }

    @Test
    fun rejectsTraversalOutOfTheRoot() {
        val root = dir("data", "app")
        file(dir("data", "other"), "secret.jpg")

        assertFalse(
            CarArtPaths.isAllowed("${root.path}/files/../../other/secret.jpg", listOf(root))
        )
        assertFalse(CarArtPaths.isAllowed("${root.path}/../other/secret.jpg", listOf(root)))
    }

    @Test
    fun allowsTraversalThatStaysInsideTheRoot() {
        val root = dir("data", "app")
        val art = file(dir("data", "app", "files"), "a.jpg")
        dir("data", "app", "cache")

        assertTrue(CarArtPaths.isAllowed("${root.path}/cache/../files/a.jpg", listOf(root)))
        assertEquals(
            art.canonicalFile,
            CarArtPaths.resolve("${root.path}/cache/../files/a.jpg", listOf(root)),
        )
    }

    @Test
    fun rejectsASymlinkThatLeavesTheRoot() {
        val root = dir("data", "app")
        val outside = file(dir("data", "other"), "secret.jpg")
        val link = File(root, "link.jpg")
        Files.createSymbolicLink(link.toPath(), outside.toPath())
        val dirLink = File(root, "dirlink")
        Files.createSymbolicLink(dirLink.toPath(), outside.parentFile.toPath())

        assertFalse(CarArtPaths.isAllowed(link.path, listOf(root)))
        assertFalse(CarArtPaths.isAllowed("${dirLink.path}/secret.jpg", listOf(root)))
    }

    @Test
    fun followsASymlinkThatStaysInsideTheRoot() {
        val root = dir("data", "app")
        val art = file(dir("data", "app", "files"), "a.jpg")
        val link = File(root, "link.jpg")
        Files.createSymbolicLink(link.toPath(), art.toPath())

        assertEquals(art.canonicalFile, CarArtPaths.resolve(link.path, listOf(root)))
    }

    @Test
    fun aRootReachedThroughASymlinkStillMatches() {
        val real = dir("real", "app")
        val art = file(real, "a.jpg")
        val aliasParent = dir("alias")
        val alias = File(aliasParent, "app")
        Files.createSymbolicLink(alias.toPath(), real.toPath())

        assertTrue(CarArtPaths.isAllowed(art.path, listOf(alias)))
        assertTrue(CarArtPaths.isAllowed("${alias.path}/a.jpg", listOf(real)))
    }

    @Test
    fun rejectsEmptyNullRelativeAndNulPaths() {
        val root = dir("data", "app")

        assertFalse(CarArtPaths.isAllowed(null, listOf(root)))
        assertFalse(CarArtPaths.isAllowed("", listOf(root)))
        assertFalse(CarArtPaths.isAllowed("files/a.jpg", listOf(root)))
        assertFalse(CarArtPaths.isAllowed("${root.path}/a\u0000.jpg", listOf(root)))
    }

    @Test
    fun noRootsMeansNothingIsAllowed() {
        val art = file(dir("data", "app"), "a.jpg")

        assertFalse(CarArtPaths.isAllowed(art.path, emptyList()))
    }

    @Test
    fun tokensRoundTripAndRejectGarbage() {
        val path = "/data/user/0/com.mossapps.flick/files/covers/Beyoncé – Lemonade ✓.jpg"
        val token = CarArtPaths.encode(path)

        assertEquals(path, CarArtPaths.decode(token))
        assertTrue(token.all { it.isLetterOrDigit() || it == '-' || it == '_' })
        assertNull(CarArtPaths.decode(""))
        assertNull(CarArtPaths.decode("not base64!"))
        assertNull(CarArtPaths.decode("a".repeat(9000)))
        assertNotNull(CarArtPaths.decode(CarArtPaths.encode("/a")))
    }
}
