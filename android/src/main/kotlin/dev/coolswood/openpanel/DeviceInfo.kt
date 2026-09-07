package dev.coolswood.openpanel

import android.content.Context
import android.content.res.Resources
import android.os.Build
import java.util.Locale

/** Version of the Flutter SDK reported in headers; keep in sync with pubspec. */
internal const val SDK_VERSION = "0.1.0"

/**
 * Device and app metadata attached to every event. Collected once, lazily —
 * safe to read from any thread after the first access.
 */
internal class DeviceInfo(private val context: Context) {
    val properties: Map<String, Any?> by lazy { collect() }

    val userAgent: String by lazy {
        val props = properties
        val os = "${props["os_name"]} ${props["os_version"]}"
        val model = props["device_model"] ?: ""
        "OpenPanelFlutter/$SDK_VERSION ($os; $model)"
    }

    private fun collect(): Map<String, Any?> = buildMap {
        put("os_name", "Android")
        put("os_version", Build.VERSION.RELEASE)
        put("device_manufacturer", Build.MANUFACTURER)
        put("device_model", Build.MODEL)
        put("locale", Locale.getDefault().toLanguageTag())
        put("sdk_name", "openpanel_flutter")
        put("sdk_version", SDK_VERSION)
        val metrics = Resources.getSystem().displayMetrics
        put("screen_width", metrics.widthPixels)
        put("screen_height", metrics.heightPixels)
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            put("app_version", info.versionName)
            put(
                "app_build",
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    info.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    info.versionCode.toLong()
                },
            )
        } catch (_: Exception) {
            // Package info is unavailable (rare test environments) — skip.
        }
    }
}
