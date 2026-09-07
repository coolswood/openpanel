import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'openpanel_options.dart';
import 'openpanel_platform_interface.dart';

/// An implementation of [OpenpanelPlatform] that uses method channels.
class MethodChannelOpenpanel extends OpenpanelPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('openpanel');

  /// Calls the native side, never letting analytics failures reach the app.
  ///
  /// Any failure — a missing native implementation (web/desktop), a platform
  /// error or an uninitialized Flutter binding — is swallowed: an analytics
  /// SDK must not crash the host app. In debug builds failures are printed
  /// to the console.
  Future<void> _guard(String method, Map<String, Object?>? arguments) async {
    try {
      await methodChannel.invokeMethod<void>(method, arguments);
    } catch (error) {
      debugPrint('openpanel: $method failed: $error');
    }
  }

  @override
  Future<void> initialize(OpenpanelOptions options) =>
      _guard('initialize', options.toMap());

  @override
  Future<void> track(String name, Map<String, Object?>? properties) =>
      _guard('track', <String, Object?>{
        'name': name,
        if (properties != null) 'properties': properties,
      });

  @override
  Future<void> identify(
    String profileId, {
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    Map<String, Object?>? properties,
  }) =>
      _guard('identify', <String, Object?>{
        'profileId': profileId,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null) 'email': email,
        if (avatar != null) 'avatar': avatar,
        if (properties != null) 'properties': properties,
      });

  @override
  Future<void> increment(String profileId, String property, num value) =>
      _guard('increment', <String, Object?>{
        'profileId': profileId,
        'property': property,
        'value': value,
      });

  @override
  Future<void> decrement(String profileId, String property, num value) =>
      _guard('decrement', <String, Object?>{
        'profileId': profileId,
        'property': property,
        'value': value,
      });

  @override
  Future<void> setGlobalProperties(Map<String, Object?> properties) =>
      _guard('setGlobalProperties', <String, Object?>{
        'properties': properties,
      });

  @override
  Future<void> clear() => _guard('clear', const <String, Object?>{});

  @override
  Future<void> flush() => _guard('flush', const <String, Object?>{});
}
