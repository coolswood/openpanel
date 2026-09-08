import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'openpanel_method_channel.dart';
import 'openpanel_options.dart';

/// The interface that platform implementations of the openpanel plugin
/// must extend.
///
/// Applications use [Openpanel] from `package:openpanel/openpanel.dart`
/// directly; this interface exists so the implementation can be replaced in
/// tests (see `OpenpanelPlatform.instance`).
abstract class OpenpanelPlatform extends PlatformInterface {
  /// Constructs a OpenpanelPlatform.
  OpenpanelPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpenpanelPlatform _instance = MethodChannelOpenpanel();

  /// The default instance of [OpenpanelPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpenpanel].
  static OpenpanelPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpenpanelPlatform] when they
  /// register themselves.
  static set instance(OpenpanelPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Configures the native client with [options].
  Future<void> initialize(OpenpanelOptions options) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Sends a named event with optional [properties].
  Future<void> track(String name, Map<String, Object?>? properties) {
    throw UnimplementedError('track() has not been implemented.');
  }

  /// Creates or updates a user profile and binds subsequent events to it.
  Future<void> identify(
    String profileId, {
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    Map<String, Object?>? properties,
  }) {
    throw UnimplementedError('identify() has not been implemented.');
  }

  /// Increments a numeric [property] of the profile by [value].
  Future<void> increment(String profileId, String property, num value) {
    throw UnimplementedError('increment() has not been implemented.');
  }

  /// Decrements a numeric [property] of the profile by [value].
  Future<void> decrement(String profileId, String property, num value) {
    throw UnimplementedError('decrement() has not been implemented.');
  }

  /// Merges [properties] into the properties attached to every future
  /// `track` event. A null value removes the property.
  Future<void> setGlobalProperties(Map<String, Object?> properties) {
    throw UnimplementedError('setGlobalProperties() has not been implemented.');
  }

  /// Clears the stored profile id, global properties and the pending event
  /// queue.
  Future<void> clear() {
    throw UnimplementedError('clear() has not been implemented.');
  }

  /// Sends everything queued on the native side immediately.
  Future<void> flush() {
    throw UnimplementedError('flush() has not been implemented.');
  }
}
