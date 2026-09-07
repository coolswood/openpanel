# openpanel

[OpenPanel](https://openpanel.dev) analytics for Flutter with **native
Android (Kotlin) and iOS (Swift) clients**, a **persistent offline event
queue** and **batching**.

OpenPanel does not ship an official Flutter SDK — this package fills the gap
with hand-written native clients that speak the documented
[`/track` REST API](https://openpanel.dev/docs/api/track) directly, mirroring
the API of the official mobile SDKs.

## Features

- **Native clients, zero native dependencies**: Kotlin (`HttpURLConnection`)
  and Swift (`URLSession`) implementations, no OpenPanel SDK dependencies,
  no third-party libraries.
- **Full API**: `track`, `identify`, `increment`, `decrement`,
  `setGlobalProperties`, `clear`, `flush` — everything the official mobile
  SDKs expose.
- **Persistent offline queue**: events survive app restarts (capped at 500,
  oldest dropped first).
- **Batching**: the queue is flushed when it reaches 10 events, 5 seconds
  after the first queued event, when the app goes to the background, or on
  an explicit `flush()`. Failures retry with exponential backoff (0.5s up to
  60s); events rejected with a 4xx are dropped instead of blocking the queue.
- **Lifecycle tracking**: automatic `app_opened` / `app_closed` events
  (opt-out via `automaticTracking: false`).
- **Device metadata on every event**: OS name/version, device
  model/manufacturer, screen size, app version/build, locale, SDK version.
- **Self-hosted support** via `apiUrl`.
- **Analytics never crashes the app**: platform errors are swallowed (logged
  in debug), release builds drop events sent before initialization.

## Platform support

| Android | iOS   |
| ------- | ----- |
| API 24+ | 15.0+ |

> Android release builds need the `INTERNET` permission in the *main*
> manifest (the Flutter debug template adds it only for debug builds).
> Networked apps already have it.

## Usage

### Initialize

```dart
import 'package:openpanel/openpanel.dart';

await Openpanel.instance.initialize(
  OpenpanelOptions(clientId: 'YOUR_CLIENT_ID'),
);
```

For a self-hosted instance:

```dart
await Openpanel.instance.initialize(
  OpenpanelOptions(
    clientId: 'YOUR_CLIENT_ID',
    apiUrl: 'https://openpanel.example.com',
  ),
);
```

Events tracked before initialization completes are held back and delivered
afterwards. In debug builds tracking before `initialize` throws a
`StateError` to surface mis-wiring early; in release builds such events are
dropped silently.

### Track events

```dart
Openpanel.instance.track('button_clicked', properties: {
  'button': 'signup',
});
```

Property values must be JSON-compatible primitives (`num`, `String`, `bool`,
`null`, lists and nested maps of those).

### Identify users

```dart
Openpanel.instance.identify(
  'user-42',
  firstName: 'John',
  email: 'john@example.com',
  properties: {'plan': 'pro'},
);
```

After `identify`, every subsequent `track` event carries the `profileId`.
The binding persists across app restarts until `clear()` is called.

### Profile counters

```dart
Openpanel.instance.increment('user-42', 'login_count', value: 1);
Openpanel.instance.decrement('user-42', 'credits_remaining', value: 5);
```

### Global properties

```dart
Openpanel.instance.setGlobalProperties({'environment': 'production'});
```

Merged into every future `track` event (event properties win on conflicts);
persists across app restarts until `clear()`.

### Screen views (optional)

```dart
MaterialApp(
  navigatorObservers: [OpenpanelNavigatorObserver()],
  // ...
);
```

Reports `screen_view` events with `{ 'name': <route name> }` for routes that
have a non-empty name.

## API

| Method | Description |
| --- | --- |
| `initialize(options)` | Configure and start the SDK (once). |
| `track(name, {properties})` | Send a named event. |
| `identify(profileId, {firstName, lastName, email, avatar, properties})` | Bind events to a user profile. |
| `increment(profileId, property, {value})` | Increment a numeric profile property. |
| `decrement(profileId, property, {value})` | Decrement a numeric profile property. |
| `setGlobalProperties(properties)` | Merge properties attached to every event. |
| `flush()` | Send everything queued immediately. |
| `clear()` | Clear profile binding, global properties and the queue. |

### Options

| Option | Default | Description |
| --- | --- | --- |
| `clientId` | — | Client ID of your OpenPanel project (required). |
| `clientSecret` | `null` | Optional; the track endpoint works without it. A secret embedded in a mobile app is public anyway. |
| `apiUrl` | `https://api.openpanel.dev` | Base API URL; point to your self-hosted instance. |
| `automaticTracking` | `true` | Track `app_opened` / `app_closed` automatically. |
| `disabled` | `false` | Drop all events, send nothing. |
| `verbose` | `false` | Log every queued/sent event natively. |

## Example

See the [example](example/) app. Run it with your credentials:

```sh
cd example && flutter run \
  --dart-define=OPENPANEL_CLIENT_ID=... \
  --dart-define=OPENPANEL_API_URL=https://your-openpanel.example.com
```

## Comparison with `openpanel_flutter`

The existing community package is an unofficial thin client. Differences:

- `identify` / `increment` / `decrement` (profile attributes and counters) —
  this package supports them.
- Persistent offline queue — events survive restarts; both official SDKs
  and the community package keep at most an in-memory buffer.
- Actively built on the documented REST protocol (`{type, payload}`
  envelopes) instead of the unpublished Kotlin SDK.

## License

MIT — see [LICENSE](LICENSE).
