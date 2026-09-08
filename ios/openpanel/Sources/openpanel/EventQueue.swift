import Foundation

/// Persistent event queue (a JSON file in Application Support) plus small
/// key-value state (profile id, global properties) in UserDefaults.
///
/// Every operation re-reads and rewrites the whole file: with the default
/// cap of 500 events this stays in the low-millisecond range and keeps the
/// code trivial. All methods must be called from the SDK serial queue only.
final class EventQueue {
  private let limit: Int
  private let fileUrl: URL
  private let storage: UserDefaults

  init(limit: Int) {
    self.limit = limit
    let directory =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    fileUrl = directory.appendingPathComponent("openpanel_queue.json")
    storage = UserDefaults.standard
  }

  func append(_ envelope: [String: Any]) {
    var events = readAll()
    events.append(envelope)
    writeAll(events)
  }

  func peek(limit max: Int) -> [[String: Any]] {
    Array(readAll().prefix(max))
  }

  func removeFirst() {
    var events = readAll()
    guard !events.isEmpty else { return }
    events.removeFirst()
    writeAll(events)
  }

  func count() -> Int {
    readAll().count
  }

  func isEmpty() -> Bool {
    readAll().isEmpty
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileUrl)
  }

  func storeProfileId(_ profileId: String?) {
    if let profileId {
      storage.set(profileId, forKey: Keys.profileId)
    } else {
      storage.removeObject(forKey: Keys.profileId)
    }
  }

  func readProfileId() -> String? {
    storage.string(forKey: Keys.profileId)
  }

  func storeGlobalProperties(_ properties: [String: Any]) {
    // UserDefaults accepts only property-list values, and the standard
    // codec delivers types NSNull among them that are not property-list
    // (storing them raises NSInvalidArgumentException). Encoding through
    // JSON makes any codec value storable; non-JSON values are simply not
    // persisted (in-memory state still works until restart).
    if JSONSerialization.isValidJSONObject(properties),
      let data = try? JSONSerialization.data(withJSONObject: properties)
    {
      storage.set(data, forKey: Keys.globalProperties)
    }
  }

  func readGlobalProperties() -> [String: Any] {
    if let data = storage.data(forKey: Keys.globalProperties),
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    {
      return object
    }
    // Stored before 0.1.1 as a plain plist dictionary.
    return storage.dictionary(forKey: Keys.globalProperties) ?? [:]
  }

  private func readAll() -> [[String: Any]] {
    guard let data = try? Data(contentsOf: fileUrl),
      let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    else { return [] }
    return array
  }

  private func writeAll(_ events: [[String: Any]]) {
    let trimmed = Array(events.suffix(limit))
    if let data = try? JSONSerialization.data(withJSONObject: trimmed) {
      try? data.write(to: fileUrl, options: .atomic)
    }
  }

  private enum Keys {
    static let profileId = "openpanel.profileId"
    static let globalProperties = "openpanel.globalProperties"
  }
}
