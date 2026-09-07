import Flutter
import UIKit

/// Entry point of the openpanel plugin.
///
/// The channel layer is intentionally thin: arguments are unpacked here and
/// handed to `OpenpanelSdk`, which owns all state on a single serial queue.
public class OpenpanelPlugin: NSObject, FlutterPlugin {
  private let sdk = OpenpanelSdk()
  private var lifecycleTracker: LifecycleTracker?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "openpanel", binaryMessenger: registrar.messenger())
    let instance = OpenpanelPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.start()
  }

  /// Registers lifecycle observers. Kept out of `init` so `sdk` is fully
  /// constructed first.
  private func start() {
    lifecycleTracker = LifecycleTracker { [weak sdk] foreground in
      sdk?.onAppLifecycle(inForeground: foreground)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "initialize":
      guard let clientId = args["clientId"] as? String, !clientId.isEmpty else {
        result(FlutterError(code: "invalid_arguments", message: "clientId is required", details: nil))
        return
      }
      sdk.initialize(
        clientId: clientId,
        clientSecret: args["clientSecret"] as? String,
        apiUrl: args["apiUrl"] as? String ?? OpenpanelSdk.defaultApiUrl,
        automaticTracking: args["automaticTracking"] as? Bool ?? true,
        disabled: args["disabled"] as? Bool ?? false,
        verbose: args["verbose"] as? Bool ?? false)
      result(nil)

    case "track":
      sdk.track(
        name: args["name"] as? String ?? "unknown",
        properties: args["properties"] as? [String: Any])
      result(nil)

    case "identify":
      guard let profileId = args["profileId"] as? String, !profileId.isEmpty else {
        result(FlutterError(code: "invalid_arguments", message: "profileId is required", details: nil))
        return
      }
      sdk.identify(
        profileId: profileId,
        firstName: args["firstName"] as? String,
        lastName: args["lastName"] as? String,
        email: args["email"] as? String,
        avatar: args["avatar"] as? String,
        properties: args["properties"] as? [String: Any])
      result(nil)

    case "increment", "decrement":
      guard let profileId = args["profileId"] as? String, !profileId.isEmpty,
        let property = args["property"] as? String, !property.isEmpty
      else {
        result(FlutterError(code: "invalid_arguments", message: "profileId and property are required", details: nil))
        return
      }
      sdk.increment(
        type: call.method,
        profileId: profileId,
        property: property,
        value: (args["value"] as? NSNumber)?.intValue ?? 1)
      result(nil)

    case "setGlobalProperties":
      sdk.setGlobalProperties(args["properties"] as? [String: Any] ?? [:])
      result(nil)

    case "clear":
      sdk.clear()
      result(nil)

    case "flush":
      sdk.flush(reason: "manual")
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
