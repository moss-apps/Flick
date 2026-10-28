package com.mossapps.flick

import org.junit.Assert.assertEquals
import org.junit.Test

class MetadataNumberPairTest {
    @Test
    fun readsNumberAndTotal() {
        assertEquals(4 to 12, parseMetadataNumberPair("04/12"))
        assertEquals(2 to 3, parseMetadataNumberPair(" 2 / 3 "))
    }

    @Test
    fun bareNumberDoesNotInventATotal() {
        assertEquals(4 to null, parseMetadataNumberPair("4"))
    }

    @Test
    fun rejectsUnrelatedNumbersAndMalformedPairs() {
        for (value in listOf(null, "", " ", "4 of 12", "4/12/15", "-1/12")) {
            assertEquals(value, null to null, parseMetadataNumberPair(value))
        }
    }

    @Test
    fun zeroOrOverflowIsNotAValidCount() {
        assertEquals(null to 12, parseMetadataNumberPair("0/12"))
        assertEquals(4 to null, parseMetadataNumberPair("4/0"))
        assertEquals(null to 12, parseMetadataNumberPair("999999999999/12"))
        assertEquals(4 to null, parseMetadataNumberPair("4/999999999999"))
    }
}
