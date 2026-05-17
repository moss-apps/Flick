package com.mossapps.flick.widgets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

object WidgetArtLoader {

    private const val MAX_PX = 256

    fun load(path: String?): Bitmap? {
        if (path.isNullOrEmpty() || !File(path).exists()) return null
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        if (opts.outWidth <= 0 || opts.outHeight <= 0) return null
        val sample = calculateSampleSize(opts.outWidth, opts.outHeight)
        return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
        })
    }

    private fun calculateSampleSize(w: Int, h: Int): Int {
        var s = 1
        while (w / s > MAX_PX || h / s > MAX_PX) s *= 2
        return s
    }
}
