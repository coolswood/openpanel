import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_example/main.dart';

import 'package:flutter/material.dart';

void main() {
  testWidgets('example app renders status card', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenpanelExampleApp());

    expect(find.text('OpenPanel Example'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
