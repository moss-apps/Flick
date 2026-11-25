package com.mossapps.flick

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Serves album covers to car hosts as `content://<applicationId>.carart/art/{base64url(path)}`.
 *
 * Covers are files in app-private storage and a host cannot read them, so the
 * provider decodes the file and returns only a re-encoded JPEG of at most 512 px,
 * cached in `cacheDir/car_art/`. The original file is never streamed. The
 * provider is exported and read-only, and trusts nothing in the URI: the path
 * must resolve (symlinks and `..` included) inside the app's own directories.
 * Anything else is a [FileNotFoundException], and the car UI falls back to a
 * placeholder.
 */
class CarArtProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = MIME_TYPE

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (mode != "r") throw FileNotFoundException("read-only")
        val ctx = context ?: throw FileNotFoundException("no context")

        val segments = uri.pathSegments
        if (segments.size != 2 || segments[0] != "art") throw FileNotFoundException("bad uri")
        val path = CarArtPaths.decode(segments[1]) ?: throw FileNotFoundException("bad token")
        val source = CarArtPaths.resolve(path, allowedRoots(ctx))
            ?: throw FileNotFoundException("outside the app's directories")
        if (!source.isFile || source.length() !in 1..MAX_SOURCE_BYTES) {
            throw FileNotFoundException("not a readable image")
        }

        val cacheDir = File(ctx.cacheDir, CACHE_DIR)
        val cached = File(cacheDir, cacheName(source) + ".jpg")
        if (!(cached.isFile && cached.length() > 0)) {
            // One decode at a time bounds memory when a host asks for many covers at once.
            synchronized(decodeLock) {
                if (!(cached.isFile && cached.length() > 0)) {
                    writeCover(source, cacheDir, cached)
                    if (writes.getAndIncrement() % TRIM_EVERY_WRITES == 0) {
                        trimCache(cacheDir)
                    }
                }
            }
        }
        return ParcelFileDescriptor.open(cached, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    private fun writeCover(source: File, cacheDir: File, target: File) {
        if (!cacheDir.isDirectory && !cacheDir.mkdirs() && !cacheDir.isDirectory) {
            throw FileNotFoundException("no cache directory")
        }
        val temp = File(cacheDir, ".tmp-${UUID.randomUUID()}")
        try {
            val bitmap = decodeScaled(source) ?: throw FileNotFoundException("not an image")
            try {
                val ok = temp.outputStream().use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                }
                if (!ok) throw FileNotFoundException("encode failed")
            } finally {
                bitmap.recycle()
            }
            if (!temp.renameTo(target) && !target.isFile) {
                throw FileNotFoundException("cache write failed")
            }
        } catch (e: FileNotFoundException) {
            throw e
        } catch (e: IOException) {
            throw FileNotFoundException("cache write failed: ${e.message}")
        } catch (e: RuntimeException) {
            throw FileNotFoundException("decode failed: ${e.message}")
        } catch (e: OutOfMemoryError) {
            throw FileNotFoundException("decode failed: out of memory")
        } finally {
            temp.delete()
        }
    }

    // Bounds first, then a power-of-two sample that keeps at least MAX_EDGE_PX, then an
    // exact scale down, so a 600 px cover is not halved to 300 px.
    private fun decodeScaled(source: File): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        val longEdge = maxOf(bounds.outWidth, bounds.outHeight)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (longEdge / (sample * 2) >= MAX_EDGE_PX) sample *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(source.path, options) ?: return null

        val edge = maxOf(decoded.width, decoded.height)
        if (edge <= MAX_EDGE_PX) return decoded
        val scale = MAX_EDGE_PX.toFloat() / edge
        val scaled = Bitmap.createScaledBitmap(
            decoded,
            maxOf(1, (decoded.width * scale).toInt()),
            maxOf(1, (decoded.height * scale).toInt()),
            true,
        )
        if (scaled !== decoded) decoded.recycle()
        return scaled
    }

    private fun trimCache(cacheDir: File) {
        try {
            val files = cacheDir.listFiles() ?: return
            val doomed = CarArtCache.selectEvictions(
                files.map { it.name to it.lastModified() },
                limit = CACHE_LIMIT,
                keep = CACHE_KEEP,
            )
            doomed.forEach { File(cacheDir, it).delete() }
        } catch (e: Exception) {
            Log.w(TAG, "cache trim failed: ${e.message}")
        }
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    companion object {
        private const val TAG = "CarArtProvider"
        private const val MIME_TYPE = "image/jpeg"
        private const val CACHE_DIR = "car_art"
        private const val MAX_EDGE_PX = 512
        private const val JPEG_QUALITY = 88
        private const val MAX_SOURCE_BYTES = 64L * 1024 * 1024
        private const val CACHE_LIMIT = 600
        private const val CACHE_KEEP = 500
        private const val TRIM_EVERY_WRITES = 32

        private val decodeLock = Any()
        private val writes = AtomicInteger(0)

        /** The URI a car host loads this cover from, or null when there is no cover. */
        fun uriFor(context: Context, path: String?): Uri? {
            if (path.isNullOrBlank()) return null
            return Uri.Builder()
                .scheme("content")
                .authority("${context.packageName}.carart")
                .appendPath("art")
                .appendPath(CarArtPaths.encode(path))
                .build()
        }

        private fun allowedRoots(context: Context): List<File> {
            val roots = mutableListOf<File>()
            context.applicationInfo.dataDir?.let { roots += File(it) }
            context.filesDir?.parentFile?.let { roots += it }
            context.cacheDir?.parentFile?.let { roots += it }
            context.getExternalFilesDirs(null)?.forEach { dir -> dir?.let { roots += it } }
            context.externalCacheDirs?.forEach { dir -> dir?.let { roots += it } }
            return roots
        }

        // The key changes when the cover file does, so an edited cover is re-encoded.
        private fun cacheName(source: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest("${source.path}${source.lastModified()}".toByteArray(Charsets.UTF_8))
            return digest.joinToString("") { "%02x".format(it) }
        }
    }
}

/** The path rules for [CarArtProvider], free of Android so they run on the JVM. */
internal object CarArtPaths {
    private const val MAX_PATH_BYTES = 4096

    fun encode(path: String): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(path.toByteArray(Charsets.UTF_8))

    fun decode(token: String): String? {
        if (token.isEmpty() || token.length > MAX_PATH_BYTES * 2) return null
        return try {
            String(Base64.getUrlDecoder().decode(token), Charsets.UTF_8).takeIf { it.isNotEmpty() }
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    /**
     * The canonical file for [path] when it lies strictly inside one of [roots],
     * else null. `..` and symlinks are resolved first and the comparison keeps a
     * trailing separator, so `/data/app2` is not inside `/data/app`. Callers open
     * the returned file, not the path they were given.
     */
    fun resolve(path: String?, roots: Collection<File>): File? {
        if (path.isNullOrEmpty() || path.contains('\u0000')) return null
        val file = File(path)
        if (!file.isAbsolute) return null
        val canonical = try {
            file.canonicalFile
        } catch (_: IOException) {
            return null
        }
        val canonicalPath = canonical.path
        val inside = roots.any { root ->
            val rootPath = try {
                root.canonicalPath
            } catch (_: IOException) {
                return@any false
            }
            val prefix = if (rootPath.endsWith(File.separator)) rootPath else rootPath + File.separator
            canonicalPath.startsWith(prefix)
        }
        return canonical.takeIf { inside }
    }

    fun isAllowed(path: String?, roots: Collection<File>): Boolean = resolve(path, roots) != null
}

internal object CarArtCache {
    /**
     * Names to delete when the cache holds more than [limit] files: the oldest
     * ones, down to [keep]. Below the limit nothing is evicted, so the common
     * case costs one count.
     */
    fun selectEvictions(entries: List<Pair<String, Long>>, limit: Int, keep: Int): List<String> {
        if (entries.size <= limit) return emptyList()
        return entries.sortedBy { it.second }.take(entries.size - keep).map { it.first }
    }
}
