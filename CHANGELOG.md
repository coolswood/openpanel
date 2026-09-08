## 0.1.1

* `setGlobalProperties`: a `null` value now removes the property on both
  platforms (PostHog `register`/`unregister` semantics). Previously a Dart
  `null` arrived on iOS as `NSNull`, which is not a property-list value and
  crashed the app with `NSInvalidArgumentException` when persisted to
  `UserDefaults`.
* iOS: global properties are persisted as JSON data instead of a raw
  dictionary, so any other non-property-list value (e.g. a nested `null`)
  can no longer crash the app either. Old plist-format storage is still
  read.

## 0.1.0

* Initial release with native Android (Kotlin) and iOS (Swift) clients.
* Events: `track`, `identify`, `increment`, `decrement`.
* `setGlobalProperties`, `clear`, `flush`.
* Persistent offline event queue (survives app restarts, capped at 500
  events) with batching: flush on 10 queued events, after 5 seconds, when
  the app goes to background or on explicit `flush()`.
* Automatic `app_opened` / `app_closed` lifecycle tracking (opt-out via
  `OpenpanelOptions.automaticTracking`).
* Automatic device metadata on every event: OS name/version, device
  model/manufacturer, screen size, app version/build, locale.
* Self-hosted instances supported via `OpenpanelOptions.apiUrl`.
* Optional `OpenpanelNavigatorObserver` for `screen_view` tracking.
