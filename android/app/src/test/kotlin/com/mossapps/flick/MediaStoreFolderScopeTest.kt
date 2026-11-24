package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaStoreFolderScopeTest {
    @Test
    fun folderNamesAreLiteralSqlPrefixes() {
        val scope = MediaStoreFolderScope(listOf("/Music/", "/My_100%!Music"))

        assertEquals("_data LIKE ? ESCAPE '!' OR _data LIKE ? ESCAPE '!'", scope.selection("_data"))
        assertEquals(listOf("/Music/%", "/My!_100!%!!Music/%"), scope.args)
        assertTrue(scope.contains("/Music/Album/song.flac"))
        assertTrue(scope.contains("/My_100%!Music/album.cue"))
        assertFalse(scope.contains("/Music Backup/song.flac"))
        assertFalse(scope.contains("/MyX100ABC!Music/song.dsf"))
        assertFalse(scope.contains("/music/song.flac"))
        assertFalse(scope.contains("/Music/"))
    }

    @Test
    fun noFoldersMeansUnrestrictedQuery() {
        val scope = MediaStoreFolderScope(emptyList())

        assertNull(scope.selection("_data"))
        assertTrue(scope.args.isEmpty())
        assertTrue(scope.contains("/Music/song.flac"))
    }
}
