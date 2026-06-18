package com.mossapps.flick.widgets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

object WidgetArtLoader {

    private const val MAX_PX = 256

    fun load(path: String?, maxPx: Int = MAX_PX): Bitmap? {
        if (path.isNullOrEmpty() || !File(path).exists()) return null
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        if (opts.outWidth <= 0 || opts.outHeight <= 0) return null
        val sample = calculateSampleSize(opts.outWidth, opts.outHeight, maxPx)
        return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
        })
    }

    private fun calculateSampleSize(w: Int, h: Int, maxPx: Int): Int {
        var s = 1
        while (w / s > maxPx || h / s > maxPx) s *= 2
        return s
    }
}
