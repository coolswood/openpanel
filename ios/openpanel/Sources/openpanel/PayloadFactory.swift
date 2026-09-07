import Foundation

/// Builds wire-format envelopes for the OpenPanel `/track` endpoint:
/// `{"type": "...", "payload": {...}}`.
///
/// Values arriving through the Flutter standard codec are already
/// JSON-serializable, so no recursive conversion is needed here.
enum PayloadFactory {
  static func track(
    name: String,
    properties: [String: Any]?,
    globalProperties: [String: Any],
    deviceProperties: [String: Any],
    profileId: String?
  ) -> [String: Any] {
    // Merge precedence (later wins): device metadata < global properties
    // < event properties.
    var merged = deviceProperties
    globalProperties.forEach { merged[$0.key] = $0.value }
    properties?.forEach { merged[$0.key] = $0.value }
    var payload: [String: Any] = ["name": name, "properties": merged]
    if let profileId, !profileId.isEmpty {
      payload["profileId"] = profileId
    }
    return envelope(type: "track", payload: payload)
  }

  static func identify(
    profileId: String,
    firstName: String?,
    lastName: String?,
    email: String?,
    avatar: String?,
    properties: [String: Any]?
  ) -> [String: Any] {
    var payload: [String: Any] = ["profileId": profileId]
    if let firstName, !firstName.isEmpty { payload["firstName"] = firstName }
    if let lastName, !lastName.isEmpty { payload["lastName"] = lastName }
    if let email, !email.isEmpty { payload["email"] = email }
    if let avatar, !avatar.isEmpty { payload["avatar"] = avatar }
    if let properties, !properties.isEmpty { payload["properties"] = properties }
    return envelope(type: "identify", payload: payload)
  }

  static func increment(
    type: String,
    profileId: String,
    property: String,
    value: Int
  ) -> [String: Any] {
    envelope(
      type: type,
      payload: ["profileId": profileId, "property": property, "value": value])
  }

  private static func envelope(type: String, payload: [String: Any]) -> [String: Any] {
    ["type": type, "payload": payload]
  }
}
