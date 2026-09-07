import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel/openpanel_method_channel.dart';
import 'package:openpanel/openpanel_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelOpenpanel platform = MethodChannelOpenpanel();
  const MethodChannel channel = MethodChannel('openpanel');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize sends the options map', () async {
    await platform.initialize(
      const OpenpanelOptions(clientId: 'cid', apiUrl: 'https://op.example.com'),
    );

    expect(calls.single.method, 'initialize');
    expect(calls.single.arguments, <String, Object?>{
      'clientId': 'cid',
      'clientSecret': null,
      'apiUrl': 'https://op.example.com',
      'automaticTracking': true,
      'disabled': false,
      'verbose': false,
    });
  });

  test('track sends name and properties', () async {
    await platform.track('clicked', <String, Object?>{'button': 'signup'});

    expect(calls.single.method, 'track');
    expect(calls.single.arguments, <String, Object?>{
      'name': 'clicked',
      'properties': <String, Object?>{'button': 'signup'},
    });
  });

  test('track omits properties when null', () async {
    await platform.track('clicked', null);

    expect(calls.single.arguments, <String, Object?>{'name': 'clicked'});
  });

  test('identify sends only the given attributes', () async {
    await platform.identify(
      'user-1',
      email: 'user@example.com',
      properties: <String, Object?>{'plan': 'pro'},
    );

    expect(calls.single.method, 'identify');
    expect(calls.single.arguments, <String, Object?>{
      'profileId': 'user-1',
      'email': 'user@example.com',
      'properties': <String, Object?>{'plan': 'pro'},
    });
  });

  test('increment and decrement send profileId, property and value', () async {
    await platform.increment('user-1', 'logins', 1);
    await platform.decrement('user-1', 'credits', 5);

    expect(calls[0].method, 'increment');
    expect(calls[0].arguments, <String, Object?>{
      'profileId': 'user-1',
      'property': 'logins',
      'value': 1,
    });
    expect(calls[1].method, 'decrement');
    expect(calls[1].arguments, <String, Object?>{
      'profileId': 'user-1',
      'property': 'credits',
      'value': 5,
    });
  });

  test('setGlobalProperties, clear and flush use the right methods', () async {
    await platform.setGlobalProperties(<String, Object?>{'env': 'test'});
    await platform.clear();
    await platform.flush();

    expect(calls.map((c) => c.method).toList(), <String>[
      'setGlobalProperties',
      'clear',
      'flush',
    ]);
    expect(calls[0].arguments, <String, Object?>{
      'properties': <String, Object?>{'env': 'test'},
    });
  });

  test('a missing native implementation never throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    // Would throw MissingPluginException without the guard.
    await platform.track('event', null);
  });
}
