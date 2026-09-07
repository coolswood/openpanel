import Foundation
import UIKit

/// Device and app metadata attached to every event.
///
/// `properties` and `userAgent` are collected lazily on first access — the
/// first access happens on the main thread during `initialize` (UIScreen
/// and UIApplication are main-thread-only), afterwards the cached values
/// are safe to read from any thread.
final class DeviceInfo {
  /// Version of the Flutter SDK reported in headers; keep in sync with pubspec.
  static let sdkVersion = "0.1.0"

  private(set) lazy var properties: [String: Any] = collect()
  private(set) lazy var userAgent: String = {
    let props = properties
    let os = "\(props["os_name"] ?? "") \(props["os_version"] ?? "")"
    let model = props["device_model"] ?? ""
    return "OpenPanelFlutter/\(DeviceInfo.sdkVersion) (\(os); \(model))"
  }()

  /// Whether the application is currently visible; main-thread only.
  var isAppActive: Bool {
    let state = UIApplication.shared.applicationState
    return state == .active || state == .inactive
  }

  private func collect() -> [String: Any] {
    let device = UIDevice.current
    let bundle = Bundle.main
    var props: [String: Any] = [
      "os_name": device.systemName,
      "os_version": device.systemVersion,
      "device_model": machineIdentifier(),
      "locale": Locale.current.identifier,
      "sdk_name": "openpanel_flutter",
      "sdk_version": DeviceInfo.sdkVersion,
    ]
    let screen = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.screen }
      .first
    if let screen {
      props["screen_width"] = Int(screen.bounds.width * screen.scale)
      props["screen_height"] = Int(screen.bounds.height * screen.scale)
    }
    if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
      props["app_version"] = version
    }
    if let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
      props["app_build"] = build
    }
    return props
  }

  /// Hardware model identifier like "iPhone17,1" — more precise than
  /// `UIDevice.model` which only returns "iPhone"/"iPad".
  private func machineIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let bytes = mirror.children.compactMap { child -> UInt8? in
      guard let value = child.value as? Int8 else { return nil }
      return value != 0 ? UInt8(value) : nil
    }
    return String(bytes: bytes, encoding: .utf8) ?? UIDevice.current.model
  }
}
