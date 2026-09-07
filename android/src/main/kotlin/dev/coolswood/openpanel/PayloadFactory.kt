package dev.coolswood.openpanel

import org.json.JSONArray
import org.json.JSONObject

/**
 * Builds wire-format envelopes for the OpenPanel `/track` endpoint:
 * `{"type": "...", "payload": {...}}`.
 *
 * Pure JSON logic, no Android dependencies — covered by unit tests.
 */
internal object PayloadFactory {

    fun track(
        name: String,
        properties: Map<String, Any?>?,
        globalProperties: JSONObject,
        deviceProperties: Map<String, Any?>,
        profileId: String?,
    ): JSONObject {
        // Merge precedence (later wins): device metadata < global properties
        // < event properties.
        val merged = JSONObject()
        mergeInto(merged, deviceProperties)
        mergeInto(merged, globalProperties)
        mergeInto(merged, properties)
        val payload = JSONObject()
            .put("name", name)
            .put("properties", merged)
        profileId?.takeIf { it.isNotEmpty() }?.let { payload.put("profileId", it) }
        return envelope("track", payload)
    }

    fun identify(
        profileId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        avatar: String?,
        properties: Map<String, Any?>?,
    ): JSONObject {
        val payload = JSONObject()
            .put("profileId", profileId)
        firstName?.takeIf { it.isNotEmpty() }?.let { payload.put("firstName", it) }
        lastName?.takeIf { it.isNotEmpty() }?.let { payload.put("lastName", it) }
        email?.takeIf { it.isNotEmpty() }?.let { payload.put("email", it) }
        avatar?.takeIf { it.isNotEmpty() }?.let { payload.put("avatar", it) }
        if (!properties.isNullOrEmpty()) payload.put("properties", toJson(properties) as JSONObject)
        return envelope("identify", payload)
    }

    fun increment(type: String, profileId: String, property: String, value: Int): JSONObject =
        envelope(
            type,
            JSONObject()
                .put("profileId", profileId)
                .put("property", property)
                .put("value", value),
        )

    /** Merges [source] entries into [target], converting values to JSON types. */
    fun mergeInto(target: JSONObject, source: Map<String, Any?>?) {
        if (source == null) return
        for ((key, value) in source) {
            target.put(key, toJson(value))
        }
    }

    /** Merges entries of a persisted [source] into [target]. */
    fun mergeInto(target: JSONObject, source: JSONObject?) {
        if (source == null) return
        for (key in source.keys()) {
            target.put(key, source.get(key))
        }
    }

    private fun envelope(type: String, payload: JSONObject): JSONObject =
        JSONObject()
            .put("type", type)
            .put("payload", payload)

    /**
     * Converts values coming from the Flutter standard codec (and JSONObject
     * global properties) into org.json types recursively.
     */
    private fun toJson(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> {
            val obj = JSONObject()
            for ((key, v) in value) obj.put(key.toString(), toJson(v))
            obj
        }

        is List<*> -> {
            val arr = JSONArray()
            for (v in value) arr.put(toJson(v))
            arr
        }

        is Float -> value.toDouble()
        is String, is Boolean, is Int, is Long, is Double -> value
        else -> value.toString()
    }
}
