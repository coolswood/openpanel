import Foundation
import UIKit

/// Core of the iOS client: owns configuration, the persistent event queue
/// and the flush cycle.
///
/// Threading: all state is confined to a single serial `queue`. Method
/// calls from the plugin hop onto it; channel results are acknowledged
/// immediately, network delivery is asynchronous by design. `DeviceInfo`
/// values are captured on the main thread (method calls arrive there)
/// before hopping.
final class OpenpanelSdk {
  static let defaultApiUrl = "https://api.openpanel.dev"

  private enum Constants {
    static let queueLimit = 500
    static let batchSize = 10
    static let drainLimit = 20
    static let flushDelay: TimeInterval = 5
    static let initialBackoff: TimeInterval = 0.5
    static let maxBackoff: TimeInterval = 60
    static let maxBackoffPower = 7
  }

  private let queue = DispatchQueue(label: "dev.coolswood.openpanel.sdk")
  private let eventQueue = EventQueue(limit: Constants.queueLimit)
  private let deviceInfo = DeviceInfo()

  private var initialized = false
  private var disabled = false
  private var verbose = false
  private var automaticTracking = true
  private var apiUrl = OpenpanelSdk.defaultApiUrl
  private var headers: [String: String] = [:]
  private var profileId: String?
  private var globalProperties: [String: Any] = [:]
  private var inForeground = false
  private var flushScheduled = false
  private var consecutiveFailures = 0
  private var retryNotBefore = Date.distantPast

  func initialize(
    clientId: String,
    clientSecret: String?,
    apiUrl url: String,
    automaticTracking: Bool,
    disabled isDisabled: Bool,
    verbose isVerbose: Bool
  ) {
    // Capture main-thread-only values (UIScreen, UIApplication) while we are
    // still on the calling thread; Flutter method calls arrive on main.
    let metadata = deviceInfo.properties
    let userAgent = deviceInfo.userAgent
    let appActive = deviceInfo.isAppActive

    queue.async { [weak self] in
      guard let self, !self.initialized else { return }
      self.initialized = true
      self.disabled = isDisabled
      self.verbose = isVerbose
      self.automaticTracking = automaticTracking
      self.apiUrl = url.hasSuffix("/") ? String(url.dropLast()) : url
      self.headers = [
        "Content-Type": "application/json",
        "openpanel-client-id": clientId,
        "openpanel-sdk-name": "flutter",
        "openpanel-sdk-version": DeviceInfo.sdkVersion,
        "User-Agent": userAgent,
      ]
      if let clientSecret, !clientSecret.isEmpty {
        self.headers["openpanel-client-secret"] = clientSecret
      }
      self.profileId = self.eventQueue.readProfileId()
      self.globalProperties = self.eventQueue.readGlobalProperties()
      self.logV("initialized: apiUrl=\(self.apiUrl)")

      if !self.disabled, automaticTracking, appActive || self.inForeground {
        // Cold start: the app was already active before Dart ran
        // initialize(), so the foreground transition was missed.
        self.enqueue(
          PayloadFactory.track(
            name: "app_opened",
            properties: nil,
            globalProperties: self.globalProperties,
            deviceProperties: metadata,
            profileId: self.profileId))
      }
    }
  }

  func track(name: String, properties: [String: Any]?) {
    queue.async { [weak self] in
      guard let self, self.initialized, !self.disabled else { return }
      self.enqueue(
        PayloadFactory.track(
          name: name,
          properties: properties,
          globalProperties: self.globalProperties,
          deviceProperties: self.deviceInfo.properties,
          profileId: self.profileId))
    }
  }

  func identify(
    profileId: String,
    firstName: String?,
    lastName: String?,
    email: String?,
    avatar: String?,
    properties: [String: Any]?
  ) {
    queue.async { [weak self] in
      guard let self, self.initialized, !self.disabled else { return }
      self.profileId = profileId
      self.eventQueue.storeProfileId(profileId)
      self.enqueue(
        PayloadFactory.identify(
          profileId: profileId,
          firstName: firstName,
          lastName: lastName,
          email: email,
          avatar: avatar,
          properties: properties))
    }
  }

  func increment(type: String, profileId: String, property: String, value: Int) {
    queue.async { [weak self] in
      guard let self, self.initialized, !self.disabled else { return }
      self.enqueue(PayloadFactory.increment(type: type, profileId: profileId, property: property, value: value))
    }
  }

  func setGlobalProperties(_ properties: [String: Any]) {
    queue.async { [weak self] in
      guard let self, self.initialized, !self.disabled else { return }
      // A Dart null arrives as NSNull over the method channel and means
      // "remove the property" (PostHog register/unregister semantics). It
      // must never reach storage: NSNull is not a property-list value and
      // makes UserDefaults throw NSInvalidArgumentException.
      properties.forEach { key, value in
        if value is NSNull {
          self.globalProperties.removeValue(forKey: key)
        } else {
          self.globalProperties[key] = value
        }
      }
      self.eventQueue.storeGlobalProperties(self.globalProperties)
    }
  }

  func clear() {
    queue.async { [weak self] in
      guard let self else { return }
      self.profileId = nil
      self.globalProperties = [:]
      self.eventQueue.clear()
      self.logV("cleared profile, global properties and event queue")
    }
  }

  func flush(reason: String) {
    queue.async { [weak self] in
      self?.drain(reason: reason)
    }
  }

  func onAppLifecycle(inForeground: Bool) {
    queue.async { [weak self] in
      guard let self else { return }
      let wasForeground = self.inForeground
      self.inForeground = inForeground
      if self.initialized, !self.disabled, self.automaticTracking {
        if inForeground, !wasForeground {
          self.enqueue(
            PayloadFactory.track(
              name: "app_opened",
              properties: nil,
              globalProperties: self.globalProperties,
              deviceProperties: self.deviceInfo.properties,
              profileId: self.profileId))
        }
        if !inForeground, wasForeground {
          self.enqueue(
            PayloadFactory.track(
              name: "app_closed",
              properties: nil,
              globalProperties: self.globalProperties,
              deviceProperties: self.deviceInfo.properties,
              profileId: self.profileId))
        }
      }
      if !inForeground {
        self.drain(reason: "background")
      }
    }
  }

  private func enqueue(_ envelope: [String: Any]) {
    eventQueue.append(envelope)
    let pending = eventQueue.count()
    logV("queued (pending: \(pending))")
    if pending >= Constants.batchSize {
      drain(reason: "batch")
    } else {
      scheduleFlush(after: Constants.flushDelay)
    }
  }

  private func scheduleFlush(after delay: TimeInterval) {
    guard !flushScheduled else { return }
    flushScheduled = true
    queue.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self else { return }
      self.flushScheduled = false
      self.drain(reason: "timer")
    }
  }

  /// Sends queued events one by one. A bad request (4xx except 429) drops
  /// only the offending event; network errors and 5xx/429 keep the queue
  /// and back off exponentially.
  private func drain(reason: String) {
    guard initialized, !disabled else { return }
    let now = Date()
    if now < retryNotBefore {
      scheduleFlush(after: now.distance(to: retryNotBefore) + 0.1)
      return
    }
    while !eventQueue.isEmpty() {
      let batch = eventQueue.peek(limit: Constants.drainLimit)
      if batch.isEmpty { break }
      var failed = false
      var sent = 0
      for envelope in batch {
        let outcome = HttpPoster.post(url: "\(apiUrl)/track", headers: headers, body: envelope)
        switch outcome {
        case .success:
          eventQueue.removeFirst()
          sent += 1
        case .clientError(let code):
          eventQueue.removeFirst()
          logV("dropped invalid event: HTTP \(code)")
        case .retryable(let code, let error):
          failed = true
          logV("send failed: HTTP \(code.map(String.init) ?? "nil") \(error.map { String(describing: $0) } ?? "")")
        }
        if failed { break }
      }
      if failed {
        consecutiveFailures += 1
        let backoff = min(
          Constants.maxBackoff,
          Constants.initialBackoff * pow(2, Double(min(consecutiveFailures - 1, Constants.maxBackoffPower))))
        retryNotBefore = Date().addingTimeInterval(backoff)
        logV("flush (\(reason)) failed \(consecutiveFailures)x, backing off \(backoff)s")
        scheduleFlush(after: backoff)
        return
      }
      if sent > 0 { logV("flush (\(reason)): sent \(sent) event(s)") }
    }
    if consecutiveFailures > 0 { logV("flush (\(reason)) recovered") }
    consecutiveFailures = 0
  }

  private func logV(_ message: String) {
    if verbose {
      // NSLog instead of print: os_log output is forwarded to the Flutter
      // console, Xcode and Console.app — print() stdout is not.
      NSLog("OpenpanelSdk: %@", message)
    }
  }
}
