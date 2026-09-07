import 'dart:async';

import 'package:flutter/foundation.dart';

import 'openpanel_options.dart';
import 'openpanel_platform_interface.dart';

export 'openpanel_options.dart';

/// Flutter SDK for [OpenPanel](https://openpanel.dev) — open-source product
/// analytics.
///
/// Events are sent by native clients (Kotlin on Android, Swift on iOS) with
/// a persistent offline queue: events survive app restarts and are flushed in
/// batches when the queue grows, after a short delay, when the app goes to
/// the background, or on an explicit [flush].
///
/// Usage:
///
/// ```dart
/// await Openpanel.instance.initialize(
///   OpenpanelOptions(clientId: 'YOUR_CLIENT_ID'),
/// );
///
/// Openpanel.instance.track('button_clicked', properties: {'button': 'signup'});
/// Openpanel.instance.identify('user-42', email: 'user@example.com');
/// ```
///
/// Events sent before [initialize] completes are held back and delivered
/// afterwards; calls made before [initialize] was ever invoked are dropped
/// with a console warning in debug builds (an analytics SDK must never
/// crash the host app).
class Openpanel {
  Openpanel._();

  /// The singleton instance of the SDK.
  static final Openpanel instance = Openpanel._();

  /// Name reported to OpenPanel in the `openpanel-sdk-name` header.
  static const String sdkName = 'openpanel_flutter';

  /// Version of this SDK reported to OpenPanel.
  ///
  /// Keep in sync with `pubspec.yaml`, `SDK_VERSION` in the Kotlin sources
  /// and `DeviceInfo.sdkVersion` in the Swift sources.
  static const String sdkVersion = '0.1.0';

  Completer<void>? _initCompleter;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initCompleter?.isCompleted ?? false;

  /// Initializes the native clients with [options].
  ///
  /// Must be called once before any tracking method. Repeated calls are
  /// ignored and return the future of the first call.
  Future<void> initialize(OpenpanelOptions options) {
    final Completer<void>? existing = _initCompleter;
    if (existing != null) {
      return existing.future;
    }

    final Completer<void> completer = Completer<void>();
    _initCompleter = completer;
    // The platform call never throws (see MethodChannelOpenpanel._guard);
    // `whenComplete` also propagates readiness on unexpected failures so
    // queued events are not stuck forever.
    OpenpanelPlatform.instance
        .initialize(options)
        .whenComplete(() => _complete(completer));
    return completer.future;
  }

  /// Sends a named event.
  ///
  /// [properties] values must be JSON-compatible primitives
  /// (num/String/bool/null, lists and nested maps of those).
  Future<void> track(String name, {Map<String, Object?>? properties}) =>
      _whenReady(() => OpenpanelPlatform.instance.track(name, properties));

  /// Creates or updates the profile [profileId] and binds subsequent
  /// [track] events to it.
  ///
  /// The binding persists across app restarts until [clear] is called.
  /// [firstName], [lastName], [email] and [avatar] map to the built-in
  /// profile attributes in the OpenPanel dashboard; [properties] is an
  /// arbitrary map of custom attributes.
  Future<void> identify(
    String profileId, {
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    Map<String, Object?>? properties,
  }) =>
      _whenReady(
        () => OpenpanelPlatform.instance.identify(
          profileId,
          firstName: firstName,
          lastName: lastName,
          email: email,
          avatar: avatar,
          properties: properties,
        ),
      );

  /// Increments a numeric profile [property] by [value] (default semantics:
  /// pass the step, not the total).
  Future<void> increment(String profileId, String property, {num value = 1}) =>
      _whenReady(() =>
          OpenpanelPlatform.instance.increment(profileId, property, value));

  /// Decrements a numeric profile [property] by [value].
  Future<void> decrement(String profileId, String property, {num value = 1}) =>
      _whenReady(() =>
          OpenpanelPlatform.instance.decrement(profileId, property, value));

  /// Merges [properties] into the properties attached to every future
  /// [track] event.
  ///
  /// Global properties persist across app restarts until [clear] is called.
  Future<void> setGlobalProperties(Map<String, Object?> properties) =>
      _whenReady(
          () => OpenpanelPlatform.instance.setGlobalProperties(properties));

  /// Clears the bound profile, global properties and the pending event
  /// queue. The SDK stays initialized.
  Future<void> clear() => _whenReady(() => OpenpanelPlatform.instance.clear());

  /// Sends everything queued on the native side immediately.
  Future<void> flush() => _whenReady(() => OpenpanelPlatform.instance.flush());

  /// Runs [action] once [initialize] has completed.
  Future<void> _whenReady(Future<void> Function() action) {
    final Completer<void>? completer = _initCompleter;
    if (completer == null) {
      // Never initialized: warn loudly in debug, drop silently in release —
      // an analytics SDK must never crash the host app.
      if (kDebugMode) {
        debugPrint(
          'openpanel: event dropped — Openpanel.instance.initialize() '
          'has not been called yet.',
        );
      }
      return Future<void>.value();
    }
    return completer.future.then((_) => action());
  }

  void _complete(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  /// Resets the initialization state. Visible for tests only.
  @visibleForTesting
  static void debugReset() {
    instance._initCompleter = null;
  }
}
