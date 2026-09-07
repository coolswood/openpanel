import Foundation
import UIKit

/// Tracks application foreground/background transitions via UIKit
/// notifications: `didBecomeActive` marks the foreground,
/// `didEnterBackground` marks the background.
final class LifecycleTracker {
  private var observers: [NSObjectProtocol] = []

  init(onChange: @escaping (_ foreground: Bool) -> Void) {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { _ in onChange(true) })
    observers.append(
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { _ in onChange(false) })
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }
}
