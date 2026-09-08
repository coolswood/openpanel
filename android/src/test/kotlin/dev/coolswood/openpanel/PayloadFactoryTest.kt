package dev.coolswood.openpanel

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import org.json.JSONObject

internal class PayloadFactoryTest {

    @Test
    fun `track merges device, global and event properties with event winning`() {
        val device = mapOf(
            "os_name" to "Android",
            "app_version" to "1.0.0",
            "shared" to "device",
        )
        val global = JSONObject()
            .put("env", "prod")
            .put("shared", "global")
        val event = mapOf(
            "button" to "signup",
            "shared" to "event",
        )

        val envelope = PayloadFactory.track("clicked", event, global, device, "user-1")

        assertEquals("track", envelope.getString("type"))
        val payload = envelope.getJSONObject("payload")
        assertEquals("clicked", payload.getString("name"))
        val props = payload.getJSONObject("properties")
        assertEquals("Android", props.getString("os_name"))
        assertEquals("prod", props.getString("env"))
        assertEquals("signup", props.getString("button"))
        assertEquals("event", props.getString("shared"))
        assertEquals("user-1", payload.getString("profileId"))
    }

    @Test
    fun `track without profile omits profileId`() {
        val envelope = PayloadFactory.track("opened", null, JSONObject(), emptyMap(), null)

        val payload = envelope.getJSONObject("payload")
        assertFalse(payload.has("profileId"))
    }

    @Test
    fun `identify includes only provided attributes`() {
        val envelope = PayloadFactory.identify(
            profileId = "user-1",
            firstName = "John",
            lastName = null,
            email = "john@example.com",
            avatar = null,
            properties = mapOf("plan" to "pro"),
        )

        val payload = envelope.getJSONObject("payload")
        assertEquals("identify", envelope.getString("type"))
        assertEquals("user-1", payload.getString("profileId"))
        assertEquals("John", payload.getString("firstName"))
        assertFalse(payload.has("lastName"))
        assertEquals("john@example.com", payload.getString("email"))
        assertFalse(payload.has("avatar"))
        assertEquals("pro", payload.getJSONObject("properties").getString("plan"))
    }

    @Test
    fun `increment uses the given type and fields`() {
        val envelope = PayloadFactory.increment("decrement", "user-1", "credits", 5)

        assertEquals("decrement", envelope.getString("type"))
        val payload = envelope.getJSONObject("payload")
        assertEquals("user-1", payload.getString("profileId"))
        assertEquals("credits", payload.getString("property"))
        assertEquals(5, payload.getInt("value"))
    }

    @Test
    fun `nested maps and lists convert to json`() {
        val event = mapOf(
            "nested" to mapOf("a" to 1),
            "list" to listOf(1, "two", true),
        )

        val envelope = PayloadFactory.track("e", event, JSONObject(), emptyMap(), null)
        val props = envelope.getJSONObject("payload").getJSONObject("properties")

        assertEquals(1, props.getJSONObject("nested").getInt("a"))
        assertEquals(1, props.getJSONArray("list").getInt(0))
        assertEquals("two", props.getJSONArray("list").getString(1))
        assertEquals(true, props.getJSONArray("list").getBoolean(2))
    }

    @Test
    fun `null property values become json null`() {
        val envelope = PayloadFactory.track("e", mapOf("key" to null), JSONObject(), emptyMap(), null)
        val props = envelope.getJSONObject("payload").getJSONObject("properties")

        assertEquals(JSONObject.NULL, props.get("key"))
    }

    @Test
    fun `mergeGlobalProperties overwrites values, adds new and removes on null`() {
        val target = JSONObject()
            .put("env", "prod")
            .put("subscription_id", "sub-1")

        PayloadFactory.mergeGlobalProperties(
            target,
            mapOf(
                "env" to "test",
                "subscription_id" to null,
                "flag" to true,
            ),
        )

        assertEquals("test", target.getString("env"))
        assertFalse(target.has("subscription_id"))
        assertEquals(true, target.getBoolean("flag"))
    }

    @Test
    fun `mergeGlobalProperties with null source keeps target unchanged`() {
        val target = JSONObject().put("env", "prod")

        PayloadFactory.mergeGlobalProperties(target, null)

        assertEquals("prod", target.getString("env"))
    }

    @Test
    fun `mergeGlobalProperties converts nested structures like mergeInto`() {
        val target = JSONObject()

        PayloadFactory.mergeGlobalProperties(
            target,
            mapOf("nested" to mapOf("a" to 1), "list" to listOf(1, "two")),
        )

        assertEquals(1, target.getJSONObject("nested").getInt("a"))
        assertEquals("two", target.getJSONArray("list").getString(1))
    }
}
