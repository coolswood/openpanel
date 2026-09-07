package dev.coolswood.openpanel

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Core of the Android client: owns configuration, the persistent event queue
 * and the flush cycle.
 *
 * Threading: every method call is a fire-and-forget task posted to a single
 * background [executor], so all mutable state below is touched by one thread
 * only. Channel results are acknowledged immediately; network delivery is
 * asynchronous by design.
 */
internal class OpenpanelSdk(private val context: Context) {
    companion object {
        const val DEFAULT_API_URL = "https://api.openpanel.dev"

        private const val TAG = "Openpanel"
        private const val QUEUE_LIMIT = 500
        private const val BATCH_SIZE = 10
        private const val DRAIN_LIMIT = 20
        private const val FLUSH_DELAY_MS = 5_000L
        private const val INITIAL_BACKOFF_MS = 500L
        private const val MAX_BACKOFF_MS = 60_000L
        private const val MAX_BACKOFF_POWER = 7
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val queue = EventQueue(context, QUEUE_LIMIT)
    private val deviceInfo = DeviceInfo(context)

    private var initialized = false
    private var disabled = false
    private var verbose = false
    private var automaticTracking = true
    private var apiUrl = DEFAULT_API_URL
    private var headers: Map<String, String> = emptyMap()
    private var profileId: String? = null
    private var globalProperties = JSONObject()
    private var inForeground = false
    private val flushScheduled = AtomicBoolean(false)
    private var consecutiveFailures = 0
    private var retryNotBeforeMs = 0L

    fun initialize(
        clientId: String,
        clientSecret: String?,
        apiUrl: String,
        automaticTracking: Boolean,
        disabled: Boolean,
        verbose: Boolean,
    ) {
        executor.execute {
            if (initialized) return@execute
            initialized = true
            this.disabled = disabled
            this.verbose = verbose
            this.automaticTracking = automaticTracking
            this.apiUrl = apiUrl.trimEnd('/')
            profileId = queue.readProfileId()
            globalProperties = queue.readGlobalProperties()
            headers = buildMap {
                put("Content-Type", "application/json")
                put("openpanel-client-id", clientId)
                put("openpanel-sdk-name", "flutter")
                put("openpanel-sdk-version", SDK_VERSION)
                clientSecret?.takeIf { it.isNotEmpty() }?.let { put("openpanel-client-secret", it) }
                put("User-Agent", deviceInfo.userAgent)
            }
            logV("initialized: apiUrl=$apiUrl clientId=${clientId.take(8)}…")

            if (!disabled && automaticTracking && inForeground) {
                // Cold start: the activity was already started before Dart ran
                // initialize(), so the foreground transition was missed.
                enqueue(PayloadFactory.track("app_opened", null, globalProperties, deviceInfo.properties, profileId))
            }
        }
    }

    fun track(name: String, properties: Map<String, Any?>?) {
        executor.execute {
            if (!initialized || disabled) return@execute
            enqueue(PayloadFactory.track(name, properties, globalProperties, deviceInfo.properties, profileId))
        }
    }

    fun identify(
        profileId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        avatar: String?,
        properties: Map<String, Any?>?,
    ) {
        executor.execute {
            if (!initialized || disabled) return@execute
            this.profileId = profileId
            queue.storeProfileId(profileId)
            enqueue(
                PayloadFactory.identify(profileId, firstName, lastName, email, avatar, properties),
            )
        }
    }

    fun increment(type: String, profileId: String, property: String, value: Int) {
        executor.execute {
            if (!initialized || disabled) return@execute
            enqueue(PayloadFactory.increment(type, profileId, property, value))
        }
    }

    fun setGlobalProperties(properties: Map<String, Any?>?) {
        executor.execute {
            if (!initialized || disabled) return@execute
            PayloadFactory.mergeInto(globalProperties, properties)
            queue.storeGlobalProperties(globalProperties)
        }
    }

    fun clear() {
        executor.execute {
            profileId = null
            globalProperties = JSONObject()
            queue.clear()
            logV("cleared profile, global properties and event queue")
        }
    }

    fun flush(reason: String) {
        executor.execute { drain(reason) }
    }

    fun onAppLifecycle(foreground: Boolean) {
        executor.execute {
            val wasForeground = inForeground
            inForeground = foreground
            if (initialized && !disabled && automaticTracking) {
                if (foreground && !wasForeground) {
                    enqueue(
                        PayloadFactory.track("app_opened", null, globalProperties, deviceInfo.properties, profileId),
                    )
                }
                if (!foreground && wasForeground) {
                    enqueue(
                        PayloadFactory.track("app_closed", null, globalProperties, deviceInfo.properties, profileId),
                    )
                }
            }
            if (!foreground) {
                drain("background")
            }
        }
    }

    fun dispose() {
        executor.shutdown()
    }

    private fun enqueue(envelope: JSONObject) {
        queue.append(envelope)
        logV("queued: ${envelope.optJSONObject("payload")?.optString("name", "?")} (${queue.size()} pending)")
        if (queue.size() >= BATCH_SIZE) {
            drain("batch")
        } else {
            scheduleFlush(FLUSH_DELAY_MS)
        }
    }

    private fun scheduleFlush(delayMs: Long) {
        if (!flushScheduled.compareAndSet(false, true)) return
        mainHandler.postDelayed(
            {
                flushScheduled.set(false)
                executor.execute { drain("timer") }
            },
            delayMs,
        )
    }

    /**
     * Sends queued events one by one. A bad request (4xx except 429) drops
     * only the offending event; network errors and 5xx/429 keep the queue
     * and back off exponentially.
     */
    private fun drain(reason: String) {
        if (!initialized || disabled) return
        val now = System.currentTimeMillis()
        if (now < retryNotBeforeMs) {
            scheduleFlush(retryNotBeforeMs - now + 100)
            return
        }
        while (true) {
            val batch = queue.peek(DRAIN_LIMIT)
            if (batch.isEmpty()) break
            var failed = false
            var sent = 0
            for (envelope in batch) {
                when (val outcome = HttpPoster.post("$apiUrl/track", headers, envelope.toString())) {
                    is HttpResult.Ok -> {
                        queue.removeFirst()
                        sent++
                    }

                    is HttpResult.BadRequest -> {
                        queue.removeFirst()
                        logV("dropped invalid event: HTTP ${outcome.code}")
                    }

                    is HttpResult.Retryable -> {
                        failed = true
                        logV("send failed: HTTP ${outcome.code} ${outcome.error ?: ""}")
                        break
                    }
                }
            }
            if (failed) {
                consecutiveFailures++
                val backoffMs = minOf(
                    MAX_BACKOFF_MS,
                    INITIAL_BACKOFF_MS shl (consecutiveFailures - 1).coerceAtMost(MAX_BACKOFF_POWER),
                )
                retryNotBeforeMs = System.currentTimeMillis() + backoffMs
                logV("flush ($reason) failed ${consecutiveFailures}x, backing off ${backoffMs}ms")
                scheduleFlush(backoffMs)
                return
            }
            if (sent > 0) logV("flush ($reason): sent $sent event(s)")
        }
        if (consecutiveFailures > 0) logV("flush ($reason) recovered")
        consecutiveFailures = 0
    }

    private fun logV(message: String) {
        if (verbose) Log.d(TAG, message)
    }
}
