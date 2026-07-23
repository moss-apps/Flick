package com.mossapps.flick

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log

class DsdAudioTrackManager {

    companion object {
        private const val TAG = "DsdAudioTrack"
        @Volatile
        private var encodingDsdAvailable: Boolean? = null

        @JvmStatic
        fun isEncodingDsdAvailable(): Boolean {
            encodingDsdAvailable?.let { return it }
            // Definitive test: actually build an ENCODING_DSD AudioTrack at DSD64.
            // getMinBufferSize may reject the rate even when the HAL accepts it (HiBy
            // exposes the constant but the framework validation fails), so we bypass
            // it and let AudioTrack.Builder().build() be the arbiter.
            val available = try {
                val encoding = AudioFormat::class.java.getField("ENCODING_DSD").getInt(null)
                val format = AudioFormat.Builder()
                    .setSampleRate(2_822_400)
                    .setEncoding(encoding)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                val testTrack = AudioTrack.Builder()
                    .setAudioAttributes(attrs)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(70_560)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
                testTrack.release()
                true
            } catch (e: Exception) {
                Log.w(TAG, "ENCODING_DSD AudioTrack build test failed: ${e.message}")
                false
            }
            encodingDsdAvailable = available
            Log.i(TAG, "ENCODING_DSD runtime probe: available=$available")
            return available
        }
    }
}
