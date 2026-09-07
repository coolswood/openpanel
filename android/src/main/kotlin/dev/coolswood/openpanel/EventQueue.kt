package dev.coolswood.openpanel

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persistent event queue plus small key-value state (profile id, global
 * properties) on top of SharedPreferences.
 *
 * Every operation re-reads and rewrites the whole JSON array: with the
 * default cap of 500 events this stays in the low-millisecond range and
 * keeps the code trivial. All methods must be called from the SDK executor
 * thread only.
 */
internal class EventQueue(context: Context, private val limit: Int) {
    private val prefs = context.getSharedPreferences("openpanel", Context.MODE_PRIVATE)

    fun append(envelope: JSONObject) {
        val array = readArray()
        array.put(envelope)
        while (array.length() > limit) array.remove(0)
        persist(array)
    }

    fun peek(max: Int): List<JSONObject> {
        val array = readArray()
        val count = minOf(max, array.length())
        return (0 until count).mapNotNull { array.optJSONObject(it) }
    }

    fun removeFirst() {
        val array = readArray()
        if (array.length() > 0) array.remove(0)
        persist(array)
    }

    fun size(): Int = readArray().length()

    fun clear() {
        prefs.edit().remove(KEY_QUEUE).apply()
    }

    fun storeProfileId(profileId: String?) {
        prefs.edit().apply {
            if (profileId == null) remove(KEY_PROFILE_ID) else putString(KEY_PROFILE_ID, profileId)
        }.apply()
    }

    fun readProfileId(): String? = prefs.getString(KEY_PROFILE_ID, null)

    fun storeGlobalProperties(properties: JSONObject) {
        prefs.edit().putString(KEY_GLOBAL_PROPERTIES, properties.toString()).apply()
    }

    fun readGlobalProperties(): JSONObject = try {
        JSONObject(prefs.getString(KEY_GLOBAL_PROPERTIES, "{}") ?: "{}")
    } catch (_: Exception) {
        JSONObject()
    }

    private fun readArray(): JSONArray = try {
        JSONArray(prefs.getString(KEY_QUEUE, "[]") ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }

    private fun persist(array: JSONArray) {
        prefs.edit().putString(KEY_QUEUE, array.toString()).apply()
    }

    private companion object {
        const val KEY_QUEUE = "queue"
        const val KEY_PROFILE_ID = "profile_id"
        const val KEY_GLOBAL_PROPERTIES = "global_properties"
    }
}
