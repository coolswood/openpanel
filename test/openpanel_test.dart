import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel/openpanel.dart';
import 'package:openpanel/openpanel_platform_interface.dart';

/// Records every call so tests can assert the facade forwards the exact
/// arguments.
class _RecordingPlatform extends OpenpanelPlatform {
  final List<(String, Map<String, Object?>?)> calls = [];

  @override
  Future<void> initialize(OpenpanelOptions options) async =>
      calls.add(('initialize', options.toMap()));

  @override
  Future<void> track(String name, Map<String, Object?>? properties) async =>
      calls.add(('track', {'name': name, 'properties': properties}));

  @override
  Future<void> identify(
    String profileId, {
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    Map<String, Object?>? properties,
  }) async =>
      calls.add((
        'identify',
        {
          'profileId': profileId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'avatar': avatar,
          'properties': properties,
        }
      ));

  @override
  Future<void> increment(String profileId, String property, num value) async =>
      calls.add((
        'increment',
        {'profileId': profileId, 'property': property, 'value': value}
      ));

  @override
  Future<void> decrement(String profileId, String property, num value) async =>
      calls.add((
        'decrement',
        {'profileId': profileId, 'property': property, 'value': value}
      ));

  @override
  Future<void> setGlobalProperties(Map<String, Object?> properties) async =>
      calls.add(('setGlobalProperties', {'properties': properties}));

  @override
  Future<void> clear() async => calls.add(('clear', null));

  @override
  Future<void> flush() async => calls.add(('flush', null));
}

/// Delays `initialize` until [gate] completes, simulating a slow native
/// setup; every method records its name in call order.
class _GatedPlatform extends OpenpanelPlatform {
  _GatedPlatform(this.gate);

  final Completer<void> gate;
  final List<String> rawCalls = <String>[];

  @override
  Future<void> initialize(OpenpanelOptions options) async {
    await gate.future;
    rawCalls.add('initialize');
  }

  @override
  Future<void> track(String name, Map<String, Object?>? properties) async {
    rawCalls.add('track');
  }
}

void main() {
  late _RecordingPlatform platform;

  setUp(() {
    Openpanel.debugReset();
    platform = _RecordingPlatform();
    OpenpanelPlatform.instance = platform;
  });

  tearDown(() {
    Openpanel.debugReset();
  });

  test('tracking before initialize throws StateError in debug', () {
    expect(() => Openpanel.instance.track('event'), throwsStateError);
  });

  test('initialize forwards options to the platform', () async {
    await Openpanel.instance.initialize(
      const OpenpanelOptions(
        clientId: 'client-id',
        apiUrl: 'https://openpanel.example.com',
        automaticTracking: false,
      ),
    );

    expect(Openpanel.instance.isInitialized, isTrue);
    expect(platform.calls, hasLength(1));
    expect(platform.calls.single.$1, 'initialize');
    expect(platform.calls.single.$2, <String, Object?>{
      'clientId': 'client-id',
      'clientSecret': null,
      'apiUrl': 'https://openpanel.example.com',
      'automaticTracking': false,
      'disabled': false,
      'verbose': false,
    });
  });

  test('initialize is idempotent', () async {
    final first = Openpanel.instance
        .initialize(const OpenpanelOptions(clientId: 'client-id'));
    final second = Openpanel.instance
        .initialize(const OpenpanelOptions(clientId: 'other'));
    await Future.wait([first, second]);

    expect(platform.calls.where((c) => c.$1 == 'initialize'), hasLength(1));
  });

  test('events sent before initialize completes are delivered after it',
      () async {
    final gate = Completer<void>();
    final gated = _GatedPlatform(gate);
    OpenpanelPlatform.instance = gated;

    final initFuture =
        Openpanel.instance.initialize(const OpenpanelOptions(clientId: 'c'));
    final trackFuture = Openpanel.instance.track('early_event');

    // Nothing has reached the platform yet — initialize is gated.
    expect(gated.rawCalls, isEmpty);

    gate.complete();
    await Future.wait([initFuture, trackFuture]);

    expect(gated.rawCalls, <String>['initialize', 'track']);
  });

  test('identify forwards named attributes', () async {
    await Openpanel.instance.initialize(const OpenpanelOptions(clientId: 'c'));
    await Openpanel.instance.identify(
      'user-1',
      firstName: 'John',
      email: 'john@example.com',
      properties: <String, Object?>{'plan': 'pro'},
    );

    final identifyCall = platform.calls.singleWhere((c) => c.$1 == 'identify');
    expect(identifyCall.$2, <String, Object?>{
      'profileId': 'user-1',
      'firstName': 'John',
      'lastName': null,
      'email': 'john@example.com',
      'avatar': null,
      'properties': <String, Object?>{'plan': 'pro'},
    });
  });

  test('increment and decrement forward values', () async {
    await Openpanel.instance.initialize(const OpenpanelOptions(clientId: 'c'));
    await Openpanel.instance.increment('user-1', 'logins');
    await Openpanel.instance.decrement('user-1', 'credits', value: 5);

    expect(
      platform.calls.where((c) => c.$1 == 'increment').single.$2,
      <String, Object?>{
        'profileId': 'user-1',
        'property': 'logins',
        'value': 1,
      },
    );
    expect(
      platform.calls.where((c) => c.$1 == 'decrement').single.$2,
      <String, Object?>{
        'profileId': 'user-1',
        'property': 'credits',
        'value': 5,
      },
    );
  });

  test('clear and flush reach the platform', () async {
    await Openpanel.instance.initialize(const OpenpanelOptions(clientId: 'c'));
    await Openpanel.instance.setGlobalProperties(<String, Object?>{'a': 1});
    await Openpanel.instance.clear();
    await Openpanel.instance.flush();

    expect(platform.calls.map((c) => c.$1).toList(), <String>[
      'initialize',
      'setGlobalProperties',
      'clear',
      'flush',
    ]);
  });
}
