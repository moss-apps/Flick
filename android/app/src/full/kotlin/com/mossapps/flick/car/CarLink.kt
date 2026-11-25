package com.mossapps.flick.car

import android.content.Context
import com.mossapps.flick.CarChannel
import com.mossapps.flick.car.model.CarCollectionDetail
import com.mossapps.flick.car.model.CarHome
import com.mossapps.flick.car.model.CarList
import com.mossapps.flick.car.model.CarModels
import com.mossapps.flick.car.model.CarQueue
import com.mossapps.flick.car.model.CarSearchResults
import com.mossapps.flick.car.model.CarStatus
import com.mossapps.flick.car.ui.CarLimits
import com.mossapps.flick.car.ui.ListKind
import java.util.concurrent.CopyOnWriteArrayList

/**
 * The car side of `com.mossapps.flick/car`: typed requests, a small cache and the fan-out of
 * `changed` events (docs/ANDROID_AUTO_DESIGN.md, 4.3 and 4.5). One per process, shared by the
 * templated session and the classic browser service, so both work with the app closed
 * (the channel starts the engine on demand).
 *
 * Main thread only: every callback runs there, exactly once, with a parsed model or a failure
 * (a [com.mossapps.flick.CarChannelException] for Dart failures, a
 * [com.mossapps.flick.car.model.CarModelException] for an answer that is not the contract).
 */
class CarLink private constructor(private val context: Context) {
    fun interface ChangeListener {
        fun onChanged(what: String)
    }

    private val cache = object : LinkedHashMap<String, Any>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>): Boolean =
            size > MAX_CACHED
    }
    private val waiting = HashMap<String, MutableList<(Result<Any>) -> Unit>>()
    private val listeners = CopyOnWriteArrayList<ChangeListener>()

    /** Bumped on every invalidation: an answer that was requested before one is not cached. */
    private var epoch = 0

    private val channelListener: (String) -> Unit = { what -> onChanged(what) }

    init {
        CarChannel.addListener(channelListener)
    }

    fun addChangeListener(listener: ChangeListener) {
        listeners.addIfAbsent(listener)
    }

    fun removeChangeListener(listener: ChangeListener) {
        listeners.remove(listener)
    }

    // ---------------------------------------------------------------- queries

    /** Never cached: it is the readiness probe. */
    fun status(callback: (Result<CarStatus>) -> Unit) {
        call("status", null, CarModels::status, callback)
    }

    fun home(refresh: Boolean = false, callback: (Result<CarHome>) -> Unit) {
        cached("home", refresh, "home", null, CarModels::home, callback)
    }

    fun list(
        kind: ListKind,
        limit: Int = CarLimits.LIST,
        refresh: Boolean = false,
        callback: (Result<CarList>) -> Unit,
    ) {
        cached(
            "list:${kind.wire}:$limit",
            refresh,
            "list",
            mapOf("kind" to kind.wire, "limit" to limit),
            CarModels::list,
            callback,
        )
    }

    fun collection(
        kind: String,
        id: String,
        limit: Int = CarLimits.LIST,
        refresh: Boolean = false,
        callback: (Result<CarCollectionDetail>) -> Unit,
    ) {
        cached(
            "collection:$kind:$id:$limit",
            refresh,
            "collection",
            mapOf("kind" to kind, "id" to id, "limit" to limit),
            CarModels::collection,
            callback,
        )
    }

    /** Not cached: a query is asked once. */
    fun search(query: String, limit: Int = CarLimits.SEARCH_PER_TYPE, callback: (Result<CarSearchResults>) -> Unit) {
        call("search", mapOf("query" to query, "limit" to limit), CarModels::search, callback)
    }

    fun queue(limit: Int = CarLimits.QUEUE, refresh: Boolean = false, callback: (Result<CarQueue>) -> Unit) {
        cached("queue:$limit", refresh, "queue", mapOf("limit" to limit), CarModels::queue, callback)
    }

    // --------------------------------------------------------------- commands

    fun play(
        kind: String,
        id: String,
        trackId: String? = null,
        shuffle: Boolean = false,
        callback: (Result<Unit>) -> Unit,
    ) {
        val args = mutableMapOf<String, Any?>("kind" to kind, "id" to id)
        if (trackId != null) args["trackId"] = trackId
        if (shuffle) args["shuffle"] = true
        command("play", args, callback)
    }

    fun playSearch(query: String, callback: (Result<Unit>) -> Unit) {
        command("playSearch", mapOf("query" to query), callback)
    }

    /** The number of songs added (Dart adds at most 50). */
    fun enqueue(kind: String, id: String, callback: (Result<Int>) -> Unit) {
        call("enqueue", mapOf("kind" to kind, "id" to id), { CarModels.int((it as? Map<*, *>)?.get("added")) ?: 0 }) {
            if (it.isSuccess) dropQueueCaches()
            callback(it)
        }
    }

    fun jump(section: String, index: Int, callback: (Result<Unit>) -> Unit) {
        command("jump", mapOf("section" to section, "index" to index), callback)
    }

    fun clearQueue(callback: (Result<Unit>) -> Unit) = command("clearQueue", null, callback)

    fun toggleShuffle(callback: (Result<Unit>) -> Unit) = command("toggleShuffle", null, callback)

    fun cycleLoop(callback: (Result<Unit>) -> Unit) = command("cycleLoop", null, callback)

    fun toggleFavorite(callback: (Result<Unit>) -> Unit) = command("toggleFavorite", null, callback)

    fun resume(callback: (Result<Unit>) -> Unit) = command("resume", null, callback)

    // ------------------------------------------------------------------ plumbing

    private fun command(method: String, args: Map<String, Any?>?, callback: (Result<Unit>) -> Unit) {
        call(method, args, { }) {
            if (it.isSuccess) dropQueueCaches()
            callback(it)
        }
    }

    /** A request whose answer is not kept. */
    private fun <T : Any> call(
        method: String,
        args: Map<String, Any?>?,
        parse: (Any?) -> T,
        callback: (Result<T>) -> Unit,
    ) {
        CarChannel.invoke(context, method, args) { raw -> callback(raw.mapCatching(parse)) }
    }

    /**
     * A request whose answer is kept until the next change that affects it. Requests for the
     * same key that overlap share one call.
     */
    @Suppress("UNCHECKED_CAST")
    private fun <T : Any> cached(
        key: String,
        refresh: Boolean,
        method: String,
        args: Map<String, Any?>?,
        parse: (Any?) -> T,
        callback: (Result<T>) -> Unit,
    ) {
        if (!refresh) {
            (cache[key] as? T)?.let {
                callback(Result.success(it))
                return
            }
        }
        val waiters = waiting[key]
        if (waiters != null) {
            waiters += { result -> callback(result.map { it as T }) }
            return
        }
        val started = epoch
        waiting[key] = mutableListOf({ result -> callback(result.map { it as T }) })
        CarChannel.invoke(context, method, args) { raw ->
            val parsed: Result<Any> = raw.mapCatching { parse(it) }
            if (parsed.isSuccess && started == epoch) cache[key] = parsed.getOrThrow()
            val done = waiting.remove(key).orEmpty()
            for (waiter in done) waiter(parsed)
        }
    }

    private fun onChanged(what: String) {
        epoch++
        when (what) {
            "library" -> cache.clear()
            "track", "queue" -> dropQueueCaches()
            "modes" -> cache.keys.removeAll { it.startsWith("queue:") }
        }
        for (listener in listeners) listener.onChanged(what)
    }

    /** The queue, and the home answer that quotes it (Resume and Up next). */
    private fun dropQueueCaches() {
        epoch++
        cache.keys.removeAll { it == "home" || it.startsWith("queue:") }
    }

    companion object {
        private const val MAX_CACHED = 24

        @Volatile
        private var instance: CarLink? = null

        fun get(context: Context): CarLink = instance ?: synchronized(this) {
            instance ?: CarLink(context.applicationContext).also { instance = it }
        }
    }
}
