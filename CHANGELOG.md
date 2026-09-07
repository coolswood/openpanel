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
