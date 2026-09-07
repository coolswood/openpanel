import 'package:flutter/material.dart';
import 'package:openpanel/openpanel.dart';

/// Configuration comes from --dart-define so no credentials live in the
/// repository:
///
/// ```sh
/// flutter run \
///   --dart-define=OPENPANEL_CLIENT_ID=... \
///   --dart-define=OPENPANEL_API_URL=https://your-openpanel.example.com
/// ```
const String clientId = String.fromEnvironment('OPENPANEL_CLIENT_ID');
const String apiUrl = String.fromEnvironment(
  'OPENPANEL_API_URL',
  defaultValue: OpenpanelOptions.defaultApiUrl,
);
const String clientSecret = String.fromEnvironment('OPENPANEL_CLIENT_SECRET');

void main() {
  if (clientId.isNotEmpty) {
    // The SDK queues events until initialization completes, so tracking can
    // start immediately.
    Openpanel.instance.initialize(
      OpenpanelOptions(
        clientId: clientId,
        apiUrl: apiUrl,
        clientSecret: clientSecret.isEmpty ? null : clientSecret,
      ),
    );
  }
  runApp(const OpenpanelExampleApp());
}

class OpenpanelExampleApp extends StatelessWidget {
  const OpenpanelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenPanel Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ExamplePage(),
    );
  }
}

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  void _run(BuildContext context, String label, Future<void> Function() body) {
    final messenger = ScaffoldMessenger.of(context);
    body().then(
      (_) => _toast(messenger, '$label ✓'),
      onError: (Object error) => _toast(messenger, '$label failed: $error'),
    );
  }

  void _toast(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenPanel Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                clientId.isEmpty
                    ? 'Not configured. Run with '
                          '--dart-define=OPENPANEL_CLIENT_ID=... '
                          '(and OPENPANEL_API_URL for self-hosted).'
                    : 'Configured. api: $apiUrl\n'
                          'Events are queued natively and flushed in batches.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _run(context, 'track', () {
              return Openpanel.instance.track(
                'button_clicked',
                properties: <String, Object?>{
                  'button': 'track_demo',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              );
            }),
            child: const Text('track: button_clicked'),
          ),
          FilledButton(
            onPressed: () => _run(context, 'identify', () {
              return Openpanel.instance.identify(
                'example-user-42',
                email: 'user@example.com',
                properties: <String, Object?>{'plan': 'free'},
              );
            }),
            child: const Text('identify: example-user-42'),
          ),
          FilledButton(
            onPressed: () => _run(context, 'increment', () {
              return Openpanel.instance.increment(
                'example-user-42',
                'demo_counter',
                value: 1,
              );
            }),
            child: const Text('increment: demo_counter'),
          ),
          FilledButton(
            onPressed: () => _run(context, 'decrement', () {
              return Openpanel.instance.decrement(
                'example-user-42',
                'demo_counter',
                value: 1,
              );
            }),
            child: const Text('decrement: demo_counter'),
          ),
          FilledButton(
            onPressed: () => _run(context, 'setGlobalProperties', () {
              return Openpanel.instance.setGlobalProperties(<String, Object?>{
                'environment': 'example',
              });
            }),
            child: const Text('setGlobalProperties: environment'),
          ),
          FilledButton(
            onPressed: () => _run(context, 'flush', Openpanel.instance.flush),
            child: const Text('flush'),
          ),
          OutlinedButton(
            onPressed: () => _run(context, 'clear', Openpanel.instance.clear),
            child: const Text('clear'),
          ),
        ],
      ),
    );
  }
}
