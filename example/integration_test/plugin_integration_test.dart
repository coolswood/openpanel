// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can
// interact with the host side of a plugin implementation, unlike Dart unit
// tests. The OpenPanel server is not reachable from CI, so this only
// verifies that the native client accepts the calls without throwing —
// events land in the persistent queue and are dropped/retried by the
// poster at runtime.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:openpanel/openpanel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize, track and identify do not throw',
      (WidgetTester tester) async {
    await Openpanel.instance.initialize(
      const OpenpanelOptions(
        clientId: 'integration-test-client-id',
        // Unroutable on purpose: exercises the offline queue path.
        apiUrl: 'https://localhost:3/openpanel',
      ),
    );
    expect(Openpanel.instance.isInitialized, isTrue);

    await Openpanel.instance.track('integration_test_event');
    await Openpanel.instance.identify('integration-user');
    await Openpanel.instance.setGlobalProperties(<String, Object?>{
      'environment': 'integration_test',
    });
  });
}
