package com.mossapps.flick.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import androidx.annotation.FontRes
import androidx.core.content.res.ResourcesCompat


object WidgetTextRenderer {

    fun createTextBitmap(
        context: Context,
        text: String,
        @FontRes fontRes: Int,
        textSizeSp: Int,
        textColor: Int,
        maxWidthPx: Int,
        alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = ResourcesCompat.getFont(context, fontRes)
            textSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                textSizeSp.toFloat(),
                dm,
            )
            color = textColor
        }
        val ellipsized = TextUtils.ellipsize(
            text,
            paint,
            maxWidthPx.toFloat(),
            TextUtils.TruncateAt.END,
        )
        @Suppress("DEPRECATION")
        val layout = StaticLayout(
            ellipsized,
            paint,
            maxWidthPx,
            alignment,
            1f,
            0f,
            false,
        )
        val bitmap = Bitmap.createBitmap(maxWidthPx, layout.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        layout.draw(canvas)
        return bitmap
    }
}
