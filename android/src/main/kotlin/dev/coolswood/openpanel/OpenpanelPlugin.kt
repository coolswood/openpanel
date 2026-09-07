package dev.coolswood.openpanel

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Entry point of the openpanel plugin.
 *
 * The channel layer is intentionally thin: arguments are unpacked here and
 * handed to [OpenpanelSdk], which owns all state on a single background
 * thread.
 */
class OpenpanelPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var sdk: OpenpanelSdk? = null
    private var lifecycleTracker: LifecycleTracker? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val openpanelSdk = OpenpanelSdk(binding.applicationContext)
        sdk = openpanelSdk
        lifecycleTracker = LifecycleTracker(binding.applicationContext) { foreground ->
            openpanelSdk.onAppLifecycle(foreground)
        }
        val methodChannel = MethodChannel(binding.binaryMessenger, "openpanel")
        methodChannel.setMethodCallHandler(this)
        channel = methodChannel
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val openpanelSdk = sdk
        if (openpanelSdk == null) {
            result.error("unavailable", "openpanel plugin is not attached", null)
            return
        }

        when (call.method) {
            "initialize" -> {
                val clientId = call.argument<String>("clientId")
                if (clientId.isNullOrEmpty()) {
                    result.error("invalid_arguments", "clientId is required", null)
                    return
                }
                openpanelSdk.initialize(
                    clientId = clientId,
                    clientSecret = call.argument("clientSecret"),
                    apiUrl = call.argument<String>("apiUrl") ?: OpenpanelSdk.DEFAULT_API_URL,
                    automaticTracking = call.argument<Boolean>("automaticTracking") ?: true,
                    disabled = call.argument<Boolean>("disabled") ?: false,
                    verbose = call.argument<Boolean>("verbose") ?: false,
                )
                result.success(null)
            }

            "track" -> {
                openpanelSdk.track(
                    name = call.argument<String>("name") ?: "unknown",
                    properties = call.argument<Map<String, Any?>>("properties"),
                )
                result.success(null)
            }

            "identify" -> {
                val profileId = call.argument<String>("profileId")
                if (profileId.isNullOrEmpty()) {
                    result.error("invalid_arguments", "profileId is required", null)
                    return
                }
                openpanelSdk.identify(
                    profileId = profileId,
                    firstName = call.argument("firstName"),
                    lastName = call.argument("lastName"),
                    email = call.argument("email"),
                    avatar = call.argument("avatar"),
                    properties = call.argument<Map<String, Any?>>("properties"),
                )
                result.success(null)
            }

            "increment", "decrement" -> {
                val profileId = call.argument<String>("profileId")
                val property = call.argument<String>("property")
                if (profileId.isNullOrEmpty() || property.isNullOrEmpty()) {
                    result.error("invalid_arguments", "profileId and property are required", null)
                    return
                }
                val value = call.argument<Number>("value")?.toInt() ?: 1
                openpanelSdk.increment(
                    type = call.method,
                    profileId = profileId,
                    property = property,
                    value = value,
                )
                result.success(null)
            }

            "setGlobalProperties" -> {
                openpanelSdk.setGlobalProperties(call.argument<Map<String, Any?>>("properties"))
                result.success(null)
            }

            "clear" -> {
                openpanelSdk.clear()
                result.success(null)
            }

            "flush" -> {
                openpanelSdk.flush(reason = "manual")
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        lifecycleTracker?.dispose()
        lifecycleTracker = null
        sdk?.dispose()
        sdk = null
    }
}
