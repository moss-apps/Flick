package com.mossapps.flick

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

/** A Dart-side failure: an error reply, a missing handler, or a timeout. */
class CarChannelException(
    val code: String,
    message: String?,
    val details: Any? = null,
) : Exception(message ?: code)

/**
 * Kotlin side of `com.mossapps.flick/car`. Requests go to Dart (CarBridge) and
 * come back on the main thread; `changed {what}` events from Dart fan out to
 * listeners.
 *
 * Dart answers are plain maps and lists. Early in a headless start the Dart
 * handler may not exist yet, which surfaces as a [CarChannelException] with
 * code `notImplemented`; callers treat that as "not ready yet".
 */
object CarChannel {
    const val CHANNEL = "com.mossapps.flick/car"
    private const val TIMEOUT_MS = 10_000L
    private const val TAG = "CarChannel"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArrayList<(String) -> Unit>()
    private val lock = Any()
    private var channel: MethodChannel? = null
    private var boundEngine: WeakReference<FlutterEngine>? = null

    /**
     * Calls [method] in Dart. [callback] runs exactly once, on the main thread:
     * with the Dart value, or a failure (error reply, `notImplemented`,
     * `timeout` after 10 s, or the engine could not start). Safe to call from
     * any thread.
     */
    fun invoke(
        context: Context,
        method: String,
        args: Map<String, Any?>?,
        callback: (Result<Any?>) -> Unit,
    ) {
        if (Looper.myLooper() !== Looper.getMainLooper()) {
            mainHandler.post { invoke(context, method, args, callback) }
            return
        }

        val pending = PendingCall(method, callback)
        val boundChannel = try {
            bind(FlickEngine.ensure(context))
        } catch (t: Throwable) {
            Log.e(TAG, "$method: engine unavailable: ${t.message}", t)
            mainHandler.post { pending.finish(Result.failure(t)) }
            return
        }

        mainHandler.postDelayed(pending.timeout, TIMEOUT_MS)
        try {
            boundChannel.invokeMethod(method, args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pending.finish(Result.success(result))
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    pending.finish(
                        Result.failure(CarChannelException(errorCode, errorMessage, errorDetails))
                    )
                }

                override fun notImplemented() {
                    pending.finish(
                        Result.failure(CarChannelException("notImplemented", "$method is not implemented"))
                    )
                }
            })
        } catch (t: Throwable) {
            Log.e(TAG, "$method: invoke failed: ${t.message}", t)
            pending.finish(Result.failure(t))
        }
    }

    /** Called on the main thread with `what` from Dart's `changed`: queue, modes, library or track. */
    fun addListener(listener: (what: String) -> Unit) {
        listeners.addIfAbsent(listener)
    }

    fun removeListener(listener: (what: String) -> Unit) {
        listeners.remove(listener)
    }

    /** Wired by [FlickEngine.prepare]: the incoming handler lives as long as the engine. */
    internal fun attach(engine: FlutterEngine) {
        bind(engine)
    }

    private fun bind(engine: FlutterEngine): MethodChannel = synchronized(lock) {
        val existing = channel
        if (existing != null && boundEngine?.get() === engine) {
            return existing
        }
        val created = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        created.setMethodCallHandler(::onDartCall)
        channel = created
        boundEngine = WeakReference(engine)
        created
    }

    private fun onDartCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "changed" -> {
                val what = (call.arguments as? Map<*, *>)?.get("what") as? String
                if (what.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "changed needs a 'what' string", null)
                    return
                }
                result.success(null)
                for (listener in listeners) {
                    try {
                        listener(what)
                    } catch (t: Throwable) {
                        Log.w(TAG, "changed($what) listener failed: ${t.message}", t)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Guards a callback so a late reply cannot run it after the timeout, or the reverse. */
    private class PendingCall(
        private val method: String,
        private val callback: (Result<Any?>) -> Unit,
    ) {
        private val done = AtomicBoolean(false)

        val timeout = Runnable {
            finish(
                Result.failure(
                    CarChannelException("timeout", "$method did not answer within ${TIMEOUT_MS / 1000}s")
                )
            )
        }

        fun finish(result: Result<Any?>) {
            if (!done.compareAndSet(false, true)) return
            mainHandler.removeCallbacks(timeout)
            try {
                callback(result)
            } catch (t: Throwable) {
                Log.w(TAG, "$method callback failed: ${t.message}", t)
            }
        }
    }
}
