package com.mossapps.flick

/** Reads the number or number/total form used by TRCK and TPOS. */
internal fun parseMetadataNumberPair(rawValue: String?): Pair<Int?, Int?> {
    val match = rawValue?.trim()?.let {
        Regex("""^(\d+)(?:\s*/\s*(\d+))?$""").matchEntire(it)
    } ?: return null to null
    val number = match.groupValues[1].toIntOrNull()?.takeIf { it > 0 }
    val total = match.groupValues[2].toIntOrNull()?.takeIf { it > 0 }
    return number to total
}
