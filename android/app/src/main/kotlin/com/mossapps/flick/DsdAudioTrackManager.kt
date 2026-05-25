package com.mossapps.flick

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.util.Log

class DsdAudioTrackManager {

    companion object {
        private const val TAG = "DsdAudioTrack"
        private var instance: DsdAudioTrackManager? = null
        @Volatile
        private var encodingDsdAvailable: Boolean? = null

        @JvmStatic
        fun isEncodingDsdAvailable(): Boolean {
            encodingDsdAvailable?.let { return it }
            val available = try {
                AudioFormat::class.java.getField("ENCODING_DSD").getInt(null)
                true
            } catch (_: Exception) {
                false
            }
            encodingDsdAvailable = available
            Log.i(TAG, "ENCODING_DSD runtime probe: available=$available")
            return available
        }

        @JvmStatic
        fun nativeCreate(sampleRate: Int, channels: Int): Boolean {
            val manager = DsdAudioTrackManager()
            if (!manager.create(sampleRate, channels)) {
                return false
            }
            instance = manager
            return true
        }

        @JvmStatic
        fun nativePlay(): Boolean {
            return instance?.play() ?: false
        }

        @JvmStatic
        fun nativeWrite(data: ByteArray): Int {
            return instance?.write(data) ?: -1
        }

        @JvmStatic
        fun nativeStop() {
            instance?.stop()
            instance = null
        }

        @JvmStatic
        fun nativeIsRunning(): Boolean {
            return instance?.isRunning() ?: false
        }
    }

    private var track: AudioTrack? = null
    private var running = false

    fun create(
        sampleRate: Int,
        channels: Int,
    ): Boolean {
        if (track != null) {
            Log.w(TAG, "AudioTrack already created; stopping existing")
            stop()
        }

        val channelMask = if (channels == 1) {
            AudioFormat.CHANNEL_OUT_MONO
        } else {
            AudioFormat.CHANNEL_OUT_STEREO
        }

        val encoding: Int = try {
            AudioFormat::class.java.getField("ENCODING_DSD")
                .getInt(null)
        } catch (e: Exception) {
            Log.e(TAG, "ENCODING_DSD not available on this platform: ${e.message}")
            return false
        }

        val bufferSize: Int = try {
            val getMinBufSize = AudioTrack::class.java.getMethod(
                "getMinBufferSize",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
            )
            getMinBufSize.invoke(null, sampleRate, channelMask, encoding) as Int
        } catch (e: Exception) {
            Log.e(TAG, "getMinBufferSize with ENCODING_DSD failed: ${e.message}")
            return false
        }

        if (bufferSize <= 0) {
            Log.e(TAG, "Invalid buffer size for DSD AudioTrack: $bufferSize (rate=$sampleRate, ch=$channels)")
            return false
        }

        try {
            val format = AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(encoding)
                .setChannelMask(channelMask)
                .build()

            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            track = AudioTrack.Builder()
                .setAudioAttributes(attributes)
                .setAudioFormat(format)
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create DSD AudioTrack: ${e.message}")
            track = null
            return false
        }

        Log.i(TAG, "DSD AudioTrack created: rate=$sampleRate ch=$channels bufSize=$bufferSize")
        return true
    }

    fun play(): Boolean {
        val t = track ?: run {
            Log.e(TAG, "play: no AudioTrack")
            return false
        }
        return try {
            t.play()
            running = true
            Log.d(TAG, "DSD AudioTrack playing")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start DSD AudioTrack: ${e.message}")
            false
        }
    }

    fun write(data: ByteArray): Int {
        val t = track ?: return -1
        return try {
            t.write(data, 0, data.size)
        } catch (e: Exception) {
            Log.e(TAG, "DSD AudioTrack write error: ${e.message}")
            -1
        }
    }

    fun stop() {
        running = false
        try {
            track?.stop()
        } catch (_: Exception) {}
        try {
            track?.release()
        } catch (_: Exception) {}
        track = null
        Log.d(TAG, "DSD AudioTrack stopped and released")
    }

    fun isRunning(): Boolean = running && track != null
}